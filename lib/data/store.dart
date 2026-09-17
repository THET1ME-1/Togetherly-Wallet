import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart' show Color;
import 'package:path_provider/path_provider.dart';

import '../design/app_theme.dart';
import '../logic/goals.dart';
import '../logic/notice_match.dart';
import '../logic/notice_rules.dart';
import '../logic/period.dart';
import '../logic/presets.dart';
import '../logic/notice_parse.dart';
import '../l10n/strings.dart';
import '../logic/money.dart';
import '../logic/recurring.dart';
import '../logic/round_up.dart';
import 'models.dart';

/// Состояние приложения и всё, что связано с диском.
///
/// База лежит обычным файлом в каталоге приложения. У веб-версии она жила в
/// localStorage с потолком около пяти мегабайт, и на четырёх тысячах операций
/// запись начинала молча пропадать; у файла такого потолка нет.
class Store extends ChangeNotifier {
  Database _db = const Database();

  /// Хранилища других пар: ключ — номер группы, значение — её база.
  ///
  /// Человек может вести деньги с несколькими людьми сразу: «Саша + Аня» и
  /// «Саша + Кирилл» — разные пары, и Кирилл не должен видеть траты Ани
  /// (13.09.2026). Поэтому у каждой пары своё хранилище, своя очередь и своя
  /// метка дельты, а на экране человек переключается между ними.
  final Map<String, Database> _parked = {};
  final Map<String, Set<String>> _parkedOutbox = {};
  final Map<String, int> _parkedMarks = {};

  /// Номер нынешнего пространства: группа пары или свой uid у одиночки.
  String get space => _db.pair.groupId;

  /// Все известные пространства, включая нынешнее.
  List<String> get spaces => [
        if (space.isNotEmpty) space,
        ..._parked.keys.where((k) => k != space),
      ];

  /// Очередь отправки пространства.
  Set<String> outboxOf(String groupId) =>
      groupId == space ? _outbox : (_parkedOutbox[groupId] ?? const {});

  /// Метка дельты пространства.
  int markOf(String groupId) =>
      groupId == space ? _syncMark : (_parkedMarks[groupId] ?? 0);

  /// Очистить очередь пространства после ответа сервера.
  void clearOutboxOf(String groupId, Set<String> done) {
    if (groupId == space) {
      clearOutbox(done);
      return;
    }
    _parkedOutbox[groupId]?.removeAll(done);
    _saveSettings();
    notifyListeners();
  }

  /// Принять дельту в ОТЛОЖЕННОЕ пространство: открытая пара при этом не
  /// шелохнётся, а вторая пара обновится, пока человек смотрит на первую.
  void applyRemoteTo(String groupId, Map<String, dynamic> payload) {
    if (groupId == space) {
      applyRemote(payload);
      return;
    }
    final parked = _parked[groupId];
    if (parked == null) return;

    // Приём написан для нынешнего хранилища, поэтому подменяем его на время
    // разбора: так вторая пара получает ровно ту же логику слияния, что и
    // первая, без её копии.
    final keepDb = _db;
    final keepOutbox = {..._outbox};
    final keepMark = _syncMark;

    _db = parked;
    _outbox
      ..clear()
      ..addAll(_parkedOutbox[groupId] ?? const <String>{});
    _syncMark = _parkedMarks[groupId] ?? 0;

    applyRemote(payload);

    _parked[groupId] = _db;
    _parkedOutbox[groupId] = {..._outbox};
    _parkedMarks[groupId] = _syncMark;

    _db = keepDb;
    _outbox
      ..clear()
      ..addAll(keepOutbox);
    _syncMark = keepMark;
    _schedule();
    notifyListeners();
  }

  /// Смотрим ли все пары разом. Настройка взгляда, а не данных: запись всё
  /// равно ложится в открытое пространство.
  bool _viewAll = false;
  bool get viewAll => _viewAll;

  void setViewAll(bool value) {
    if (_viewAll == value) return;
    _viewAll = value;
    _saveSettings();
    notifyListeners();
  }

  /// База для ЭКРАНОВ: в обычном режиме — открытая пара, в сводном — все
  /// вместе. Писать в неё нельзя: запись всегда идёт в `db`.
  Database get view => _viewAll && _parked.isNotEmpty ? _merged() : _db;

  /// Все пары одной базой.
  ///
  /// Счета разных пар зовутся одинаково («Карта» есть у обеих), поэтому в
  /// сводке к имени добавляется, с кем эта пара: сложить два разных остатка в
  /// один было бы прямым враньём.
  Database _merged() {
    final accounts = <Account>[];
    final transactions = <Transaction>[];
    final categories = <Category>[..._db.categories];

    void take(Database from, String label) {
      String rename(String name) =>
          label.isEmpty || isVirtualAccount(name) ? name : '$name · $label';

      for (final a in from.accounts) {
        accounts.add(a.copyWith(name: rename(a.name)));
      }
      for (final t in from.transactions) {
        transactions.add(t.copyWith(account: rename(t.account)));
      }
      for (final c in from.categories) {
        if (categories.any((x) => x.name == c.name && x.parent == c.parent)) {
          continue;
        }
        categories.add(c);
      }
    }

    take(_db, _labelOf(_db));
    for (final e in _parked.entries) {
      take(e.value, _labelOf(e.value));
    }
    transactions.sort((a, b) => b.date.compareTo(a.date));

    return _db.copyWith(
      accounts: accounts,
      transactions: transactions,
      categories: categories,
    );
  }

  /// Чем подписать пару в сводке: именем партнёра, а у личного — ничем.
  String _labelOf(Database from) {
    final other = from.pair.other(viewer);
    return other?.name.trim() ?? '';
  }

  /// Хранилище пространства: нынешнее берётся как есть, остальные — из
  /// отложенных. Нужен сводке «все пары разом».
  Database dbOf(String groupId) =>
      groupId == space ? _db : (_parked[groupId] ?? const Database());

  /// Переключиться на другую пару.
  ///
  /// Нынешнее хранилище не стирается, а откладывается целиком — вместе с
  /// очередью и меткой. Возврат в прежнюю пару поднимает её ровно такой, какой
  /// её оставили: ждать нового круга синхронизации не нужно.
  void openSpace(Pair pair) {
    final next = pair.groupId;
    if (next.isEmpty || next == space) return;

    final was = space;
    if (was.isNotEmpty) {
      _parked[was] = _db;
      _parkedOutbox[was] = {..._outbox};
      _parkedMarks[was] = _syncMark;
    }

    final found = _parked.remove(next);
    _outbox
      ..clear()
      ..addAll(_parkedOutbox.remove(next) ?? const <String>{});
    _syncMark = _parkedMarks.remove(next) ?? 0;
    _db = found ??
        Database(
          baseCurrency: _db.baseCurrency,
          rates: _db.rates,
          pair: pair,
        );
    // Состав пары мог смениться, пока мы были в другой: имена и аватары
    // приезжают вместе с выбором.
    if (found != null) _db = _db.copyWith(pair: pair);
    _saveSettings();
    _schedule();
    notifyListeners();
  }
  Database get db => _db;

  bool _ready = false;
  bool get ready => _ready;

  /// Отмена последнего действия: снимок держится до следующего действия.
  ({String label, Database before})? _undo;
  ({String label, Database before})? get undo => _undo;

  ThemeChoice _theme = ThemeChoice.system;
  ThemeChoice get theme => _theme;

  /// Акцент, из которого строится вся схема. По умолчанию фирменный индиго
  /// Орбиты; человек может поставить свой, и тогда цвет живёт в настройках.
  Color _seed = AppTheme.defaultSeed;
  Color get seed => _seed;

  /// Чёрный фон вместо тёмно-серого: на OLED-экране он не светится.
  bool _amoled = false;
  bool get amoled => _amoled;

  /// Ключи моделей лежат на устройстве и уходят только по нажатию.
  Map<String, String> _keys = {};
  Map<String, String> get modelKeys => _keys;

  void setKey(String who, String value) {
    _keys = {..._keys, who: value};
    notifyListeners();
    _saveSettings();
  }

  /// Что ещё не уехало на сервер: ключи вида `tx:<id>`, `acc:<имя>`,
  /// `cat:<имя>`, `settings:base`. Очередь переживает перезапуск и чистится
  /// ТОЛЬКО после ответа сервера — иначе правка теряется на обрыве сети.
  final Set<String> _outbox = <String>{};
  Set<String> get outbox => Set.unmodifiable(_outbox);

  /// Метка последней успешной дельты (миллисекунды сервера).
  int _syncMark = 0;
  int get syncMark => _syncMark;

  /// Отметить правку к отправке. Без аккаунта очередь не копится: решение
  /// «синхронизироваться или нет» принимает Sync, но складывать ключи в
  /// пустоту ради человека, который выбрал жить на устройстве, незачем.
  bool syncEnabled = false;

  /// Сколько записей человек сделал без аккаунта и ещё не решил, переносить
  /// ли их в облако. Ноль — решение принято или переносить нечего.
  int pendingLocal = 0;

  /// Кто смотрит на эти деньги. Ставится при входе; пусто — человек без
  /// аккаунта, и тогда парных подписей на экранах нет вовсе.
  String viewer = '';

  /// Уведомления банков: что читать, что уже разобрано и чему приложение
  /// научилось. Всё это живёт ТОЛЬКО на устройстве: текст чужих пушей не
  /// уезжает на сервер ни в каком виде.
  final Map<String, NoticeMode> _senders = {};
  final List<ParsedNotice> _pending = [];
  final Map<String, String> _noticeAccounts = {};
  final Map<String, String> _noticeCategories = {};
  final Set<String> _seenNotices = {};

  /// Свои правила разбора. Порядок в списке и есть приоритет.
  final List<NoticeRule> _noticeRules = [];

  /// Открыта ли подписка. Ставится снаружи (`PlusService`), потому что база не
  /// должна ходить в сеть. Правила без подписки остаются в списке и молчат:
  /// отменивший её не теряет свою работу, он теряет автоматику.
  bool plusActive = false;

  /// Сказать базе, что подписка открылась или закрылась.
  ///
  /// Зовётся слушателем `PlusService` из `main.dart`. Отдельный метод, а не
  /// голое присваивание: экраны со счётчиками слушают базу, и покупка обязана
  /// убирать «осталось 2 из 5» без перезахода на экран.
  void setPlusActive(bool value) {
    if (plusActive == value) return;
    plusActive = value;
    notifyListeners();
  }

  /// Когда от источника приходили уведомления, последние 30 дней. Нужно, чтобы
  /// экран показывал ТИШИНУ: банк, который молчит месяц, обычно отключён в
  /// настройках Android, и это не лечится внутри приложения.
  final Map<String, List<int>> _noticeLog = {};

  /// Объяснение про Android человек читает один раз. Дальше оно занимает
  /// верх экрана и повторяет то, что он уже знает.
  bool _noticeHintDone = false;
  bool get noticeHintDone => _noticeHintDone;

  void hideNoticeHint() {
    if (_noticeHintDone) return;
    _noticeHintDone = true;
    _saveSettings();
    notifyListeners();
  }

  Map<String, NoticeMode> get senders => Map.unmodifiable(_senders);
  List<ParsedNotice> get pendingNotices => List.unmodifiable(_pending);
  Map<String, String> get noticeAccounts => Map.unmodifiable(_noticeAccounts);
  Map<String, String> get noticeCategories => Map.unmodifiable(_noticeCategories);
  List<NoticeRule> get noticeRules => List.unmodifiable(_noticeRules);

  /// Отрезок у каждого блока главной свой: баланс смотрят за месяц, категории
  /// за неделю, поток за год — переключать их вместе значило бы мешать
  /// человеку. Ключ — имя блока.
  ///
  /// Храним и вид, и опорную дату: человек листнул на август и ушёл с экрана —
  /// вернувшись, он ждёт август, а не «этот месяц».
  final Map<String, Period> _blockPeriods = {};

