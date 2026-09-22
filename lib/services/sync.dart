import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'session.dart';

/// Синхронизация с moneypath: тянем дельту, отдаём свои правки.
///
/// Дельта идёт по метке времени сервера (`updated`, миллисекунды): клиент
/// помнит последнюю и просит всё, что новее. Полная выгрузка у пары с годом
/// истории — это мегабайты на каждое открытие приложения.
///
/// Приватность НЕ фильтруется здесь: сервер не отдаёт чужой личный кошелёк и
/// урезает чужую скрытую трату сам. Клиент рисует то, что пришло, и не знает,
/// что от него скрыли.
class Sync extends ChangeNotifier {
  Sync({required this.session, required this.store}) {
    // Запись должна уезжать сразу, а не ждать свёртывания приложения:
    // партнёр видит трату через секунды, а не через полдня.
    store.addListener(_onStoreChanged);
  }

  final Session session;
  final Store store;

  Timer? _soon;

  /// Повтор после обрыва. Сеть на телефоне рвётся постоянно — в лифте, в
  /// метро, при переходе с Wi-Fi на мобильную, — и один такой обрыв оставлял
  /// на экране красную строку «Сервер не отвечает» до следующего круга.
  /// Человек видел её и решал, что сломан сервер (13.09.2026).
  Timer? _retry;
  int _tries = 0;