  Period periodOf(String block, {Period? fallback}) =>
      _blockPeriods[block] ?? fallback ?? Period.month();

  void setPeriod(String block, Period period) {
    _blockPeriods[block] = period;
    _saveSettings();
    notifyListeners();
  }

  /// Счета, которые человек оставил в общем балансе на главной. Пусто — все.
  /// Настройка устройства: на телефоне партнёра свой взгляд на те же деньги.
  final Set<String> _balanceAccounts = {};
  Set<String> get balanceAccounts => {..._balanceAccounts};

  void setBalanceAccounts(Set<String> next) {
    _balanceAccounts
      ..clear()
      ..addAll(next);
    _saveSettings();
    notifyListeners();
  }

  /// Развёрнута ли карточка баланса. Человек развернул — пусть так и
  /// останется, пока он сам не свернёт.
  bool _balanceOpen = false;
  bool get balanceOpen => _balanceOpen;

  void setBalanceOpen(bool value) {
    if (_balanceOpen == value) return;
    _balanceOpen = value;
    _saveSettings();
    notifyListeners();
  }

  /// От кого уведомления уже приходили. Источник остаётся в списке и после
  /// того, как очередь разобрана: иначе банк исчезал с экрана настроек, стоило
  /// подтвердить последнюю трату.
  Set<String> get noticeSenders => {..._noticeLog.keys};

  /// Сколько уведомлений поймано от источника за месяц.
  int noticeCountOf(String package) => (_noticeLog[package] ?? const []).length;

  /// Когда пришло последнее, `null` — тишина дольше месяца.
  DateTime? noticeLastAt(String package) {
    final log = _noticeLog[package] ?? const <int>[];
    if (log.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(log.last);
  }

  /// Куда ложатся траты источника: запомненные пары «карта — счёт».
  List<({String last4, String account})> routesOf(String package) {
    final out = <({String last4, String account})>[];
    for (final e in _noticeAccounts.entries) {
      final parts = e.key.split('|');
      if (parts.first != package) continue;
      if (!_db.accounts.any((a) => a.name == e.value)) continue;
      out.add((last4: parts.length > 1 ? parts[1] : '*', account: e.value));
    }
    out.sort((a, b) => a.last4.compareTo(b.last4));
    return out;
  }

  /// Забыть привязку карты к счёту: человек ошибся или закрыл карту.
  void forgetNoticeAccount(String package, String last4) {
    _noticeAccounts.remove(noticeKey(package, last4 == '*' ? null : last4));
    _saveSettings();
    notifyListeners();
  }

  /// Забыть категорию магазина.
  void forgetNoticeCategory(String merchant) {
    _noticeCategories.remove(merchant.trim().toLowerCase());
    _saveSettings();
    notifyListeners();
  }

  NoticeMode modeOf(String package) =>
      _senders[package] ?? defaultModeFor(package, _sourceChoice);

  void _mark(String key) {
    if (!syncEnabled) return;
    _outbox.add(key);
    _saveSettings();
  }

  /// Пометить всё, что есть, к отправке.
  ///
  /// Так локальные записи уезжают в пару после входа: человек месяц писал без
  /// аккаунта, и без переноса он решит, что потерял всё.
  int markAllForSync() {
    if (!syncEnabled) return 0;
    pendingLocal = 0;
    for (final t in _db.transactions) {
      _outbox.add('tx:${t.id}');
    }
    for (final a in _db.accounts) {
      _outbox.add('acc:${a.name}');
    }
    for (final c in _db.categories) {
      _outbox.add('cat:${c.name}');
    }
    // Всё остальное тоже уезжает. До 12.09.2026 здесь стояли только операции,
    // счета и категории: месяц работы без аккаунта попадал в пару без целей,
    // долгов, лимитов и регулярных платежей — человек считал, что потерял их.
    for (final g in _db.goals) {
      _outbox.add('goal:${g.name}');
    }
    for (final d in _db.debts) {
      _outbox.add('debt:${d.name}');
    }
    for (final b in _db.budgets) {
      _outbox.add(budgetKey(b.category, b.subcategory));
    }
    for (final r in _db.recurring) {
      _outbox.add('rec:${r.id}');
    }
    for (final a in _db.agreements) {
      _outbox.add('agr:${a.id}');
    }
    for (final item in _db.plan) {
      _outbox.add('plan:${item.key}');
    }
    for (final c in _db.comments) {
      _outbox.add('cm:${c.id}');
    }
    _outbox.add('settings:base');
    _saveSettings();
    notifyListeners();
    return _outbox.length;
  }

  /// Пара распалась: хранилище становится личным.
  ///
  /// Записи с устройства НЕ стираются — пара кончилась, а учёт продолжается, и
  /// год общей истории остаётся у обоих. Но лежат они теперь под своим uid,
  /// поэтому всё помечается к отправке: иначе человек, войдя с другого
  /// телефона, увидел бы пустоту. Записи прежней группы на сервере остаются у
  /// партнёра и нам больше не приезжают.
  void leavePair(String uid) {
    if (uid.isEmpty) return;
    final mine = _db.pair.byUid(uid) ?? Member(uid: uid, name: '');
    _syncMark = 0;
    _apply(
      _db.copyWith(
        pair: Pair(
          groupId: uid,
          baseCurrency: _db.pair.baseCurrency,
          members: [mine],
          defaultSplit: _db.pair.defaultSplit,
        ),
      ),
      label: tr('storeDisbanded'),
    );
    markAllForSync();
    _saveSettings();
  }

  /// Сказать экранам, что состояние изменилось, не трогая саму базу.
  void notify() => notifyListeners();

  void clearOutbox(Set<String> done) {
    _outbox.removeAll(done);
    _saveSettings();
    notifyListeners();
  }

  Timer? _writeTimer;
  Directory? _dir;

  Future<void> load() async {
    _dir = await getApplicationDocumentsDirectory();
    final file = File('${_dir!.path}/orbita.json');
    if (await file.exists()) {
      try {
        _db = Database.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      } catch (_) {
        // Битый файл не должен ронять запуск: приложение откроется пустым,
        // а копия рядом остаётся нетронутой.
      }
    }
    final side = File('${_dir!.path}/spaces.json');
    if (await side.exists()) {
      try {
        final j = jsonDecode(await side.readAsString()) as Map<String, dynamic>;
        for (final e in j.entries) {
          _parked[e.key] =
              Database.fromJson((e.value as Map).cast<String, dynamic>());
        }
      } catch (_) {
        // Битый файл соседних пар не должен ронять запуск: нынешняя пара
        // лежит отдельно и цела.
      }
    }

    final settings = File('${_dir!.path}/settings.json');
    if (await settings.exists()) {
      try {
        final j = jsonDecode(await settings.readAsString()) as Map<String, dynamic>;
        _theme = ThemeChoice.values.firstWhere(
          (t) => t.name == j['theme'],
          orElse: () => ThemeChoice.system,
        );
        _keys = ((j['keys'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v'));
        final seed = j['seed'];
        if (seed is int) _seed = Color(seed);
        _outbox
          ..clear()
          ..addAll(((j['outbox'] as List?) ?? const []).map((e) => '$e'));
        _syncMark = (j['syncMark'] as num?)?.toInt() ?? 0;
        _amoled = j['amoled'] == true;
        _categoriesSeeded = j['categoriesSeeded'] == true;
        _pairChoice = j['pairChoice'] as String? ?? '';
        _viewAll = j['viewAll'] == true;
        final queues = (j['parkedOutbox'] as Map?) ?? const {};
        _parkedOutbox
          ..clear()
          ..addEntries(queues.entries.map((e) => MapEntry(
                '${e.key}',
                ((e.value as List?) ?? const []).map((v) => '$v').toSet(),
              )));
        final marks = (j['parkedMarks'] as Map?) ?? const {};
        _parkedMarks
          ..clear()
          ..addEntries(marks.entries
              .map((e) => MapEntry('${e.key}', (e.value as num?)?.toInt() ?? 0)));
        _sourceChoice = NoticeSource.values
            .where((s) => s.name == j['noticeSource'])
            .firstOrNull;
        final senders = (j['senders'] as Map?) ?? const {};
        _senders
          ..clear()
          ..addEntries(senders.entries
              .map((e) => MapEntry('${e.key}', noticeModeOf('${e.value}'))));
        _pending
          ..clear()
          ..addAll(((j['pendingNotices'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => ParsedNotice.fromJson(m.cast<String, dynamic>())));
        _noticeAccounts
          ..clear()
          ..addEntries(((j['noticeAccounts'] as Map?) ?? const {})
              .entries
              .map((e) => MapEntry('${e.key}', '${e.value}')));
        _noticeRules
          ..clear()
          ..addAll([
            for (final r in ((j['noticeRules'] as List?) ?? const []))
              if (r is Map) NoticeRule.fromJson(r.cast<String, dynamic>()),
          ]);
        _noticeCategories
          ..clear()
          ..addEntries(((j['noticeCategories'] as Map?) ?? const {})
              .entries
              .map((e) => MapEntry('${e.key}', '${e.value}')));
        _seenNotices
          ..clear()
          ..addAll(((j['seenNotices'] as List?) ?? const []).map((e) => '$e'));
        _noticeHintDone = j['noticeHintDone'] == true;
        _blockPeriods
          ..clear()
          ..addEntries(((j['blockPeriods'] as Map?) ?? const {})
              .entries
              .map((e) {
                final raw = (e.value as Map?)?.cast<String, dynamic>() ?? {};
                final kind = PeriodKind.values.firstWhere(
                  (k) => k.name == '${raw['kind']}',
                  orElse: () => PeriodKind.month,
                );
                final anchor = DateTime.tryParse('${raw['anchor']}');
                final from = DateTime.tryParse('${raw['from']}');
                final to = DateTime.tryParse('${raw['to']}');
                if (kind == PeriodKind.custom && from != null && to != null) {
                  return MapEntry('${e.key}', Period.custom(from, to));
                }
                return MapEntry(
                  '${e.key}',
                  Period(kind, anchor ?? DateTime.now()),
                );
              })
              .whereType<MapEntry<String, Period>>());
        _balanceAccounts
          ..clear()
          ..addAll(_stringList(j['balanceAccounts']));
        _balanceOpen = j['balanceOpen'] == true;
        _ratesSource = '${j['ratesSource'] ?? ''}';
        _ratesAt = (j['ratesAt'] as num?)?.toInt() ?? 0;
        _noticeLog
          ..clear()
          ..addEntries(((j['noticeLog'] as Map?) ?? const {}).entries.map((e) =>
              MapEntry('${e.key}',
                  ((e.value as List?) ?? const []).map((t) => (t as num).toInt()).toList())));
      } catch (_) { /* настройки не критичны */ }
    }
    _ready = true;
    notifyListeners();
  }

  /// Запись отложена: пока тянут ползунок цвета, состояние меняется десятки раз
  /// в секунду, и сериализация трёхсот операций на каждое движение съедала бы
  /// кадры.
  void _schedule() {
    _writeTimer?.cancel();
    // Каталога нет — писать некуда: так бывает до load() и в тестах. Таймер
    // впустую держал бы виджет-тесты открытыми.
    if (_dir == null) return;
    _writeTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    final dir = _dir;
    if (dir == null) return;
    // Отложенные пары лежат рядом с нынешней: без этого переключение теряло
    // бы их при первом же перезапуске.
    if (_parked.isNotEmpty) {
      final side = File('${dir.path}/spaces.json');
      await side.writeAsString(jsonEncode({
        for (final e in _parked.entries) e.key: e.value.toJson(),
      }), flush: true);
    }
    final text = jsonEncode(_db.toJson());
    // Пишем через временный файл: обрыв на середине не оставит огрызок вместо
    // базы.
    final tmp = File('${dir.path}/orbita.tmp');
    await tmp.writeAsString(text, flush: true);
    await tmp.rename('${dir.path}/orbita.json');
  }

  void _apply(Database next, {String? label}) {
    if (label != null) _undo = (label: label, before: _db);
    _db = next;
    _schedule();
    notifyListeners();
  }

  void undoLast() {
    final snap = _undo;
    if (snap == null) return;
    _undo = null;
    _apply(snap.before);
  }

  void forgetUndo() {
    if (_undo == null) return;
    _undo = null;
    notifyListeners();
  }

  void setTheme(ThemeChoice value) {
    _theme = value;
    notifyListeners();
    _saveSettings();
  }

  void setSeed(Color value) {
    _seed = value;
    notifyListeners();
    _saveSettings();
  }

  void setAmoled(bool value) {
    _amoled = value;
    notifyListeners();
    _saveSettings();
  }

  void _saveSettings() {
    final dir = _dir;
    if (dir == null) return;
    File('${dir.path}/settings.json').writeAsString(jsonEncode({
      'theme': _theme.name,
      'seed': _seed.toARGB32(),
      'amoled': _amoled,
      'keys': _keys,
      'outbox': _outbox.toList(),
      'syncMark': _syncMark,
      'senders': {for (final e in _senders.entries) e.key: e.value.name},
      'pendingNotices': [for (final n in _pending) n.toJson()],
      'noticeAccounts': _noticeAccounts,
      'noticeCategories': _noticeCategories,
      'noticeRules': [for (final r in _noticeRules) r.toJson()],
      // Отпечатки храним последние двести: банк повторяет уведомление, а
      // держать их все — расти файлу без предела.
      'seenNotices': _seenNotices.toList().reversed.take(200).toList(),
      'noticeHintDone': _noticeHintDone,
      'categoriesSeeded': _categoriesSeeded,
      if (_sourceChoice != null) 'noticeSource': _sourceChoice!.name,
      if (_pairChoice.isNotEmpty) 'pairChoice': _pairChoice,
      'viewAll': _viewAll,
      'parkedOutbox': {
        for (final e in _parkedOutbox.entries) e.key: e.value.toList(),
      },
      'parkedMarks': _parkedMarks,
      'noticeLog': {for (final e in _noticeLog.entries) e.key: e.value},
      'blockPeriods': {
        for (final e in _blockPeriods.entries)
          e.key: {
            'kind': e.value.kind.name,
            'anchor': iso(e.value.anchor),
            if (e.value.customFrom != null) 'from': iso(e.value.customFrom!),
            if (e.value.customTo != null) 'to': iso(e.value.customTo!),
          },
      },
      'balanceAccounts': _balanceAccounts.toList(),
      'balanceOpen': _balanceOpen,
      'ratesSource': _ratesSource,
      'ratesAt': _ratesAt,
    }));
  }

  /// Загрузка бэкапа: и свой формат, и голая база внутри поля `data`.
  /// Восстановить базу из копии. Возвращает число записей; ноль значит, что
  /// файл не наш и НИЧЕГО не изменилось.
  ///
  /// Прежде тут не было ни одной проверки: битый json бросал исключение прямо
  /// в обработчике нажатия, а чужой файл затирал базу пустышкой — человек
  /// нажимал «Загрузить» и терял всё.
  int importBackup(String text) {
    Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException {
      return 0;
    }
    if (raw is! Map) return 0;

    final root = raw.cast<String, dynamic>();
    final map = root['data'] is Map
        ? (root['data'] as Map).cast<String, dynamic>()
        : root;

    // Наш файл узнаётся по пометке или по знакомым ключам: снимок чужого
    // приложения в базу попасть не должен.
    const known = ['transactions', 'accounts', 'categories', 'goals', 'debts'];
    final ours = '${root['format'] ?? ''}'.contains('backup') ||
        known.any(map.containsKey);
    if (!ours) return 0;

    final next = Database.fromJson(map);
    if (next.transactions.isEmpty && next.accounts.isEmpty) return 0;

    _apply(next, label: tr('storeRestored'));
    // Всё помечается к отправке: иначе восстановленное останется на этом
    // телефоне, а с сервера вернётся прежнее.
    markAllForSync();
    return next.transactions.length;
  }

  /// Записать операцию в ДРУГОЕ пространство: в пару, которую человек сейчас
  /// не смотрит, или в своё личное.
  ///
  /// Так работает правило видимости: трата принадлежит ровно одной паре, и
  /// видят её только те, кто в этой паре. Ровно то же делает Splitwise —
  /// запись лежит в одной группе, а приватная живёт вне групп.
  void saveOperationTo(String groupId, Transaction op, {String label = 'Записано'}) {
    if (groupId.isEmpty || groupId == space) {
      saveOperation(op, label: label);
      return;
    }
    final parked = _parked[groupId];
    if (parked == null) {
      saveOperation(op, label: label);
      return;
    }
    final list = [...parked.transactions];
    final at = list.indexWhere((t) => t.id == op.id);
    if (at >= 0) {
      list[at] = op;
    } else {
      list.add(op);
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    _parked[groupId] = parked.copyWith(transactions: list);
    (_parkedOutbox[groupId] ??= <String>{}).add('tx:${op.id}');
    _saveSettings();
    _schedule();
    notifyListeners();
  }

  /// Рассчитаться: долг между людьми погашен.
  ///
  /// Деньги передаются мимо приложения — наличными или переводом с карты на
  /// карту, которой здесь нет, — поэтому остатки не двигаются. Запись ложится
  /// на счёт расчёта и обнуляет сальдо: `settlement` считает её как трату
  /// [from] с долей целиком на [to].
  void settleUp({
    required String from,
    required String to,
    required double amount,
  }) {
    if (amount <= 0 || from.isEmpty || to.isEmpty || from == to) return;
    final stamp = DateTime.now();
    saveOperation(
      Transaction(
        id: 'stl-${stamp.microsecondsSinceEpoch}',
        date: stamp.toIso8601String().substring(0, 10),
        kind: TxKind.expense,
        account: '$settlePrefix$from',
        currency: _db.baseCurrency,
        amount: -amount,
        amountBase: -amount,
        note: tr('settleNote'),
        author: from,
        payer: from,
        split: SplitMode.custom,
        // Вся доля на том, кому вернули: ровно на неё сальдо и уменьшится.
        shares: {to: 10000},
      ),
      label: tr('settleDone'),
    );
  }

  /// Разделить трату с ДРУГОЙ парой.
  ///
  /// Деньги ушли со счёта той пары, которой он принадлежит, — там запись и
  /// остаётся: скрыть её нельзя, иначе остаток общей карты соврёт партнёру.
  /// А пара, за которую платили, получает ту же трату на счёте-расчёте: сумма,
  /// дата, плательщик и доли ей нужны для долга, чужой счёт — нет.
  ///
  /// Так это устроено в Splitwise: в группе видно «Саша заплатил 500», а с
  /// какой карты — не видно никому, кроме самого Саши и его пары.
  void shareWith(String groupId, Transaction op) {
    if (groupId.isEmpty || groupId == space) return;
    final who = op.payer ?? op.author ?? viewer;
    final copy = op.copyWith(
      id: 'shr-$groupId-${op.id}',
      account: outsideAccountOf(who),
    );
    saveOperationTo(groupId, copy, label: tr('storeShared'));
  }

  /// Перенести запись в другое пространство: у Splitwise это правка группы
  /// траты, и людям она нужна — записал не туда, перенёс.
  void moveOperation(Transaction op, String toGroup) {
    if (toGroup.isEmpty || toGroup == space) return;
    deleteOperation(op.id);
    saveOperationTo(toGroup, op, label: tr('storeMoved'));
  }

  /// Записать ПАЧКУ операций разом.
  ///
  /// Выписка из банка — это сто строк, и сто отдельных записей дали бы сто
  /// ступеней отмены: человек нажал бы «Отменить» и убрал одну. Здесь всё
  /// ложится одним движением, и отменяется тоже одним.
  void saveMany(List<Transaction> ops, {String? label}) {
    if (ops.isEmpty) return;
    final list = [..._db.transactions];
    for (final op in ops) {
      final at = list.indexWhere((t) => t.id == op.id);
      if (at >= 0) {
        list[at] = op;
      } else {
        list.add(op);
      }
      _mark('tx:${op.id}');
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    _apply(
      _db.copyWith(transactions: list),
      label: label ?? trf('storeSavedMany', ['${ops.length}']),
    );
  }

  void saveOperation(Transaction op, {String label = 'Записано'}) {
    final list = [..._db.transactions];
    final at = list.indexWhere((t) => t.id == op.id);
    if (at >= 0) {
      list[at] = op;
    } else {
      list.add(op);
    }
    list.sort((a, b) => b.date.compareTo(a.date));
    _mark('tx:${op.id}');
    _apply(_db.copyWith(transactions: list), label: label);
  }

  /// Удалить пачку записей одним действием.
  ///
  /// Пачка ведёт себя КАК ОДНО действие: одна отмена возвращает всё. Двадцать
  /// нажатий «Отменить» после одного удаления — не отмена, а наказание.
  /// Каждая запись при этом отмечается к отправке своим ключом: удаление
  /// уезжает на сервер флагом, иначе запись вернётся первой же дельтой.
  void deleteMany(List<String> ids) {
    if (ids.isEmpty) return;
    final gone = ids.toSet();
    for (final id in gone) {
      _mark('tx:$id');
    }
    _apply(
      _db.copyWith(
        transactions:
            _db.transactions.where((t) => !gone.contains(t.id)).toList(),
      ),
      label: trf('storeDeletedMany', ['${gone.length}']),
    );
  }

  /// Сменить категорию у пачки записей.
  ///
  /// Подкатегория СНИМАЕТСЯ: «Продукты · Кофе», перенесённое в «Кафе»,
  /// оставило бы уточнение от чужой категории, и человек увидел бы
  /// «Кафе · Кофе» из ниоткуда.
  void categorizeMany(
    List<String> ids, {
    required String category,
    String? subcategory,
  }) {
    if (ids.isEmpty) return;
    final chosen = ids.toSet();
    final list = [
      for (final t in _db.transactions)
        if (chosen.contains(t.id))
          t.copyWith(
            category: category,
            subcategory: subcategory,
            clearSubcategory: subcategory == null,
          )
        else
          t,
    ];
    for (final id in chosen) {
      _mark('tx:$id');
    }
    _apply(
      _db.copyWith(transactions: list),
      label: trf('storeMovedMany', ['${chosen.length}']),
    );
  }

  /// Перенести пачку записей на другой счёт.
  ///
  /// Счёт проверяется по списку: запись на счёте, которого нет, пропадает из
  /// всех остатков разом и найтись может только в выгрузке базы.
  void moveMany(List<String> ids, {required String account}) {
    if (ids.isEmpty) return;
    final known = _db.accounts.any((a) => a.name == account);
    if (!known) return;
    final chosen = ids.toSet();
    final list = [
      for (final t in _db.transactions)
        if (chosen.contains(t.id)) t.copyWith(account: account) else t,
    ];
    for (final id in chosen) {
      _mark('tx:$id');
    }
    _apply(
      _db.copyWith(transactions: list),
      label: trf('storeMovedMany', ['${chosen.length}']),
    );
  }

  void deleteOperation(String id) {
    _mark('tx:$id');
    _apply(
      _db.copyWith(transactions: _db.transactions.where((t) => t.id != id).toList()),
      label: 'Удалено',
    );
  }

  void editAccount(
    String name, {
    String? newName,
    int? color,
    String? icon,
    String? owner,
    bool clearOwner = false,
    bool? isPot,
    String? last4,
    bool clearLast4 = false,
    CardBrand? brand,
    AccountKind? kind,
    int? design,
    CardTexture? texture,
    String? bank,
    bool clearBank = false,
    bool clearIcon = false,
  }) {
    final accounts = [..._db.accounts];
    final at = accounts.indexWhere((a) => a.name == name);
    final base = at >= 0
        ? accounts[at]
        : Account(name: name, currency: _db.baseCurrency);
    final next = base.copyWith(
      name: newName ?? base.name,
      color: color,
      icon: icon,
      owner: owner,
      clearOwner: clearOwner,
      isPot: isPot,
      last4: last4,
      clearLast4: clearLast4,
      brand: brand,
      kind: kind,
      design: design,
      texture: texture,
      bank: bank,
      clearBank: clearBank,
      clearIcon: clearIcon,
    );
    if (at >= 0) {
      accounts[at] = next;
    } else {
      accounts.add(next);
    }
    // Счёт опознаётся по имени, поэтому переименование правит поле во всех
    // операциях: иначе они осиротеют.
    final ops = newName == null || newName == name
        ? _db.transactions
        : _db.transactions
            .map((t) => t.account == name ? t.copyWith(account: newName) : t)
            .toList();
    _mark('acc:${next.name}');
    if (newName != null && newName != name) _mark('acc:$name');
    for (final t in ops.where((t) => t.account == next.name)) {
      _mark('tx:${t.id}');
    }
    _apply(_db.copyWith(accounts: accounts, transactions: ops), label: 'Изменено');
  }

  /// Пара приезжает с сервера: приглашением или входом человека из Togetherly.
  /// Локально она кэшируется вместе с базой, чтобы приложение открывалось без
  /// сети тем же видом.
  void setPair(Pair value) {
    final was = _db.pair.groupId;
    final now = value.groupId;

    // Смена пары — это другое хранилище. Записи прежней пары остаться не
    // могут: после распада и новой пары баланс задваивался, а сальдо считало
    // чужие траты (поймано на живом эмуляторе).
    if (was.isNotEmpty && now.isNotEmpty && was != now) {
      _syncMark = 0;
      final mine = _db.transactions.where((t) => _outbox.contains('tx:${t.id}')).toList();
      final myAccounts =
          _db.accounts.where((a) => _outbox.contains('acc:${a.name}')).toList();
      final myCategories =
          _db.categories.where((c) => _outbox.contains('cat:${c.name}')).toList();
      _apply(
        _db.copyWith(
          pair: value,
          transactions: mine,
          accounts: myAccounts,
          categories: myCategories,
        ),
        label: 'Новая пара',
      );
      _saveSettings();
      return;
    }

    // Пара ПОЯВИЛАСЬ там, где её не было: хранилище меняется с личного на
    // общее, и метку синхронизации надо сбросить.
    //
    // Без этого первый круг проходит ещё одиночкой, ставит метку временем
    // сервера, и следующий — уже с парой — просит «что нового с этого
    // момента». Год общей истории под эту мерку не подходит, и человек видит
    // пустое приложение при полном сервере. Поймано на живом эмуляторе
    // 13.09.2026: вход в аккаунт с живой парой давал нули.
    if (was != now && now.isNotEmpty) _syncMark = 0;

    _apply(_db.copyWith(pair: value), label: 'Пара обновлена');
    if (was != now) _saveSettings();
  }

  /// Предложить или обновить договорённость. Своё предложение человек правит
  /// целиком, чужое — только принимает или отклоняет; это же правило стоит и
  /// на сервере, здесь оно ради честного интерфейса.
  void saveAgreement(Agreement a) {
    final list = [..._db.agreements];
    final at = list.indexWhere((x) => x.id == a.id);
    if (at >= 0) {
      list[at] = a;
    } else {
      list.add(a);
    }
    _mark('agr:${a.id}');
    _apply(_db.copyWith(agreements: list), label: 'Договорённость');
  }

  /// Бюджет в паре ставится ДОГОВОРЁННОСТЬЮ: один предлагает, второй
  /// соглашается. Одиночке предлагать некому — у него бюджет пишется сразу,
  /// и эту развилку держит экран, а не два разных пути хранения.
  ///
  /// По одной категории живёт ОДНО предложение: пять «Зал по 600» подряд —
  /// это не пять решений, а пять нажатий, и партнёру пришлось бы отвечать на
  /// каждое.
  void proposeBudget(Budget b, {String note = ''}) {
    final was = _db.budgets
        .where((x) => x.category == b.category && x.subcategory == b.subcategory)
        .map((x) => x.limit)
        .firstOrNull;
    final waiting = _db.agreements
        .where((x) =>
            x.status == AgreementStatus.proposed &&
            x.kind == AgreementKind.limit &&
            x.category == b.category &&
            x.budget?.subcategory == b.subcategory)
        .firstOrNull;
    saveAgreement(Agreement(
      id: waiting?.id ?? 'agr-${DateTime.now().microsecondsSinceEpoch}',
      kind: AgreementKind.limit,
      proposedBy: viewer,
      payload: {
        // Категория и сумма лежат отдельно ради старых записей: до 17.09.2026
        // в договорённости ехали только они, и такие предложения обязаны
        // открываться и сегодня.
        'category': b.category,
        'amount': b.limit,
        'currency': b.currency,
        'budget': b.toJson(),
        if (was != null) 'was': was,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
    ));
  }

  /// Убрать договорённость с глаз. Отклонённое предложение живёт в списке
  /// бюджетов, пока предложивший его не уберёт: молча исчезнувший отказ — это
  /// «партнёр не ответил», а он ответил.
  void dropAgreement(String id) {
    final list = [..._db.agreements]..removeWhere((x) => x.id == id);
    if (list.length == _db.agreements.length) return;
    _mark('agr:$id');
    _apply(_db.copyWith(agreements: list), label: 'Договорённость убрана');
  }

  /// Принятый бюджет становится настоящим: договорённость это решение, а не
  /// запись в блокноте.
  void acceptAgreement(Agreement a, String me) {
    final accepted = a.copyWith(status: AgreementStatus.active, acceptedBy: me);
    var budgets = _db.budgets;
    if (a.kind == AgreementKind.limit) {
      // Бюджет целиком, если он есть; иначе — старая запись из двух полей.
      final next = a.budget ??
          (a.category.isEmpty
              ? null
              : Budget(
                  category: a.category,
                  limit: a.amount,
                  currency: '${a.payload['currency'] ?? _db.baseCurrency}',
                  period: 'monthly',
                ));
      if (next != null) {
        final list = [..._db.budgets];
        final at = list.indexWhere((b) =>
            b.category == next.category && b.subcategory == next.subcategory);
        if (at >= 0) {
          list[at] = next;
        } else {
          list.add(next);
        }
        budgets = list;
        _mark(budgetKey(next.category, next.subcategory));
      }
    }
    final list = [..._db.agreements];
    final at = list.indexWhere((x) => x.id == a.id);
    if (at >= 0) list[at] = accepted;
    _mark('agr:${a.id}');
    _apply(_db.copyWith(agreements: list, budgets: budgets), label: 'Договорились');
  }

  /// Цель заведена или поправлена. Имя — ключ: по нему живёт и счёт цели,
  /// поэтому переименование делается отдельно, [renameGoal].
  void saveGoal(Goal goal) {
    final list = [..._db.goals];
    final at = list.indexWhere((g) => g.name == goal.name);
    if (at >= 0) {
      list[at] = goal;
    } else {
      list.add(goal);
    }
    _mark('goal:${goal.name}');
    _apply(_db.copyWith(goals: list), label: 'Цель сохранена');
  }

  /// Цель убрана, а накопленное остаётся на своём счёте: деньги не исчезают
  /// вместе с записью о том, на что их собирали. Снять их можно вкладом
  /// назад, [withdrawFromGoal].
  void deleteGoal(String name) {
    _mark('goal:$name');
    _apply(
      _db.copyWith(goals: _db.goals.where((g) => g.name != name).toList()),
      label: 'Цель убрана',
    );
  }

  /// Вклад в цель — это ПЕРЕВОД: деньги уходят с кошелька и появляются на
  /// счёте цели. Две записи, а не число в цели: иначе «накоплено» разойдётся
  /// с остатками кошельков на первом же снятии.
  ///
  /// [amount] задаётся в валюте кошелька — уходит именно она; на счёт цели
  /// ложится та же сумма в валюте цели.
  void contributeToGoal(
    Goal goal, {
    required String from,
    required double amount,
    String? payer,
    String? date,
  }) {
    if (amount <= 0) return;
    final wallet = _db.accounts.where((a) => a.name == from).firstOrNull;
    final walletCurrency = wallet?.currency ?? _db.baseCurrency;
    final day = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final who = (payer ?? viewer).trim();
    final base = convert(_db, amount, walletCurrency);
    final onGoal = inCurrency(_db, amount, walletCurrency, goal.currency);

    final out = Transaction(
      id: 'goal-out-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: from,
      currency: walletCurrency,
      amount: -amount,
      amountBase: -base,
      note: 'В цель «${goal.name}»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );
    final into = Transaction(
      id: 'goal-in-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: goalAccountOf(goal.name),
      currency: goal.currency,
      amount: onGoal,
      amountBase: base,
      note: 'Вклад из «$from»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );

    final list = [..._db.transactions, out, into]
      ..sort((a, b) => b.date.compareTo(a.date));
    _mark('tx:${out.id}');
    _mark('tx:${into.id}');
    _apply(_db.copyWith(transactions: list), label: 'Вклад в цель');
  }

  /// Платёж по долгу — такой же перевод, как вклад в цель: деньги уходят с
  /// кошелька на счёт долга, и «осталось» считается из истории, а не из
  /// числа, которое кто-то не забыл поправить.
  void payDebt(
    Debt debt, {
    required String from,
    required double amount,
    String? payer,
    String? date,
  }) {
    if (amount <= 0) return;
    final wallet = _db.accounts.where((a) => a.name == from).firstOrNull;
    final walletCurrency = wallet?.currency ?? _db.baseCurrency;
    final day = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final who = (payer ?? viewer).trim();
    final base = convert(_db, amount, walletCurrency);
    final onDebt = inCurrency(_db, amount, walletCurrency, debt.currency);

    final out = Transaction(
      id: 'debt-out-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: from,
      currency: walletCurrency,
      amount: -amount,
      amountBase: -base,
      note: 'Платёж по «${debt.name}»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );
    final into = Transaction(
      id: 'debt-in-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: debtAccountOf(debt.name),
      currency: debt.currency,
      amount: onDebt,
      amountBase: base,
      note: 'Из «$from»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );

    final list = [..._db.transactions, out, into]
      ..sort((a, b) => b.date.compareTo(a.date));
    _mark('tx:${out.id}');
    _mark('tx:${into.id}');
    _apply(_db.copyWith(transactions: list), label: 'Платёж по долгу');
  }

  /// Округление покупки в копилку: разницу до кратного забирает цель.
  ///
  /// Отдельным переводом, а не тихой правкой суммы: в трекере денег «куда-то
  /// ушло 7,40» хуже, чем отсутствие приёма.
  double roundUpAfter(Transaction op) {
    final rules = _db.rules;
    if (!roundUpApplies(op, rules)) return 0;
    final goal = _db.goals.where((g) => g.name == rules.roundUpGoal).firstOrNull;
    if (goal == null) return 0;
    final extra = roundUpFor(op.amount, rules.roundUpStep);
    if (extra <= 0) return 0;
    contributeToGoal(goal, from: op.account, amount: extra, payer: op.payer ?? op.author,
        date: op.date);
    return extra;
  }

  /// Отработать регулярные записи, которым пора.
  ///
  /// Зовётся на старте и на возврате из фона: приложение открывают не каждый
  /// день, и платёж от пятого числа обязан появиться седьмого, а не пропасть.
  /// Возвращает, сколько записей сработало.
  int runRecurringDue({DateTime? today}) {
    final day = today ?? DateTime.now();
    final due = dueOn(_db, today: day);
    if (due.isEmpty) return 0;

    final iso = day.toIso8601String().substring(0, 10);
    var done = 0;
    for (final r in due) {
      // Дата берётся запланированная, а не сегодняшняя: платёж пятого числа
      // и в отчёте должен стоять пятым.
      final on = r.nextDate.isEmpty ? iso : r.nextDate;
      switch (r.kindOf) {
        case RecurringKind.goal:
          final goal = _db.goals.where((g) => g.name == r.target).firstOrNull;
          if (goal == null) continue;
          contributeToGoal(goal, from: r.account, amount: r.amount,
              payer: r.owner ?? viewer, date: on);
        case RecurringKind.debt:
          final debt = _db.debts.where((d) => d.name == r.target).firstOrNull;
          if (debt == null) continue;
          payDebt(debt, from: r.account, amount: r.amount,
              payer: r.owner ?? viewer, date: on);
        case RecurringKind.income:
        case RecurringKind.expense:
          final income = r.kindOf == RecurringKind.income;
          final stamp = DateTime.now().microsecondsSinceEpoch;
          final who = (r.owner ?? viewer).trim();
          saveOperation(
            Transaction(
              id: 'rec-${r.id}-$on-$stamp',
              date: on,
              kind: income ? TxKind.income : TxKind.expense,
              account: r.account,
              currency: r.currency,
              amount: income ? r.amount : -r.amount,
              amountBase: convert(_db, income ? r.amount : -r.amount, r.currency),
              category: r.category,
              note: r.name,
              author: who.isEmpty ? null : who,
              payer: who.isEmpty ? null : who,
              split: income ? SplitMode.none : _db.pair.defaultSplit,
            ),
            label: 'Регулярное',
          );
      }
      saveRecurring(afterRun(r, on: on));
      done++;
    }
    return done;
  }

  /// Снять из цели обратно на кошелёк. Тот же перевод, только наоборот.
  void withdrawFromGoal(
    Goal goal, {
    required String to,
    required double amount,
    String? payer,
    String? date,
  }) {
    if (amount <= 0) return;
    final wallet = _db.accounts.where((a) => a.name == to).firstOrNull;
    final walletCurrency = wallet?.currency ?? _db.baseCurrency;
    final day = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final who = (payer ?? viewer).trim();
    // Сумму человек вводит в валюте ЦЕЛИ: он смотрит на накопленное.
    final base = convert(_db, amount, goal.currency);
    final onWallet = inCurrency(_db, amount, goal.currency, walletCurrency);

    final out = Transaction(
      id: 'goal-back-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: goalAccountOf(goal.name),
      currency: goal.currency,
      amount: -amount,
      amountBase: -base,
      note: 'Снято на «$to»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );
    final into = Transaction(
      id: 'goal-ret-$stamp',
      date: day,
      kind: TxKind.transfer,
      account: to,
      currency: walletCurrency,
      amount: onWallet,
      amountBase: base,
      note: 'Из цели «${goal.name}»',
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );

    final list = [..._db.transactions, out, into]
      ..sort((a, b) => b.date.compareTo(a.date));
    _mark('tx:${out.id}');
    _mark('tx:${into.id}');
    _apply(_db.copyWith(transactions: list), label: 'Снято из цели');
  }

  /// Перевод между СВОИМИ счетами: две записи, ушло и пришло.
  ///
  /// Одной записью перевод не хранится: деньги должны уйти с одного счёта и
  /// прийти на другой, иначе они просто исчезают. Ровно это и делал экран
  /// записи до 13.09.2026 — списывал и не зачислял никуда.
  ///
  /// Перевод не трата и не доход: в отчётах и бюджетах его нет, он лишь
  /// перекладывает своё из кармана в карман.
  void transfer({
    required String from,
    required String to,
    required double amount,
    String? date,
    String? time,
    String? note,
    String? payer,
  }) {
    if (amount <= 0 || from.isEmpty || to.isEmpty || from == to) return;

    final fromCurrency = _db.accounts
            .where((a) => a.name == from)
            .firstOrNull
            ?.currency ??
        _db.baseCurrency;
    final toCurrency =
        _db.accounts.where((a) => a.name == to).firstOrNull?.currency ??
            _db.baseCurrency;

    final day = date ?? iso(DateTime.now());
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final who = (payer ?? viewer).trim();
    // Сумму вводят в валюте счёта-источника: человек смотрит, сколько снимает.
    final base = convert(_db, amount, fromCurrency);
    final arrived = inCurrency(_db, amount, fromCurrency, toCurrency);

    final out = Transaction(
      id: 'move-out-$stamp',
      date: day,
      time: time,
      kind: TxKind.transfer,
      account: from,
      currency: fromCurrency,
      amount: -amount,
      amountBase: -base,
      note: note,
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );
    final into = Transaction(
      id: 'move-in-$stamp',
      date: day,
      time: time,
      kind: TxKind.transfer,
      account: to,
      currency: toCurrency,
      amount: arrived,
      amountBase: base,
      note: note,
      author: who.isEmpty ? null : who,
      payer: who.isEmpty ? null : who,
    );

    final list = [..._db.transactions, out, into]
      ..sort((a, b) => b.date.compareTo(a.date));
    _mark('tx:${out.id}');
    _mark('tx:${into.id}');
    _apply(_db.copyWith(transactions: list), label: 'Перевод');
  }

  /// Ключ бюджета в очереди: пара «категория, подкатегория» — она же
  /// первичный ключ на сервере. Через json, потому что и в названии
  /// категории, и в подкатегории человек может написать что угодно.
  static String budgetKey(String category, String? subcategory) =>
      'bud:${jsonEncode([category, subcategory ?? ''])}';

  /// Уведомление от банка приехало. Возвращает true, если операция записана
  /// сама; false — если легла в разбор и ждёт человека.
  ///
  /// Ни одно уведомление не пропадает молча: всё, что не записалось, видно
  /// списком, иначе человек не поймёт, работает приложение или нет.
  bool addNotice(ParsedNotice notice) {
    if (modeOf(notice.package) == NoticeMode.off) return false;

    // Без суммы записывать нечего: «Карта использована», код подтверждения,
    // реклама. А сумма без единой примёты операции — карты, магазина или
    // слова направления — это «Кредит до 100 000 MDL», и в очереди вопросов
    // ей не место: человек перестанет туда заходить.
    if (notice.amount <= 0) return false;
    if (!notice.ok && notice.last4 == null && notice.merchant == null) {
      return false;
    }

    // Банк повторяет уведомление, а система пересылает его при каждом
    // обновлении: один отпечаток — одна запись.
    if (_seenNotices.contains(notice.fingerprint)) return false;
    if (_pending.any((n) => n.fingerprint == notice.fingerprint)) return false;

    // Платёж телефоном приходит ДВАЖДЫ: от банка и от кошелька-посредника.
    // Покупка одна, и карточка в разборе обязана быть одна — иначе человек
    // либо запишет трату дважды, либо перестанет заходить в разбор.
    //
    // Побеждает банк: в его уведомлении валюта счёта и остаток. Пришёл он
    // первым — кошелёк молчит; пришёл вторым — вытесняет кошельковую
    // карточку вместе с её отпечатком, иначе следом задавил бы сам себя.
    if (isWalletSender(notice.package)) {
      if (_seenNotices.any((fp) => sameCharge(fp, notice))) return false;
      if (_pending.any((n) => sameCharge(n.fingerprint, notice))) return false;
    } else {
      final twins = _pending
          .where((n) =>
              isWalletSender(n.package) && sameCharge(n.fingerprint, notice))
          .toList();
      for (final twin in twins) {
        _pending.remove(twin);
        _seenNotices.remove(twin.fingerprint);
      }
      // Кошельковая карточка уже стала записью — банк повторяет ту же трату.
      if (twins.isEmpty &&
          _seenNotices.any((fp) =>
              isWalletSender(senderOfFingerprint(fp)) &&
              sameCharge(fp, notice))) {
        return false;
      }
    }

    _logNotice(notice.package, notice.at);

    // Своё правило сильнее и режима источника, и памяти: человек написал его
    // руками под конкретный случай. Правила работают только при живой
    // подписке — иначе это была бы автоматика даром.
    final rule = plusActive ? ruleFor(notice, _noticeRules) : null;

    // «Не читать»: банковская комиссия, код из СМС, реклама. Уведомление
    // уходит молча, но отпечаток запоминается — иначе оно вернётся при
    // следующем проходе.
    if (rule?.act == NoticeDo.skip) {
      _seenNotices.add(notice.fingerprint);
      _saveSettings();
      return false;
    }

    final account = rule?.account != null &&
            db.accounts.any((a) => a.name == rule!.account)
        ? rule!.account
        : accountForNotice(
            db,
            ParsedNoticeRef(package: notice.package, last4: notice.last4),
            learned: _noticeAccounts,
          );

    // Правило «записывать сразу» не требует уверенности разбора: человек сам
    // сказал, что делать с такими списаниями. Счёт всё равно обязателен —
    // положить трату некуда, если его нет.
    final auto = rule != null
        ? rule.act == NoticeDo.record && account != null
        : modeOf(notice.package) == NoticeMode.auto &&
            notice.ok &&
            notice.confidence >= 0.7 &&
            account != null;

    if (auto) {
      // Человек мог записать эту трату руками до пуша: вторая такая же
      // строка хуже, чем ни одной.
      final day = DateTime.fromMillisecondsSinceEpoch(notice.at)
          .toIso8601String()
          .substring(0, 10);
      if (alreadyRecorded(db,
          amount: notice.amount,
          currency: notice.currency,
          date: day,
          account: account)) {
        _seenNotices.add(notice.fingerprint);
        _saveSettings();
        return false;
      }
      acceptNotice(
        notice,
        account: account,
        category: rule?.category,
        subcategory: rule?.subcategory,
        split: rule?.split,
        note: rule?.note,
      );
      return true;
    }

    _pending.insert(0, notice);
    _seenNotices.add(notice.fingerprint);
    _saveSettings();
    notifyListeners();
    return false;
  }

  /// Завести или поправить правило. Новое встаёт ПЕРВЫМ: человек заводит его
  /// под свежий случай, и чаще всего оно и должно побеждать общие.
  void saveNoticeRule(NoticeRule rule) {
    final at = _noticeRules.indexWhere((r) => r.id == rule.id);
    if (at >= 0) {
      _noticeRules[at] = rule;
    } else {
      _noticeRules.insert(0, rule);
    }
    _saveSettings();
    notifyListeners();
  }

  void removeNoticeRule(String id) {
    _noticeRules.removeWhere((r) => r.id == id);
    _saveSettings();
    notifyListeners();
  }

  /// Подвинуть правило: порядок в списке — это приоритет, и менять его должен
  /// человек, а не догадки приложения.
  void moveNoticeRule(int from, int to) {
    if (from < 0 || from >= _noticeRules.length) return;
    final item = _noticeRules.removeAt(from);
    _noticeRules.insert(to.clamp(0, _noticeRules.length), item);
    _saveSettings();
    notifyListeners();
  }

  /// Отметить приход уведомления в журнале источника. Держим месяц: дальше
  /// числа никому не нужны, а файл настроек рос бы без предела.
  void _logNotice(String package, int at) {
    final edge = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    final log = (_noticeLog[package] ?? const <int>[])
        .where((t) => t >= edge)
        .toList()
      ..add(at)
      ..sort();
    _noticeLog[package] = log;
  }

  /// Записать операцию из уведомления. Заодно приложение запоминает выбор:
  /// какой счёт у этой карты и какая категория у этого магазина — со второго
  /// раза оно уже не спрашивает.
  void acceptNotice(
    ParsedNotice notice, {
    required String account,
    String? category,
    String? subcategory,
    String? payer,
    SplitMode? split,
    String? note,
  }) {
    final day = DateTime.fromMillisecondsSinceEpoch(notice.at)
        .toIso8601String()
        .substring(0, 10);
    final income = notice.kind == TxKind.income;
    final signed = income ? notice.amount : -notice.amount;
    final who = payer ?? payerForNotice(db, account, viewer);
    // Валюта берётся ИЗ УВЕДОМЛЕНИЯ, а не у счёта: банк списал десять
    // долларов с молдавской карты — значит трата долларовая, и подмена валюты
    // счётом превратила бы её в десять леев. В базовую сумму идёт пересчёт.
    final currency = notice.currency.isNotEmpty
        ? notice.currency
        : (_db.accounts
                .where((a) => a.name == account)
                .map((a) => a.currency)
                .firstOrNull ??
            _db.baseCurrency);

    saveOperation(
      Transaction(
        id: '$noticePrefix${notice.at}-${notice.amount.toStringAsFixed(2)}',
        date: day,
        kind: income ? TxKind.income : TxKind.expense,
        account: account,
        currency: currency,
        amount: signed,
        amountBase: convert(_db, signed, currency),
        category: category,
        subcategory: subcategory,
        // Заметкой идёт магазин, а не текст пуша: текст чужого уведомления
        // не наш, чтобы возить его по серверам. Правило может написать свою.
        note: (note ?? '').trim().isNotEmpty ? note : notice.merchant,
        author: who,
        payer: who,
        split: income ? SplitMode.none : (split ?? _db.pair.defaultSplit),
      ),
      label: 'Из уведомления',
    );

    _noticeAccounts[noticeKey(notice.package, notice.last4)] = account;
    final merchant = (notice.merchant ?? '').trim().toLowerCase();
    if (merchant.isNotEmpty && (category ?? '').isNotEmpty) {
      // Подкатегория пишется в ту же строку через разделитель: до 14.09.2026
      // помнилась только категория, и уточнение «Продукты · Кофе»
      // сбрасывалось на каждом следующем списании из того же места.
      _noticeCategories[merchant] = (subcategory ?? '').trim().isEmpty
          ? category!
          : '$category$noticeCategorySep$subcategory';
    }
    _pending.removeWhere((n) => n.fingerprint == notice.fingerprint);
    _seenNotices.add(notice.fingerprint);
    _saveSettings();
    notifyListeners();
  }

  /// Пропустить уведомление: реклама, код из СМС, чужая трата.
  void dismissNotice(ParsedNotice notice) {
    _pending.removeWhere((n) => n.fingerprint == notice.fingerprint);
    _seenNotices.add(notice.fingerprint);
    _saveSettings();
    notifyListeners();
  }

  void clearNotices() {
    _pending.clear();
    _saveSettings();
    notifyListeners();
  }

  /// Откуда сейчас читаются траты. `null` — не читается ниоткуда.
  /// Откуда читать: из банка, из кошелька или из обоих.
  ///
  /// Это НАСТРОЙКА, а не сумма шестидесяти переключателей. Раньше выбор
  /// проходил по всему справочнику и заводил запись каждому приложению —
  /// после чего экран «кто присылает» показывал их все, включая те, которых у
  /// человека нет и никогда не было (13.09.2026).
  NoticeSource? _sourceChoice;

  /// Какая пара выбрана, когда их несколько. Настройка УСТРОЙСТВА: человек
  /// может вести деньги с одним партнёром на телефоне и с другим на планшете.
  String _pairChoice = '';
  String get pairChoice => _pairChoice;

  void setPairChoice(String groupId) {
    if (_pairChoice == groupId) return;
    _pairChoice = groupId;
    _saveSettings();
    notifyListeners();
  }
  NoticeSource? get noticeSource {
    if (_sourceChoice != null) return _sourceChoice;
    // Выбора не было: отвечаем по тому, что человек включил руками.
    var wallet = false;
    var bank = false;
    for (final package in _ownSenders) {
      if (modeOf(package) == NoticeMode.off) continue;
      if (isWalletSender(package)) {
        wallet = true;
      } else {
        bank = true;
      }
    }
    if (wallet && bank) return NoticeSource.both;
    if (wallet) return NoticeSource.wallet;
    if (bank) return NoticeSource.bank;
    // Включённых нет. Человек ничего и не выключал — работает умолчание
    // «спрашивают все», и кнопка обязана показывать «Оба», а не пустоту и не
    // «Банк»: кошелёк при этом читается, и подпись врала бы. Выключал —
    // источника действительно нет, и врать тоже нельзя.
    final switchedOff = _senders.values.any((m) => m == NoticeMode.off);
    return switchedOff ? null : NoticeSource.both;
  }

  /// Выбрать источник разом.
  ///
  /// Режим «записывать сразу» у отдельного банка не сбрасывается: человек его
  /// ставил осознанно. А записи, которые лишь повторяли прежний выбор,
  /// снимаются — иначе они пережили бы смену настройки и спорили с ней.
  void setNoticeSource(NoticeSource source) {
    _sourceChoice = source;
    _senders.removeWhere((package, mode) =>
        mode != NoticeMode.auto && mode != defaultModeFor(package, source));

    final wantWallet = source != NoticeSource.bank;
    final wantBank = source != NoticeSource.wallet;
    if (!wantWallet) _pending.removeWhere((n) => isWalletSender(n.package));
    if (!wantBank) _pending.removeWhere((n) => !isWalletSender(n.package));
    _saveSettings();
    notifyListeners();
  }

  /// Как обходиться с уведомлениями этого приложения.
  void setSenderMode(String package, NoticeMode mode) {
    _senders[package] = mode;
    if (mode == NoticeMode.off) {
      _pending.removeWhere((n) => n.package == package);
    }
    _saveSettings();
    notifyListeners();
  }

  /// Источники, которые человек РЕШИЛ читать: режим задан и он не «не читаем».
  /// Банк, оставленный выключенным, сюда не попадает — он живёт в поиске.
  Set<String> get chosenSenders => {
        for (final e in _senders.entries)
          if (e.value != NoticeMode.off) e.key,
      };

  /// Банковские приложения, стоящие на этом телефоне. Заполняет экран
  /// уведомлений при каждом заходе — в файл не пишется, потому что приложения
  /// ставят и удаляют без нас.
  Set<String> _installedSenders = const {};
  Set<String> get installedSenders => _installedSenders;
  set installedSenders(Set<String> value) {
    if (_installedSenders.length == value.length &&
        _installedSenders.containsAll(value)) {
      return;
    }
    _installedSenders = value;
    notifyListeners();
  }

  /// Свои источники: стоят на телефоне, уже присылали или включены руками.
  Set<String> get _ownSenders => {
        ..._installedSenders,
        ...chosenSenders,
        ..._noticeLog.keys,
        for (final n in _pending) n.package,
      };

  /// Базовая валюта: в ней считаются итоги, бюджеты и сводки.
  ///
  /// Задать её человек мог только... нигде — приложение молча жило на лее.
  /// Пара в России видела свои рубли, пересчитанные в леи по курсу 1:1.
  void setBaseCurrency(String code) {
    final next = code.trim().toUpperCase();
    if (next.isEmpty || next == _db.baseCurrency) return;
    _mark('settings:base');
    _apply(
      _db.copyWith(
        baseCurrency: next,
        pair: _db.pair.copyWith(baseCurrency: next),
        // Курс базовой валюты к себе самой не хранится: он всегда единица.
        rates: {..._db.rates}..remove(next),
      ),
      label: 'Валюта',
    );
  }

  /// Курс: сколько базовой валюты стоит единица `code`.
  void setRate(String code, double? value) {
    final key = code.trim().toUpperCase();
    if (key.isEmpty || key == _db.baseCurrency) return;
    final rates = {..._db.rates};
    if (value == null || value <= 0) {
      rates.remove(key);
    } else {
      rates[key] = value;
    }
    _mark('settings:base');
    _apply(_db.copyWith(rates: rates), label: 'Курс');
  }

  /// Откуда пришли курсы и когда. Человек должен видеть, что считает не
  /// приложение по своему усмотрению, а Нацбанк.
  String _ratesSource = '';
  int _ratesAt = 0;
  String get ratesSource => _ratesSource;
  DateTime? get ratesAt =>
      _ratesAt == 0 ? null : DateTime.fromMillisecondsSinceEpoch(_ratesAt);

  /// Курсы целиком — из свежей выдачи сервера.
  void setRates(Map<String, double> next, {String source = ''}) {
    final rates = <String, double>{};
    for (final e in next.entries) {
      final key = e.key.trim().toUpperCase();
      if (key.isEmpty || key == _db.baseCurrency || e.value <= 0) continue;
      rates[key] = e.value;
    }
    if (rates.isEmpty) return;
    if (source.isNotEmpty) {
      _ratesSource = source;
      _ratesAt = DateTime.now().millisecondsSinceEpoch;
      _saveSettings();
    }
    _mark('settings:base');
    _apply(_db.copyWith(rates: {..._db.rates, ...rates}), label: 'Курсы');
  }

  /// Валюты, которые реально встречаются у счетов и операций. Курс нужен
  /// только им: список всех валют мира в настройках никому не поможет.
  List<String> get currenciesInUse {
    final codes = <String>{
      for (final a in _db.accounts) a.currency,
      for (final t in _db.transactions) t.currency,
      for (final g in _db.goals) g.currency,
    }..removeWhere((c) => c.isEmpty || c == _db.baseCurrency);
    final list = codes.toList()..sort();
    return list;
  }

  /// Список строк из выдачи сервера: jsonb приезжает то массивом, то строкой.
  static List<String> _stringList(Object? raw) {
    if (raw is List) {
      return [for (final e in raw) '$e'.trim()]..removeWhere((e) => e.isEmpty);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) {
          return [for (final e in parsed) '$e'.trim()]..removeWhere((e) => e.isEmpty);
        }
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  /// Подкатегории категории: свои цвет и значок у каждой.
  ///
  /// Подкатегория — та же запись `Category`, только с заполненным `parent`:
  /// отдельная таблица не нужна, а цвет со значком достаются ей бесплатно.
  List<Category> subcategoriesOf(String parent) =>
      _db.categories.where((c) => c.parent == parent).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  /// Завести или изменить подкатегорию.
  void saveSubcategory(
    String parent,
    Category next, {
    String? renameFrom,
  }) {
    final list = [..._db.categories];
    final from = renameFrom ?? next.name;
    final at = list.indexWhere((c) => c.name == from && c.parent == parent);

    if (at >= 0 && from != next.name) {
      // Имя подкатегории стоит в операциях: переименование обязано их забрать
      // с собой, иначе трата останется в подкатегории, которой больше нет.
      final ops = _db.transactions
          .map((t) => t.subcategory == from && t.category == parent
              ? t.copyWith(subcategory: next.name)
              : t)
          .toList();
      list[at] = next.copyWith(parent: parent);
      for (final t in ops) {
        if (t.subcategory == next.name) _mark('tx:${t.id}');
      }
      _mark('cat:${next.name}');
      _mark('cat:$from');
      _apply(
        _db.copyWith(categories: list, transactions: ops),
        label: 'Подкатегория',
      );
      return;
    }

    if (at >= 0) {
      list[at] = next.copyWith(parent: parent);
    } else {
      list.add(next.copyWith(parent: parent));
    }
    _mark('cat:${next.name}');
    _apply(_db.copyWith(categories: list), label: 'Подкатегория');
  }

  /// Убрать подкатегорию. Операции при этом остаются в своей категории — они
  /// просто теряют уточнение, а не деньги.
  void deleteSubcategory(String parent, String name) {
    final list = _db.categories
        .where((c) => !(c.name == name && c.parent == parent))
        .toList();
    final ops = _db.transactions
        .map((t) => t.category == parent && t.subcategory == name
            ? t.copyWith(clearSubcategory: true)
            : t)
        .toList();
    for (final t in _db.transactions) {
      if (t.category == parent && t.subcategory == name) _mark('tx:${t.id}');
    }
    _mark('cat:$name');
    _apply(
      _db.copyWith(categories: list, transactions: ops),
      label: 'Подкатегория убрана',
    );
  }

  /// Правила пары: распределение дохода, округление, пересмотр, общий кошелёк.
  void setRules(Rules next) {
    _mark('settings:base');
    _apply(_db.copyWith(rules: next), label: 'Правила');
  }

  /// Долг заведён или поправлен. Имя — ключ, по нему живёт и счёт долга.
  void saveDebt(Debt debt) {
    final list = [..._db.debts];
    final at = list.indexWhere((d) => d.name == debt.name);
    if (at >= 0) {
      list[at] = debt;
    } else {
      list.add(debt);
    }
    _mark('debt:${debt.name}');
    _apply(_db.copyWith(debts: list), label: 'Долг сохранён');
  }

  /// Долг убран, а платежи по нему остаются: деньги ушли, и стирать их
  /// вместе с записью о долге нельзя.
  void deleteDebt(String name) {
    _mark('debt:$name');
    _apply(
      _db.copyWith(debts: _db.debts.where((d) => d.name != name).toList()),
      label: 'Долг убран',
    );
  }

  /// Строка плана на месяц. Ноль убирает её: «нуль на категорию» и «категория
  /// не в плане» — одно и то же.
  void setPlanItem(PlanItem item) {
    final list = [..._db.plan];
    final at = list.indexWhere((x) => x.key == item.key);
    if (item.amount.abs() < 0.005) {
      if (at >= 0) list.removeAt(at);
    } else if (at >= 0) {
      list[at] = item;
    } else {
      list.add(item);
    }
    _mark('plan:${item.key}');
    _apply(_db.copyWith(plan: list), label: 'План');
  }

  /// Весь план месяца одной правкой: так его раскладывают по правилу
  /// распределения, и дробить это на двадцать записей в очереди незачем.
  void setPlanForMonth(String month, List<PlanItem> items) {
    final rest = _db.plan.where((x) => x.month != month).toList();
    final was = {for (final x in _db.plan.where((x) => x.month == month)) x.key: x};
    final now = {for (final x in items) x.key: x};
    for (final key in {...was.keys, ...now.keys}) {
      if (was[key]?.amount != now[key]?.amount) _mark('plan:$key');
    }
    _apply(
      _db.copyWith(plan: [...rest, ...items.where((x) => x.amount.abs() >= 0.005)]),
      label: 'План на месяц',
    );
  }

  /// Разметка категории: нужда, желание или сбережение.
  void setCategoryBucket(String name, Bucket bucket) {
    final list = [..._db.categories];
    final at = list.indexWhere((c) => c.name == name);
    if (at < 0) return;
    list[at] = list[at].copyWith(bucket: bucket);
    _mark('cat:$name');
    _apply(_db.copyWith(categories: list), label: 'Разметка');
  }

  /// Регулярная запись: платёж, доход, взнос в цель или платёж по долгу.
  void saveRecurring(Recurring item) {
    final list = [..._db.recurring];
    final at = list.indexWhere((r) => r.id == item.id);
    if (at >= 0) {
      list[at] = item;
    } else {
      list.add(item);
    }
    _mark('rec:${item.id}');
    _apply(_db.copyWith(recurring: list), label: 'Регулярное');
  }

  void deleteRecurring(String id) {
    _mark('rec:$id');
    _apply(
      _db.copyWith(recurring: _db.recurring.where((r) => r.id != id).toList()),
      label: 'Регулярное убрано',
    );
  }

  /// Как пара делит общие траты по умолчанию и в каких долях.
  ///
  /// Доли живут в базисных пунктах (сумма 10000): проценты с одним знаком
  /// после запятой в целых не удержать, а деление 60/40 от 17,45 обязано
  /// сойтись до копейки.
  void setSplitRule(SplitMode mode, {Map<String, int>? shares}) {
    final pair = _db.pair;
    final members = [
      for (final m in pair.members)
        Member(
          uid: m.uid,
          name: m.name,
          avatarUrl: m.avatarUrl,
          color: m.color,
          incomeShareBp: shares?[m.uid] ?? m.incomeShareBp,
        ),
    ];
    _mark('settings:base');
    _apply(
      _db.copyWith(
        pair: Pair(
          groupId: pair.groupId,
          members: members,
          baseCurrency: pair.baseCurrency,
          defaultSplit: mode,
        ),
      ),
      label: 'Правило дележа',
    );
  }

  /// Реплика под операцией. Автора ставит сервер по сессии, поэтому здесь
  /// он нужен только для того, чтобы своя реплика сразу появилась на экране.
  void saveComment(Comment c) {
    if (c.isEmpty) return;
    final list = [..._db.comments];
    final at = list.indexWhere((x) => x.id == c.id);
    if (at >= 0) {
      list[at] = c;
    } else {
      list.add(c);
    }
    list.sort((a, b) => a.created.compareTo(b.created));
    _mark('cm:${c.id}');
    _apply(_db.copyWith(comments: list), label: null);
  }

  void deleteComment(String id) {
    _mark('cm:$id');
    _apply(
      _db.copyWith(comments: _db.comments.where((c) => c.id != id).toList()),
      label: null,
    );
  }

  /// Разговор под одной операцией, по порядку сказанного.
  List<Comment> commentsOf(String txId) =>
      [for (final c in _db.comments) if (c.txId == txId) c]
        ..sort((a, b) => a.created.compareTo(b.created));

  /// Список имён из поля jsonb: строкой или уже разобранным списком.
  static List<String> _names(Object? raw) {
    if (raw is List) return [for (final x in raw) '$x'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is List) return [for (final x in parsed) '$x'];
      } catch (_) {
        // Мусор в колонке не должен ронять весь круг синхронизации.
      }
    }
    return const [];
  }

  void setBudgets(List<Budget> list) {
    // Лимит — общее имущество пары, и уезжать он обязан: до этого лимит,
    // принятый договорённостью, оставался на устройстве согласившегося, а у
    // партнёра была активная договорённость без единой цифры.
    final was = {
      for (final b in _db.budgets) budgetKey(b.category, b.subcategory): b,
    };
    final now = {
      for (final b in list) budgetKey(b.category, b.subcategory): b,
    };
    for (final key in {...was.keys, ...now.keys}) {
      final before = was[key], after = now[key];
      if (before == null ||
          after == null ||
          before.limit != after.limit ||
          before.currency != after.currency ||
          before.period != after.period ||
          before.rollover != after.rollover ||
          before.days != after.days ||
          before.startDate != after.startDate ||
          before.name != after.name ||
          before.icon != after.icon ||
          before.color != after.color ||
          before.extraCategories.join('|') != after.extraCategories.join('|') ||
          before.accounts.join('|') != after.accounts.join('|')) {
        _mark(key);
      }
    }
    _apply(_db.copyWith(budgets: list), label: 'Бюджеты изменены');
  }

  /// Стартовый набор уже клали. Флаг переживает перезапуск: человек, стерший
  /// категории нарочно, не должен получать их обратно каждое утро.
  bool _categoriesSeeded = false;
  bool get categoriesSeeded => _categoriesSeeded;

  /// Чистое место: ни категорий, ни операций. Только сюда кладётся набор сам,
  /// без спроса — затирать чужое он не должен.
  bool get categoriesUntouched =>
      _db.categories.isEmpty && _db.transactions.isEmpty;

  /// Положить стартовый набор.
  ///
  /// `replace` стирает прежние категории — это «вернуть стандартные» из
  /// настроек. Без него набор ДОБАВЛЯЕТСЯ, и уже заведённые руками имена
  /// остаются: категория опознаётся именем, и перезапись унесла бы вместе с
  /// собой цвет, значок и привязку к счетам.
  void seedCategories({bool replace = false}) {
    final preset = presetCategories();
    final list = <Category>[];
    if (replace) {
      list.addAll(preset);
    } else {
      final have = {for (final c in _db.categories) '${c.parent ?? ''}/${c.name}'};
      list
        ..addAll(_db.categories)
        ..addAll(preset.where((c) => !have.contains('${c.parent ?? ''}/${c.name}')));
    }
    _categoriesSeeded = true;
    _saveSettings();
    setCategories(list);
  }

  /// Убрать все категории. Операции при этом НЕ трогаются: деньги записаны, и
  /// стирать их вместе с ярлыком нельзя. Трата просто теряет категорию.
  void clearCategories() {
    _categoriesSeeded = true;
    _saveSettings();
    setCategories(const []);
  }

  void setCategories(List<Category> list) {
    final was = {for (final c in _db.categories) c.name};
    for (final c in list) {
      _mark('cat:${c.name}');
    }
    for (final gone in was.where((n) => list.every((c) => c.name != n))) {
      _mark('cat:$gone');
    }
    _apply(_db.copyWith(categories: list), label: 'Категории изменены');
  }

  /// Переименование категории правит поле во всех операциях: категория
  /// опознаётся по имени, и старые записи иначе осиротеют.
  void renameCategory(String from, String to) {
    if (from == to || to.trim().isEmpty) return;
    final categories = _db.categories
        .map((c) => c.name == from
            ? c.copyWith(name: to)
            : (c.parent == from ? c.copyWith(parent: to) : c))
        .toList();
    final ops = _db.transactions
        .map((t) => t.category == from ? t.copyWith(category: to) : t)
        .toList();
    final budgets = _db.budgets
        .map((b) => b.category == from
            ? Budget(
                category: to,
                subcategory: b.subcategory,
                limit: b.limit,
                currency: b.currency,
                period: b.period)
            : b)
        .toList();
    _apply(
      _db.copyWith(categories: categories, transactions: ops, budgets: budgets),
      label: 'Переименовано',
    );
  }

  /// Влить дельту с сервера.
  ///
  /// Сервер — источник правды по чужим правкам, но НЕ затирает то, что у нас
  /// ещё в очереди: иначе своя свежая запись пропадала бы на глазах, пока
  /// push не доехал. Поэтому запись из очереди пропускается.
  void applyRemote(Map<String, dynamic> payload) {
    final txs = [..._db.transactions];
    final accounts = [..._db.accounts];
    final categories = [..._db.categories];

    for (final raw in (payload['transactions'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final id = '${j['id']}';
      if (_outbox.contains('tx:$id')) continue;
      final at = txs.indexWhere((t) => t.id == id);
      if (j['deleted'] == true) {
        if (at >= 0) txs.removeAt(at);
        continue;
      }
      final tx = _txFromServer(j);
      if (at >= 0) {
        txs[at] = tx;
      } else {
        txs.add(tx);
      }
    }

    for (final raw in (payload['accounts'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final name = '${j['name']}';
      if (_outbox.contains('acc:$name')) continue;
      final at = accounts.indexWhere((a) => a.name == name);
      if (j['deleted'] == true) {
        if (at >= 0) accounts.removeAt(at);
        continue;
      }
      final acc = Account(
        name: name,
        currency: '${j['currency'] ?? _db.baseCurrency}',
        color: _hexColor(j['color']),
        icon: _orNull(j['icon']),
        owner: _orNull(j['owner_uid']),
        isPot: j['is_pot'] == true,
        last4: _orNull(j['last4']),
        brand: cardBrandOf(j['brand'] as String?),
        kind: accountKindOf(j['card_kind'] as String?),
        design: (j['design'] as num?)?.toInt() == -1
            ? null
            : (j['design'] as num?)?.toInt(),
        texture: cardTextureOf(j['texture'] as String?),
        bank: _orNull(j['bank']),
      );
      if (at >= 0) {
        accounts[at] = acc;
      } else {
        accounts.add(acc);
      }
    }

    for (final raw in (payload['categories'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final name = '${j['name']}';
      if (_outbox.contains('cat:$name')) continue;
      final at = categories.indexWhere((c) => c.name == name);
      if (j['deleted'] == true) {
        if (at >= 0) categories.removeAt(at);
        continue;
      }
      final cat = Category(
        name: name,
        parent: _orNull(j['parent']),
        color: _hexColor(j['color']),
        icon: _orNull(j['icon']),
        bucket: bucketOf(j['bucket'] as String?),
        // Сервер отдаёт список строкой JSON или массивом — принимаем оба.
        accounts: _stringList(j['accounts']),
      );
      if (at >= 0) {
        categories[at] = cat;
      } else {
        categories.add(cat);
      }
    }

    final debts = [..._db.debts];
    for (final raw in (payload['debts'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final name = '${j['name'] ?? ''}';
      if (name.isEmpty) continue;
      if (_outbox.contains('debt:$name')) continue;
      final at = debts.indexWhere((d) => d.name == name);
      if (j['deleted'] == true) {
        if (at >= 0) debts.removeAt(at);
        continue;
      }
      final d = Debt.fromJson(j);
      if (at >= 0) {
        debts[at] = d;
      } else {
        debts.add(d);
      }
    }

    final plan = [..._db.plan];
    for (final raw in (payload['plan'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final item = PlanItem.fromJson(j);
      if (item.month.isEmpty || item.name.isEmpty) continue;
      if (_outbox.contains('plan:${item.key}')) continue;
      final at = plan.indexWhere((x) => x.key == item.key);
      if (j['deleted'] == true) {
        if (at >= 0) plan.removeAt(at);
        continue;
      }
      if (at >= 0) {
        plan[at] = item;
      } else {
        plan.add(item);
      }
    }

    final recurring = [..._db.recurring];
    for (final raw in (payload['recurring'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final id = '${j['id'] ?? ''}';
      if (id.isEmpty) continue;
      if (_outbox.contains('rec:$id')) continue;
      final at = recurring.indexWhere((r) => r.id == id);
      if (j['deleted'] == true) {
        if (at >= 0) recurring.removeAt(at);
        continue;
      }
      final r = Recurring.fromJson(j);
      if (at >= 0) {
        recurring[at] = r;
      } else {
        recurring.add(r);
      }
    }

    final comments = [..._db.comments];
    for (final raw in (payload['comments'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final id = '${j['id']}';
      if (_outbox.contains('cm:$id')) continue;
      final at = comments.indexWhere((c) => c.id == id);
      if (j['deleted'] == true) {
        if (at >= 0) comments.removeAt(at);
        continue;
      }
      final c = Comment.fromJson(j);
      if (at >= 0) {
        comments[at] = c;
      } else {
        comments.add(c);
      }
    }
    comments.sort((a, b) => a.created.compareTo(b.created));

    final budgets = [..._db.budgets];
    for (final raw in (payload['budgets'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final category = '${j['category'] ?? ''}';
      if (category.isEmpty) continue;
      final sub = _orNull(j['subcategory']);
      // Личный лимит партнёра нас не касается: сервер их не фильтрует, а
      // показывать чужое «мне на кофе» в общих бюджетах нельзя.
      final scope = '${j['scope'] ?? 'shared'}';
      if (scope.startsWith('personal:') && scope != 'personal:$viewer') continue;
      if (_outbox.contains(budgetKey(category, sub))) continue;
      final at = budgets
          .indexWhere((b) => b.category == category && (b.subcategory ?? '') == (sub ?? ''));
      if (j['deleted'] == true) {
        if (at >= 0) budgets.removeAt(at);
        continue;
      }
      final b = Budget(
        category: category,
        subcategory: sub,
        limit: (j['limit_value'] as num?)?.toDouble() ?? 0,
        currency: '${j['currency'] ?? _db.baseCurrency}',
        period: '${j['period'] ?? 'monthly'}',
        rollover: j['rollover'] == true,
        days: (j['days'] as num?)?.toInt(),
        startDate: (j['start_date'] as String?)?.isEmpty ?? true
            ? null
            : '${j['start_date']}',
        name: '${j['name'] ?? ''}'.trim().isEmpty ? null : '${j['name']}'.trim(),
        icon: '${j['icon'] ?? ''}'.trim().isEmpty ? null : '${j['icon']}',
        color: (j['color'] as num?)?.toInt(),
        // Списки приезжают из jsonb строкой или уже разобранными — сервер
        // отдаёт `SELECT *`, и тип зависит от драйвера.
        extraCategories: _names(j['extra_categories']),
        accounts: _names(j['accounts']),
      );
      if (at >= 0) {
        budgets[at] = b;
      } else {
        budgets.add(b);
      }
    }

    final goals = [..._db.goals];
    for (final raw in (payload['goals'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final name = '${j['name']}';
      if (_outbox.contains('goal:$name')) continue;
      final at = goals.indexWhere((g) => g.name == name);
      if (j['deleted'] == true) {
        if (at >= 0) goals.removeAt(at);
        continue;
      }
      final g = Goal(
        name: name,
        target: (j['target'] as num?)?.toDouble() ?? 0,
        currency: '${j['currency'] ?? _db.baseCurrency}',
        deadline: _orNull(j['deadline']),
        kind: goalKindOf(j['kind'] as String?),
        months: (j['months'] as num?)?.toInt() ?? 0,
      );
      if (at >= 0) {
        goals[at] = g;
      } else {
        goals.add(g);
      }
    }

    final agreements = [..._db.agreements];
    for (final raw in (payload['agreements'] as List?) ?? const []) {
      final j = (raw as Map).cast<String, dynamic>();
      final id = '${j['id']}';
      if (_outbox.contains('agr:$id')) continue;
      final at = agreements.indexWhere((a) => a.id == id);
      if (j['deleted'] == true) {
        if (at >= 0) agreements.removeAt(at);
        continue;
      }
      final a = Agreement.fromJson(j);
      if (at >= 0) {
        agreements[at] = a;
      } else {
        agreements.add(a);
      }
    }

    // Настройки пары — общее имущество: базовая валюта, курсы и правило
    // дележа живут на сервере, иначе у партнёра остаётся своя базовая валюта
    // и одна и та же трата даёт на двух устройствах разные числа.
    //
    // Своя правка, ещё не уехавшая, сильнее серверной: иначе pull затирал бы
    // только что выбранную валюту.
    var baseCurrency = _db.baseCurrency;
    var rates = _db.rates;
    var defaultSplit = _db.pair.defaultSplit;
    var rules = _db.rules;
    var shares = <String, int>{};
    final raw = payload['settings'];
    if (raw is Map && !_outbox.contains('settings:base')) {
      final j = raw.cast<String, dynamic>();
      final code = '${j['base_currency'] ?? ''}'.trim();
      if (code.isNotEmpty) baseCurrency = code;
      final table = j['rates'];
      if (table is Map && table.isNotEmpty) {
        rates = {
          for (final e in table.entries)
            '${e.key}': (e.value as num?)?.toDouble() ?? 0,
        }..removeWhere((_, v) => v <= 0);
      }
      defaultSplit = splitModeOf(j['default_split'] as String?);
      rules = Rules.fromJson(j);
      final byUid = j['income_shares'];
      if (byUid is Map) {
        shares = {
          for (final e in byUid.entries) '${e.key}': (e.value as num?)?.toInt() ?? 0,
        };
      }
    }

    // Состав пары приходит вместе с дельтой: имена берутся из аккаунтов, а
    // не из заглушки в записи группы.
    var pair = _db.pair;
    final rawMembers = (payload['members'] as List?) ?? const [];
    if (rawMembers.isNotEmpty) {
      pair = Pair(
        groupId: pair.groupId,
        baseCurrency: pair.baseCurrency,
        defaultSplit: defaultSplit,
        members: [
          for (final raw in rawMembers)
            () {
              final j = (raw as Map).cast<String, dynamic>();
              final uid = '${j['uid']}';
              final was = pair.byUid(uid);
              final name = '${j['name'] ?? ''}'.trim();
              return Member(
                uid: uid,
                name: name.isEmpty ? (was?.name ?? 'Партнёр') : name,
                avatarUrl: _orNull(j['avatar_url']) ?? was?.avatarUrl,
                incomeShareBp: shares[uid] ?? was?.incomeShareBp ?? 5000,
              );
            }(),
        ],
      );
    }

    if (rawMembers.isEmpty && (defaultSplit != pair.defaultSplit || shares.isNotEmpty)) {
      pair = Pair(
        groupId: pair.groupId,
        baseCurrency: pair.baseCurrency,
        defaultSplit: defaultSplit,
        members: [
          for (final m in pair.members)
            Member(
              uid: m.uid,
              name: m.name,
              avatarUrl: m.avatarUrl,
              color: m.color,
              incomeShareBp: shares[m.uid] ?? m.incomeShareBp,
            ),
        ],
      );
    }

    txs.sort((a, b) => b.date.compareTo(a.date));
    _syncMark = (payload['now'] as num?)?.toInt() ?? _syncMark;
    _apply(
      _db.copyWith(
        baseCurrency: baseCurrency,
        rates: rates,
        rules: rules,
        debts: debts,
        plan: plan,
        recurring: recurring,
        transactions: txs,
        accounts: accounts,
        categories: categories,
        budgets: budgets,
        goals: goals,
        comments: comments,
        agreements: agreements,
        pair: pair,
      ),
      label: null,
    );
    _saveSettings();
  }

  static Transaction _txFromServer(Map<String, dynamic> j) => Transaction(
        id: '${j['id']}',
        date: '${j['date'] ?? ''}',
        kind: kindOf(j['kind'] as String?),
        account: '${j['account'] ?? ''}',
        currency: '${j['currency'] ?? 'MDL'}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        amountBase: (j['amount_base'] as num?)?.toDouble() ?? 0,
        category: _orNull(j['category']),
        subcategory: _orNull(j['subcategory']),
        note: _orNull(j['note']),
        hidden: j['hidden'] == true,
        author: _orNull(j['author']),
        payer: _orNull(j['payer']),
        split: splitModeOf(j['split'] as String?),
        shares: (j['shares'] as Map?)?.map((k, v) => MapEntry('$k', (v as num).toInt())),
        secret: j['secret'] == true,
        revealAt: _orNull(j['reveal_at']),
        time: _orNull(j['time']),
      );

  static String? _orNull(Object? v) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? null : s;
  }

  static int? _hexColor(Object? raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return null;
    final n = int.tryParse(s.replaceAll('#', ''), radix: 16);
    return n == null ? null : 0xFF000000 | n;
  }

  /// Подсунуть базу без диска: нужен снимкам экранов в тестах.
  @visibleForTesting
  void importBackupForTest(Database next) {
    _db = next;
    _ready = true;
  }

  /// Стереть всё с устройства.
  ///
  /// Метка синхронизации сбрасывается ВМЕСТЕ с данными. Без этого следующий
  /// круг просит у сервера «что нового с прошлого раза», получает пустую
  /// дельту — и приложение остаётся пустым, хотя на сервере всё на месте.
  /// Поймано на живом эмуляторе 13.09.2026: аккаунт вернулся входом, пара
  /// вернулась, а деньги нет.
  ///
  /// Очередь отправки тоже чистится: её ключи указывают на записи, которых
  /// больше нет, и первый же круг попытался бы удалить их на сервере.
  void wipe() {
    _syncMark = 0;
    _outbox.clear();
    _saveSettings();
    _apply(const Database(), label: 'Стёрто');
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'format': 'orbita-backup',
        'version': 1,
        'data': _db.toJson(),
      });

  @override
  void dispose() {
    _writeTimer?.cancel();
    super.dispose();
  }
}

enum ThemeChoice { light, dark, system }