  /// Задержки повторов: 5 секунд, 15, 45, полторы минуты и дальше каждые пять.
  /// Дольше ждать незачем, чаще — греть батарею в самолётном режиме.
  static const _backoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(seconds: 90),
    Duration(minutes: 5),
  ];

  bool _busy = false;
  bool get busy => _busy;

  String? _error;

  /// Ошибка, которую СТОИТ показывать.
  ///
  /// Пока назначен повтор, человеку показывать нечего: приложение уже само
  /// разбирается, и красная строка только пугает.
  String? get error => _retry == null ? _error : null;

  /// Идёт ли повтор после обрыва — для честной подписи «пробуем ещё раз».
  bool get retrying => _retry != null;

  DateTime? _lastOk;
  DateTime? get lastOk => _lastOk;

  /// Куда синхронизируемся: в пару или в своё личное хранилище.
  ///
  /// Одиночка с аккаунтом тоже держит данные на сервере — под своим uid.
  /// Иначе потеря телефона стирает год записей у того, кто просто хотел
  /// трекер и аккаунт завёл ради переноса на новый телефон.
  String get scope {
    final pair = store.db.pair.groupId;
    return pair.isNotEmpty ? pair : session.uid;
  }

  bool get possible => session.signedIn && scope.isNotEmpty;

  /// Правки склеиваются: человек правит сумму цифра за цифрой, и круг на
  /// каждое нажатие был бы десятком запросов подряд.
  void _onStoreChanged() {
    if (store.outbox.isEmpty || !possible) return;
    _soon?.cancel();
    _soon = Timer(const Duration(seconds: 2), run);
  }

  @override
  void dispose() {
    _soon?.cancel();
    _retry?.cancel();
    store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// Полный круг: отдать накопленное, забрать чужое.
  ///
  /// Сначала push, потом pull: иначе свежая правка партнёра, пришедшая в pull,
  /// была бы затёрта нашим отложенным push с прежним значением.
  Future<void> run() async {
    if (_busy || !possible) return;
    _retry?.cancel();
    _retry = null;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _refreshPair();
      await _push();
      await _pull();
      // Соседние пары: человек ведёт учёт с несколькими людьми сразу, и пока
      // он смотрит на одну, вторая обязана жить своей жизнью — у неё своя
      // очередь, своя метка и свои участники.
      for (final other in store.spaces) {
        if (other == scope || other.isEmpty) continue;
        await _push(space: other);
        await _pull(space: other);
      }
      _lastOk = DateTime.now();
      _tries = 0;
    } on SessionError catch (e) {
      _error = e.message;
      _scheduleRetry(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Назначить повтор. Не всякая беда этого стоит: если сервер сказал «это не
  /// ваша пара» или «нужен вход», повторять бессмысленно — ответ не изменится,
  /// и человеку надо показать его слова.
  void _scheduleRetry(SessionError e) {
    final worthRetry = e.status == null || e.status! >= 500 || e.status == 429;
    if (!worthRetry) {
      _tries = 0;
      return;
    }
    final wait = _backoff[_tries < _backoff.length ? _tries : _backoff.length - 1];
    _tries++;
    _retry = Timer(wait, () {
      _retry = null;
      run();
    });
  }

  /// Состав пары живёт на сервере и меняется без нас: партнёр сменил имя,
  /// пара собралась на его устройстве. Если участников нет вовсе, тянем их —
  /// без имён лента показывает «партнёр» вместо человека.
  Future<void> _refreshPair() async {
    if (store.db.pair.members.length > 1) return;
    // «Только я» — тоже выбор человека, и пара его не отменяет: в личном
    // пространстве участник один, и без этой проверки круг синхронизации
    // возвращал пару поверх выбора вместе с потерей личных записей.
    if (store.soloChosenBy(session.uid)) return;
    final loaded = await session.loadPair(preferred: store.pairChoice);
    if (loaded != null && loaded.groupId.isNotEmpty) store.setPair(loaded);
  }

  Future<void> _push({String? space}) async {
    final where = space ?? scope;
    final pending = store.outboxOf(where);
    if (pending.isEmpty) return;

    final db = store.dbOf(where);
    final body = <String, dynamic>{'group_id': where};

    final txs = <Map<String, dynamic>>[];
    final accounts = <Map<String, dynamic>>[];
    final categories = <Map<String, dynamic>>[];
    final agreements = <Map<String, dynamic>>[];
    final goals = <Map<String, dynamic>>[];
    final budgets = <Map<String, dynamic>>[];
    final comments = <Map<String, dynamic>>[];
    final debts = <Map<String, dynamic>>[];
    final plan = <Map<String, dynamic>>[];
    final recurring = <Map<String, dynamic>>[];

    for (final key in pending) {
      final i = key.indexOf(':');
      if (i < 0) continue;
      final kind = key.substring(0, i);
      final id = key.substring(i + 1);

      switch (kind) {
        case 'tx':
          final tx = db.transactions.firstWhere((t) => t.id == id,
              orElse: () => const Transaction(
                    id: '', date: '', kind: TxKind.expense, account: '',
                    currency: '', amount: 0, amountBase: 0,
                  ));
          if (tx.id.isEmpty) {
            // Запись удалили локально: сервер узнаёт об этом флагом, а не
            // молчанием. Иначе она вернётся со следующим pull.
            txs.add({'id': id, 'deleted': true});
          } else {
            txs.add(_txBody(tx));
          }
          break;
        case 'acc':
          final acc = db.accounts.where((a) => a.name == id).firstOrNull;
          accounts.add(acc == null
              ? {'name': id, 'deleted': true}
              : {
                  'name': acc.name,
                  'currency': acc.currency,
                  'color': acc.color == null
                      ? ''
                      : '#${(acc.color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  'icon': acc.icon ?? '',
                  'owner_uid': acc.owner ?? '',
                  'is_pot': acc.isPot,
                  'last4': acc.last4 ?? '',
                  'brand': cardBrandName(acc.brand),
                  'card_kind': accountKindName(acc.kind),
                  'design': acc.design ?? -1,
                  'texture': cardTextureName(acc.texture),
                  'bank': acc.bank ?? '',
                });
          break;
        case 'debt':
          final d = db.debts.where((x) => x.name == id).firstOrNull;
          debts.add(d == null
              ? {'name': id, 'deleted': true}
              : {
                  'name': d.name,
                  'kind': debtKindName(d.kind),
                  'principal': d.principal,
                  'rate': d.rate,
                  'min_payment': d.minPayment,
                  'currency': d.currency,
                  'opened': d.opened ?? '',
                  'due_day': d.dueDay,
                  'owner_uid': d.owner ?? '',
                });
          break;
        case 'plan':
          // В ключе лежит «месяц|вид|имя» — первичный ключ строки плана.
          final parts = id.split('|');
          if (parts.length < 3) break;
          final item = db.plan.where((x) => x.key == id).firstOrNull;
          plan.add(item == null
              ? {
                  'month': parts[0],
                  'item_kind': parts[1],
                  'item_name': parts.sublist(2).join('|'),
                  'deleted': true,
                }
              : {
                  'month': item.month,
                  'item_kind': planItemKindName(item.kind),
                  'item_name': item.name,
                  'amount': item.amount,
                });
          break;
        case 'rec':
          final r = db.recurring.where((x) => x.id == id).firstOrNull;
          recurring.add(r == null
              ? {'id': id, 'deleted': true}
              : {
                  'id': r.id,
                  'name': r.name,
                  'amount': r.amount,
                  'currency': r.currency,
                  'account': r.account,
                  'category': r.category ?? '',
                  'interval_rule': r.interval,
                  'next_date': r.nextDate,
                  'kind': r.kind,
                  'active': r.active,
                  'goal': r.target,
                  'last_run': r.lastRun,
                  'owner_uid': r.owner ?? '',
                  'days': r.days,
                  // Значок и цвет: без них подписка у партнёра теряет лицо.
                  'icon': r.icon ?? '',
                  'color': r.color,
                });
          break;
        case 'cm':
          final c = db.comments.where((x) => x.id == id).firstOrNull;
          comments.add(c == null
              ? {'id': id, 'deleted': true}
              : {
                  'id': c.id,
                  'tx_id': c.txId,
                  'text': c.text,
                  'emoji': c.emoji,
                });
          break;
        case 'bud':
          // В ключе лежит пара «категория, подкатегория» — первичный ключ
          // бюджета на сервере.
          final pair = (jsonDecode(id) as List).map((v) => '$v').toList();
          final category = pair.isNotEmpty ? pair[0] : '';
          final sub = pair.length > 1 ? pair[1] : '';
          final b = db.budgets
              .where((x) => x.category == category && (x.subcategory ?? '') == sub)
              .firstOrNull;
          budgets.add(b == null
              ? {'category': category, 'subcategory': sub, 'deleted': true}
              : {
                  'category': b.category,
                  'subcategory': b.subcategory ?? '',
                  'limit_value': b.limit,
                  'currency': b.currency,
                  'period': b.period,
                  // Перенос остатка не уезжал вовсе: у партнёра тот же лимит
                  // жил обычным потолком, и числа на двух телефонах расходились.
                  'rollover': b.rollover,
                  'days': b.days,
                  'start_date': b.startDate ?? '',
                  // Имя, значок, цвет и список категорий со счетами: без них
                  // у партнёра бюджет «Машина» превращался бы в «Бензин».
                  'name': b.name ?? '',
                  'icon': b.icon ?? '',
                  'color': b.color,
                  'extra_categories': b.extraCategories,
                  'accounts': b.accounts,
                  'scope': 'shared',
                });
          break;
        case 'goal':
          final g = db.goals.where((x) => x.name == id).firstOrNull;
          goals.add(g == null
              ? {'name': id, 'deleted': true}
              : {
                  'name': g.name,
                  'target': g.target,
                  'currency': g.currency,
                  'deadline': g.deadline ?? '',
                  'kind': g.isReserve ? 'reserve' : 'plain',
                  'months': g.months,
                  // Значок и цвет ОБЯЗАНЫ уезжать: без них сервер записывал
                  // цель пустой, следующая дельта возвращала её без вида, и
                  // выбранный значок сбрасывался на глазах у человека —
                  // «я меняю, а оно сразу сбрасывается» (17.09.2026).
                  'icon': g.icon ?? '',
                  'color': g.color,
                });
          break;
        case 'agr':
          final a = db.agreements.where((x) => x.id == id).firstOrNull;
          agreements.add(a == null ? {'id': id, 'deleted': true} : a.toJson());
          break;
        case 'cat':
          final cat = db.categories.where((c) => c.name == id).firstOrNull;
          categories.add(cat == null
              ? {'name': id, 'deleted': true}
              : {
                  'name': cat.name,
                  'parent': cat.parent ?? '',
                  'color': cat.color == null
                      ? ''
                      : '#${(cat.color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                  'icon': cat.icon ?? '',
                  // Без вида расхода правило распределения у партнёра
                  // считалось бы по догадкам, а разметка — общее решение.
                  'bucket': bucketName(cat.bucket),
                  // Расход или доход. Пусто — вид не задан, и оба телефона
                  // судят по операциям, как до стартового набора.
                  'kind': cat.kind == null ? '' : catKindName(cat.kind!),
                  // Счета, где категория показывается. Пусто — на всех.
                  'accounts': cat.accounts,
                });
          break;
      }
    }

    if (txs.isNotEmpty) body['transactions'] = txs;
    if (accounts.isNotEmpty) body['accounts'] = accounts;
    if (categories.isNotEmpty) body['categories'] = categories;
    if (agreements.isNotEmpty) body['agreements'] = agreements;
    if (goals.isNotEmpty) body['goals'] = goals;
    if (budgets.isNotEmpty) body['budgets'] = budgets;
    if (comments.isNotEmpty) body['comments'] = comments;
    if (debts.isNotEmpty) body['debts'] = debts;
    if (plan.isNotEmpty) body['plan'] = plan;
    if (recurring.isNotEmpty) body['recurring'] = recurring;
    if (pending.contains('settings:base')) {
      body['settings'] = {
        'base_currency': db.baseCurrency,
        'rates': db.rates,
        'default_split': db.pair.defaultSplit.name,
        'income_shares': {
          for (final m in db.pair.members) m.uid: m.incomeShareBp,
        },
        ...db.rules.toServer(),
      };
    }

    final r = await session.post('/api/money/push', body);
    if (r['ok'] != true) return;

    // Из очереди уходит ТОЛЬКО принятое. Раньше чистилось всё подряд, и
    // отказанная сервером запись исчезала бесследно: человек видел её у себя,
    // партнёр не видел никогда.
    final refused = (r['refused'] as List?) ?? const [];
    final stuck = <String>{};
    for (final raw in refused) {
      final j = (raw as Map).cast<String, dynamic>();
      final kind = '${j['kind']}';
      final id = '${j['id'] ?? j['name'] ?? ''}';
      if (id.isEmpty) continue;
      stuck.add(switch (kind) {
        'tx' => 'tx:$id',
        'account' => 'acc:$id',
        'agreement' => 'agr:$id',
        'goal' => 'goal:$id',
        'budget' => 'bud:$id',
        'comment' => 'cm:$id',
        'debt' => 'debt:$id',
        _ => '',
      });
    }
    store.clearOutboxOf(where, pending.difference(stuck));

    if (refused.isNotEmpty) {
      final why = ((refused.first as Map)['why'] ?? '').toString();
      _error = 'Сервер не принял ${refused.length}: $why';
      debugPrint('push отказал: ${jsonEncode(refused)}');
    }
  }

  Map<String, dynamic> _txBody(Transaction t) => {
        'id': t.id,
        'date': t.date,
        'kind': t.kind.name,
        'account': t.account,
        'currency': t.currency,
        'amount': t.amount,
        'amount_base': t.amountBase,
        'category': t.category ?? '',
        'subcategory': t.subcategory ?? '',
        'note': t.note ?? '',
        'hidden': t.hidden,
        'author': t.author ?? session.uid,
        'payer': t.payer ?? '',
        'split': t.split.name,
        'shares': t.shares ?? const {},
        'secret': t.secret,
        'reveal_at': t.revealAt ?? '',
        // Время, ЧЧ:ММ. Пусто — не записывали, и партнёр увидит операцию в
        // начале дня, а не в случайном месте ленты.
        'time': t.time ?? '',
      };

  Future<void> _pull({String? space}) async {
    final where = space ?? scope;
    final since = store.markOf(where);
    final r = await session.get(
        '/api/money/pull?group_id=$where&since=$since');
    store.applyRemoteTo(where, r);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
