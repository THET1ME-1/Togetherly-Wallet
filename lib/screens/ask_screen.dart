import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../logic/agent.dart';
import '../logic/shots.dart';
import '../logic/chat_log.dart';
import '../logic/money.dart';
import '../logic/reconcile.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../services/ads.dart';
import '../services/session.dart';
import '../widgets/app_sheet.dart';
import '../widgets/plus_gate.dart';
import '../services/plus.dart';
import '../logic/plus.dart';
import '../ui/theme/tm_scheme.dart';

/// Разговор о деньгах двумя контурами.
///
/// Личный контур видит все мои кошельки, общий — только общие. Сводку для
/// модели собирает СЕРВЕР: собери её клиент, и приватность утекла бы через
/// него. В общем контуре у скрытой траты остаётся одна сумма — модель,
/// знающая про «серьги», сдала бы сюрприз первой же фразой.
///
/// Экран собран как переписка, а не как форма с кнопками: своя реплика справа
/// пастелью контура, ответ слева на карточке, а что чат СДЕЛАЛ — отдельным
/// блоком под ответом. Внутри пузыря список дел ужимался в колонку из обрывков.
class AskScreen extends StatefulWidget {
  const AskScreen({
    super.key,
    required this.store,
    required this.session,
    this.ads,
    this.log,
    this.plus,
  });

  final Store store;
  final Session session;

  /// Реклама: ролик за лишний вопрос. Пусто — кнопки нет (подписка, iPhone,
  /// тест).
  final Ads? ads;

  /// Память чата. Снаружи передаётся в тестах и съёмке; в приложении экран
  /// открывает её сам рядом с базой.
  final ChatLog? log;

  /// Подписка: по касанию счётчика вопросов открывается витрина.
  final PlusService? plus;

  @override
  State<AskScreen> createState() => _AskScreenState();
}

/// Сообщение в чате: чей пузырь, слова, предложенные действия и снимки.
class _Line {
  _Line({
    required this.mine,
    required this.text,
    this.actions = const [],
    this.shots = const [],
    this.done = const [],
    this.failed = const [],
    this.names = const [],
  });

  final bool mine;
  final String text;

  /// Только вопросы человеку: остальное уже сделано.
  final List<AgentAction> actions;

  /// Прикреплённое: снимки показываются картинкой, файлы — строкой с именем.
  final List<_Attach> shots;

  /// Что сделано и что не вышло — строками для человека.
  final List<String> done;
  final List<String> failed;

  /// Имена вложений, поднятые из памяти: сами файлы там не хранятся.
  final List<String> names;
}

class _AskScreenState extends State<AskScreen> {
  final _input = TextEditingController();
  final _messages = <_Line>[];
  final _scroll = ScrollController();

  /// Прикреплённое к следующему сообщению: снимки и файлы вперемешку.
  final _shots = <_Attach>[];

  bool _shared = false;
  bool _busy = false;
  String? _error;
  /// Сколько вопросов осталось сегодня.
  ///
  /// До первого вопроса число берётся из ТАЛОНА подписки: он приезжает при
  /// запуске приложения и несёт остаток вместе со сроком. Раньше счётчик
  /// появлялся только после первого ответа, и человек, открывший чат, не
  /// видел своего потолка вовсе (замечено человеком 17.09.2026).
  int? _left;

  int? get _asksLeft => _left ?? widget.plus?.asksLeft;
  int? get _filesShown => _filesLeft ?? widget.plus?.filesLeft;

  /// Сколько файлов и чеков осталось в этом месяце. Считает сервер.
  int? _filesLeft;

  /// Файлы кончились: разбор чека и выписки закрыт до следующего месяца или
  /// до подписки.
  bool _filesOut = false;

  /// Сколько роликов сегодня ещё можно посмотреть. Считает сервер, здесь
  /// только эхо его ответа: телефон себе вопросов не выписывает.
  int _rewardLeft = 0;
  bool _watching = false;

  late final ChatLog _log = widget.log ?? ChatLog();

  /// Ветка переписки: у каждой пары и каждого чата своя.
  String get _space => widget.store.db.pair.groupId.isEmpty
      ? widget.session.uid
      : widget.store.db.pair.groupId;
  String get _scope => _shared ? 'shared' : 'personal';

  /// Примеры вопросов и примеры дел: чат не только отвечает, но и записывает,
  /// и об этом человек иначе не догадается.
  static List<String> get _asks => [
        tr('askExampleFood'),
        tr('askExampleEnough'),
        tr('askExampleTop'),
      ];

  static List<String> get _does => [
        tr('askExampleAdd'),
        tr('askExampleAccount'),
        tr('askExampleLimit'),
        tr('askExampleFile'),
      ];

  @override
  void initState() {
    super.initState();
    // Поле само подсвечивает кнопку отправки: серая стрелка при пустом поле
    // честнее, чем активная кнопка, которая ничего не делает.
    _input.addListener(() => setState(() {}));
    // Талон подписки приезжает сверкой уже после первого кадра: остаток
    // вопросов в шапке обязан появиться, когда он доехал, а не после
    // первого заданного вопроса.
    widget.plus?.addListener(_onPlus);
    _open();
  }

  /// Поднять переписку с устройства. Лог, переданный снаружи, уже загружен.
  Future<void> _open() async {
    if (widget.log == null) {
      try {
        await _log.load(await getApplicationDocumentsDirectory());
      } catch (_) {
        // Без папки данных чат просто не помнит прошлого разговора — это не
        // повод не открыть экран.
      }
    }
    if (mounted) setState(_refill);
  }

  /// Переложить ветку памяти в ленту экрана.
  void _refill() {
    _messages
      ..clear()
      ..addAll(_log.of(_space, _scope).map((t) => _Line(
            mine: t.mine,
            text: t.text,
            done: t.done,
            failed: t.failed,
            names: t.files,
          )));
  }

  void _switchScope(bool shared) {
    setState(() {
      _shared = shared;
      // У личного и общего чата разговоры разные: смешать их значило бы
      // вытащить личное в общий чат.
      _refill();
    });
    _toEnd();
  }

  Future<void> _forget() async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (sheet) => SheetScaffold(
        icon: Myna.trash,
        title: tr('askClear'),
        text: tr('askClearNote'),
        action: tr('askClearDo'),
        tone: context.tm.expense,
        onAction: () => Navigator.pop(sheet, true),
      ),
    );
    if (yes != true || !mounted) return;
    _log.clear(_space, _scope);
    setState(() {
      _messages.clear();
      _error = null;
    });
  }

  @override
  void dispose() {
    widget.plus?.removeListener(_onPlus);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onPlus() {
    if (mounted) setState(() {});
  }

  /// Последнее сообщение должно быть видно само, без пролистывания пальцем.
  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: AppTheme.emphasizedDecelerate,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    final question = (preset ?? _input.text).trim();
    final shots = [..._shots];
    // Одного снимка чека хватает как сообщения: слов человек может и не
    // написать.
    if ((question.isEmpty && shots.isEmpty) || _busy) return;

    // История собирается ДО своей новой реплики: текущий вопрос уезжает
    // отдельным полем, и дважды его слать незачем.
    final history = _log.historyFor(_space, _scope);
    _log.add(
      _space,
      _scope,
      ChatTurn(
        mine: true,
        text: question,
        at: DateTime.now().millisecondsSinceEpoch,
        files: [for (final s in shots) s.name],
      ),
    );

    setState(() {
      _busy = true;
      _error = null;
      _messages.add(_Line(mine: true, text: question, shots: shots));
      _shots.clear();
      _input.clear();
    });
    _toEnd();

    try {
      final scope = widget.store.db.pair.groupId.isEmpty
          ? widget.session.uid
          : widget.store.db.pair.groupId;
      final r = await widget.session.post(
        '/api/money/ask',
        {
        'group_id': scope,
        'scope': _shared ? 'shared' : 'personal',
        'question': question.isEmpty ? tr('askReadReceipt') : question,
        // Прошлые реплики: без них «а в прошлом месяце?» вторым сообщением
        // не значит ничего.
        if (history.isNotEmpty) 'history': history,
        // Картинки читает зрячая модель, файлы разбирает сервер: PDF-чек и
        // выписку возить через зрение незачем.
        if (shots.any((s) => s.isImage))
          'images': [
            for (final s in shots)
              if (s.isImage) base64Encode(s.bytes),
          ],
        if (shots.any((s) => !s.isImage))
          'files': [
            for (final s in shots)
              if (!s.isImage)
                {'name': s.name, 'data': base64Encode(s.bytes)},
          ],
        },
        // Снимок читает зрячая модель, потом её пересказ уходит обычной: два
        // похода к модели плюс отправка кадра в двадцать секунд не укладываются.
        timeout: Duration(seconds: shots.isEmpty ? 45 : 120),
      );
      if (!mounted) return;

      // Таблицу или выписку разбирает отдельный маршрут: модель видит только
      // образец и называет схему, а все строки — хоть тысячу — раскладывает
      // сервер. Выписывать их словами модель не может и не должна.
      final imported = await _importFiles(shots, scope, question);
      if (!mounted) return;

      final actions = [
        for (final raw in (r['actions'] as List?) ?? const [])
          AgentAction.fromJson((raw as Map).cast<String, dynamic>()),
      ];
      // Делаем СРАЗУ: человек попросил «создай счёт Зал» — счёт заводится, а
      // не превращается в карточку с кнопкой. Ошибся — внизу полоса отмены.
      final done = <String>[];
      final failed = <String>[];
      for (final a in actions) {
        if (a.isQuestion) continue;
        final summary = agentSummary(widget.store, a);
        (runAgent(widget.store, a) ? done : failed).add(summary);
      }

      final answer = '${r['answer'] ?? ''}';
      _log.add(
        _space,
        _scope,
        ChatTurn(
          mine: false,
          text: answer,
          at: DateTime.now().millisecondsSinceEpoch,
          done: [...imported, ...done],
          failed: failed,
        ),
      );

      setState(() {
        _messages.add(_Line(
          mine: false,
          text: answer,
          actions: actions.where((a) => a.isQuestion).toList(),
          done: [...imported, ...done],
          failed: failed,
        ));
        _left = (r['left'] as num?)?.toInt();
        _rewardLeft = (r['reward_left'] as num?)?.toInt() ?? _rewardLeft;
        _filesLeft = (r['files_left'] as num?)?.toInt() ?? _filesLeft;
      });
      widget.plus?.noteUsage(asks: _left, files: _filesLeft);
      _toEnd();
    } on SessionError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          // Сервер отказал по дневному потолку и сказал, сколько роликов
          // осталось: кнопку показываем ровно по его слову.
          final left = e.body?['reward_left'];
          if (left is num) _rewardLeft = left.toInt();
          final files = e.body?['files_left'];
          if (files is num) _filesLeft = files.toInt();
          if (e.body?['need_plus'] == true) {
            // Отказ бывает двух видов, и путать их нельзя: кончились вопросы
            // — поможет ролик, кончились файлы — только подписка.
            if (files is num) {
              _filesOut = true;
            } else {
              _left = 0;
            }
          }
        });
        if (_filesOut) {
          askPlus(context, plus: widget.plus, gate: PlusGate.files);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Посмотреть ролик и получить вопрос.
  ///
  /// Начисляет СЕРВЕР: показ здесь, а право спросить — там. Иначе вопросы
  /// себе выпишет любой, кто умеет повторить запрос.
  Future<void> _watch() async {
    final ads = widget.ads;
    if (ads == null || _watching) return;
    setState(() => _watching = true);
    final seen = await ads.showRewarded();
    if (!mounted) return;
    if (!seen) {
      setState(() {
        _watching = false;
        _error = tr('askWatchFailed');
      });
      return;
    }
    try {
      final r = await widget.session.post('/api/money/ask/reward', const {});
      if (!mounted) return;
      setState(() {
        _watching = false;
        _left = (r['left'] as num?)?.toInt() ?? _left;
        _rewardLeft = (r['reward_left'] as num?)?.toInt() ?? 0;
        _error = null;
      });
    } on SessionError catch (e) {
      if (!mounted) return;
      setState(() {
        _watching = false;
        _rewardLeft = 0;
        _error = e.body?['error'] == 'day_limit'
            ? tr('askWatchOut')
            : e.message;
      });
    }
  }

  /// Разобрать прикреплённые файлы целиком и записать всё, что нашлось.
  ///
  /// Возвращает строки для отчёта: «Записано из vypiska.csv: 1000». Снимки
  /// сюда не попадают — их читает зрячая модель обычным путём.
  Future<List<String>> _importFiles(
    List<_Attach> shots,
    String scope,
    String question,
  ) async {
    final out = <String>[];
    for (final file in shots.where((s) => !s.isImage)) {
      try {
        final r = await widget.session.post(
          '/api/money/import',
          {
            'group_id': scope,
            'question': question,
            'file': {'name': file.name, 'data': base64Encode(file.bytes)},
          },
          // Выписка на тысячу строк разбирается дольше вопроса: модель
          // называет схему по образцу, а строки раскладывает сервер.
          timeout: const Duration(seconds: 180),
        );
        final rows = (r['rows'] as List?) ?? const [];
        if (rows.isEmpty) {
          final note = '${r['note'] ?? ''}'.trim();
          if (note.isNotEmpty) out.add('${file.name}: $note');
          continue;
        }
        final db = widget.store.db;
        final account = db.accounts.isEmpty ? '' : db.accounts.first.name;
        if (account.isEmpty) {
          out.add(tr('agentNeedAccount'));
          continue;
        }
        final currencyOf = db.accounts
            .firstWhere((a) => a.name == account,
                orElse: () => Account(name: account, currency: db.baseCurrency))
            .currency;

        final parsed = [
          for (final raw in rows)
            ImportedRow.fromJson((raw as Map).cast<String, dynamic>()),
        ].where((row) => row.amount > 0).toList();
        if (parsed.isEmpty) continue;

        // СВЕРКА идёт всегда: тот же файл, присланный дважды, не должен
        // рожать дубли. Совпавшие записи дополняются датой, временем и
        // описанием из выписки, недостающие дописываются.
        final result = reconcile(db.transactions, parsed);
        final fixes = [
          for (final m in result.matched)
            if (m.changed) m.fixed,
        ];
        if (fixes.isNotEmpty) widget.store.saveMany(fixes, label: tr('agentChecked'));

        final onlyUpdate = r['only_update'] == true;
        var added = 0;
        if (!onlyUpdate && result.onlyFile.isNotEmpty) {
          var stamp = DateTime.now().microsecondsSinceEpoch;
          final ops = <Transaction>[];
          for (final row in result.onlyFile) {
            final currency =
                row.currency.trim().isEmpty ? currencyOf : row.currency;
            final signed = row.income ? row.amount : -row.amount;
            ops.add(Transaction(
              id: 'imp-${stamp++}',
              date: row.date.isEmpty
                  ? DateTime.now().toIso8601String().substring(0, 10)
                  : row.date,
              kind: row.income ? TxKind.income : TxKind.expense,
              account: account,
              currency: currency,
              amount: signed,
              amountBase: convert(db, signed, currency),
              note: row.note.trim().isEmpty ? null : row.note.trim(),
              time: row.time.trim().isEmpty ? null : row.time.trim(),
              author: widget.store.viewer.isEmpty ? null : widget.store.viewer,
              payer: widget.store.viewer.isEmpty ? null : widget.store.viewer,
              split: db.pair.members.length > 1
                  ? db.pair.defaultSplit
                  : SplitMode.none,
            ));
          }
          if (ops.isNotEmpty) {
            widget.store.saveMany(ops);
            added = ops.length;
          }
        }

        out.add(trf('agentReconciled', [
          file.name,
          '${result.matched.length}',
          '${fixes.length}',
          '$added',
          '${result.onlyApp.length}',
        ]));
      } on SessionError catch (e) {
        out.add('${file.name}: ${e.message}');
      }
    }
    return out;
  }

  /// Прикрепить снимок ИЛИ файл: чек бывает и фотографией, и PDF из банка, и
  /// выпиской таблицей.
  Future<void> _pickShot() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'jpeg', 'png', 'webp', 'heic',
        'pdf', 'csv', 'txt', 'json', 'xlsx', 'xlsm',
      ],
      withData: true,
      allowMultiple: true,
    );
    final files = picked?.files ?? const [];
    if (files.isEmpty || !mounted) return;

    // Снимок ужимается ЗДЕСЬ, а не при отправке: человек видит превью уже
    // готового кадра, а в тело запроса едет то, что показано. Работа идёт в
    // отдельном изоляте — на кадре с камеры разбор весит секунду.
    final ready = <_Attach>[];
    for (final f in files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      final attach = _Attach(name: f.name, bytes: bytes);
      ready.add(attach.isImage
          ? _Attach(name: f.name, bytes: await compute(shrinkShot, bytes))
          : attach);
    }
    if (!mounted) return;
    setState(() => _shots.addAll(ready));
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final paired = widget.store.db.pair.members.length > 1;
    // Цвет — граница приватности: лаванда личное, мята общее. Он держит и
    // пузырь своей реплики, и кнопку отправки, и знак ответа.
    // Своя реплика, вложения и готовая кнопка отправки — ИНВЕРСИЯ. До
    // 14.09.2026 заливкой был `tm.field`, а буквами `onAccent`: на светлой
    // теме выходило белым по светло-серому, и свой же вопрос человек не
    // читал. Кнопка отправки при этом не отличалась от погашенной.
    final scheme = Theme.of(context).colorScheme;
    final fill = scheme.secondaryContainer;
    final ink = scheme.onSecondaryContainer;
    // Знак искры: на тёмной теме СВЕТЛЫЙ, на светлой — чёрный. Условие
    // стояло наоборот, и в темноте знак красился в тот же тон, что подложка:
    // на пустом экране чата от него оставалось еле заметное пятно (замечено
    // человеком 17.09.2026). Комментарий тут был верный с самого начала —
    // ошибка была в коде под ним.
    final deep = tm.dark ? tm.textAlpha(0.92) : tm.text;

    return Scaffold(
      backgroundColor: tm.bg,
      appBar: AppBar(
        title: Text(tr('askTitle')),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _forget,
              icon: const Icon(Myna.trash),
              tooltip: tr('askClear'),
            ),
          if (_asksLeft != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _LeftChip(left: _asksLeft!, plus: widget.plus),
            ),
        ],
      ),
      body: Column(children: [
        if (paired)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: _ScopeRow(shared: _shared, onPick: _switchScope),
          ),
        Expanded(
          child: _messages.isEmpty && !_busy
              ? _Empty(onPick: _send, deep: deep)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  itemCount: _messages.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length) return _Typing(deep: deep);
                    final m = _messages[i];
                    return m.mine
                        ? _Mine(line: m, fill: fill, ink: ink)
                        : _Reply(line: m, deep: deep, onAnswer: _send);
                  },
                ),
        ),
        _Composer(
          input: _input,
          shots: _shots,
          busy: _busy,
          error: _error,
          spent: _asksLeft == 0,
          // Без рекламы кнопки быть не должно: на iPhone её нет вовсе, а у
          // подписчика вопросы и так без потолка — нажатие вело бы в никуда.
          rewardLeft: widget.ads == null ? 0 : _rewardLeft,
          watching: _watching,
          onWatch: _watch,
          fill: fill,
          ink: ink,
          hint: _shared ? tr('askHintShared') : tr('askHintPersonal'),
          onAttach: _pickShot,
          onDrop: (i) => setState(() => _shots.removeAt(i)),
          onSend: () => _send(),
          filesLeft: _filesShown,
        ),
      ]),
    );
  }
}

/// Два контура одним рядом: замок — личное, двое — общее.
///
/// `SegmentedButton` тут не годится: у него один цвет на оба положения, а цвет
/// здесь означает приватность, и спутать контуры стоит дороже, чем выглядеть
/// стандартно.
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.shared, required this.onPick});

  final bool shared;
  final ValueChanged<bool> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _ScopeCell(
          title: tr('askScopePersonal'),
          icon: Myna.lock,
          on: !shared,
          onTap: () => onPick(false),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _ScopeCell(
          title: tr('askScopeShared'),
          icon: Myna.users,
          on: shared,
          onTap: () => onPick(true),
        ),
      ),
    ]);
  }
}

class _ScopeCell extends StatelessWidget {
  const _ScopeCell({
    required this.title,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      // Выбранное — инверсия. Заливка контура отменена вместе с «мята
      // личное, мята общее»: обе давали `field`, и выбранная ячейка была
      // неотличима от соседней, а белый значок на светлой теме пропадал.
      color: on ? scheme.secondaryContainer : tm.field,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              icon,
              size: 17,
              color: on ? scheme.onSecondaryContainer : tm.textAlpha(0.6),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: on ? scheme.onSecondaryContainer : tm.textAlpha(0.6),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Остаток бесплатных вопросов — чипом в шапке.
///
/// Строкой под полем ввода он занимал место у клавиатуры и читался сноской;
/// в шапке он на виду и не мешает набирать.
class _LeftChip extends StatelessWidget {
  const _LeftChip({required this.left, this.plus});

  /// Сколько вопросов ещё осталось сегодня.
  final int left;
  final PlusService? plus;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final out = left == 0;
    final have = PlusLimits.asksPerDay - left;
    return Semantics(
      button: true,
      label: trf('plusMeterTaken', ['$have', '${PlusLimits.asksPerDay}']),
      child: InkWell(
        onTap: () => askPlus(context, plus: plus, gate: PlusGate.chat),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: tm.field,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              Myna.sparkles,
              size: 15,
              color: out ? tm.expense : tm.textAlpha(0.75),
            ),
            const SizedBox(width: 7),
            // ЧИСЛО, а не точки. Точки хороши там, где под них есть место
            // (шапка раздела, лист), но в чипе размером с ноготь они
            // сливаются с фоном, и человек видит пустоту вместо счёта
            // (замечено человеком 17.09.2026).
            Text(
              '$left',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: out ? tm.expense : tm.text,
              ),
            ),
            Text(
              '/${PlusLimits.asksPerDay}',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: tm.textAlpha(0.45),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Своя реплика: пастель контура, вложения над словами.
class _Mine extends StatelessWidget {
  const _Mine({required this.line, required this.fill, required this.ink});

  final _Line line;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 44),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
            bottomLeft: Radius.circular(22),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final shot in line.shots)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _Shot(shot: shot, ink: ink),
              ),
            // Реплика, поднятая из памяти: файла уже нет, осталось имя.
            for (final name in line.names)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FileName(name: name, ink: ink),
              ),
            if (line.text.trim().isNotEmpty)
              Text(
                line.text,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14.5,
                  height: 1.45,
                  color: ink,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Прикреплённое внутри пузыря: снимок картинкой, файл строкой с именем.
class _Shot extends StatelessWidget {
  const _Shot({required this.shot, required this.ink});

  final _Attach shot;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    if (shot.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(shot.bytes, width: 176, fit: BoxFit.cover),
      );
    }
    return _FileName(name: shot.name, ink: ink);
  }
}

/// Имя вложения строкой: так выглядит файл и в поднятой из памяти реплике.
class _FileName extends StatelessWidget {
  const _FileName({required this.name, required this.ink});

  final String name;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Myna.fileText, size: 16, color: ink),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              color: ink,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Ответ: знак слева, слова на карточке, сделанное — блоком под ответом.
class _Reply extends StatelessWidget {
  const _Reply({
    required this.line,
    required this.deep,
    required this.onAnswer,
  });

  final _Line line;
  final Color deep;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final text = line.text.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tm.personalTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Myna.sparkles, size: 17, color: deep),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (text.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: tm.card,
                  border: Border.all(color: tm.line),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14.5,
                    height: 1.5,
                    color: tm.text,
                  ),
                ),
              ),
            if (line.done.isNotEmpty || line.failed.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: text.isEmpty ? 0 : 8),
                child: _DoneCard(done: line.done, failed: line.failed),
              ),
            for (final a in line.actions)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Question(action: a, onAnswer: onAnswer),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// Что чат сделал — отдельным блоком, а не строчками внутри пузыря.
///
/// В пузыре список ужимался в колонку обрывков: «Записано 417,60 на Про…».
/// Блок во всю ширину ответа читается сразу и держит длинные строки.
class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.done, required this.failed});

  final List<String> done;
  final List<String> failed;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tm.row,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          tr('agentApplied'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            height: 1,
            color: tm.textAlpha(0.55),
          ),
        ),
        const SizedBox(height: 8),
        for (final line in done) _DoneLine(text: line, ok: true),
        for (final line in failed) _DoneLine(text: line, ok: false),
      ]),
    );
  }
}

/// Ожидание ответа: три точки на месте будущего пузыря.
class _Typing extends StatefulWidget {
  const _Typing({required this.deep});

  final Color deep;

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tm.personalTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Myna.sparkles, size: 17, color: widget.deep),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: tm.card,
            border: Border.all(color: tm.line),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(22),
              bottomLeft: Radius.circular(22),
              bottomRight: Radius.circular(22),
            ),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Opacity(
                  // Точки загораются по очереди: волна читается как «думает»,
                  // а одновременное мигание — как поломка отрисовки.
                  opacity: 0.35 + 0.65 * _wave(_c.value, i),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: widget.deep,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  /// Доля свечения точки в текущий миг: 0 в покое, 1 на гребне волны.
  double _wave(double t, int i) {
    final shift = (t - i * 0.18) % 1.0;
    return shift < 0.3 ? 1 - (shift / 0.3 - 0.5).abs() * 2 : 0;
  }
}

/// Пустой экран не должен быть пустым: чат не только отвечает, но и пишет
/// траты, заводит счета и разбирает выписку — и об этом иначе не догадаться.
class _Empty extends StatelessWidget {
  const _Empty({required this.onPick, required this.deep});

  final ValueChanged<String> onPick;
  final Color deep;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    // Содержимое стоит ПО ЦЕНТРУ высоты: прижатое к низу, оно оставляло
    // над собой пустой экран в две трети, а прижатое к верху — под собой.
    // Прокрутка остаётся для тесных экранов и крупного системного шрифта.
    return LayoutBuilder(builder: (context, box) {
      return SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Ступень выше карточки: на чёрном листе подложка в цвет
              // карточки читается как пустое место.
              color: tm.field,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Myna.sparkles, size: 26, color: deep),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr('askEmptyTitle'),
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: tm.text,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr('askServerNote'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            height: 1.45,
            color: tm.textAlpha(0.6),
          ),
        ),
        const SizedBox(height: 22),
        _HintGroup(title: tr('askAsk'), hints: _AskScreenState._asks, onPick: onPick),
        const SizedBox(height: 16),
        _HintGroup(title: tr('askDo'), hints: _AskScreenState._does, onPick: onPick),
            ],
          ),
        ),
      );
    });
  }
}

/// Подсказки лежат РЯДОМ с прокруткой вбок, а не столбиком кнопок.
class _HintGroup extends StatelessWidget {
  const _HintGroup({
    required this.title,
    required this.hints,
    required this.onPick,
  });

  final String title;
  final List<String> hints;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final scaled = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          height: 1,
          color: tm.textAlpha(0.55),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 52 * scaled,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: hints.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => Center(
            child: Material(
              color: tm.field,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => onPick(hints[i]),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      hints[i],
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13.5,
                        height: 1.1,
                        color: tm.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Строка ввода: скрепка, поле и отправка живут в ОДНОЙ капсуле.
///
/// Тремя отдельными кнопками в ряд это выглядело набором деталей: круглая
/// кнопка отправки стояла в стороне от поля и не читалась его частью.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.shots,
    required this.busy,
    required this.error,
    required this.spent,
    required this.rewardLeft,
    required this.watching,
    required this.onWatch,
    required this.fill,
    required this.ink,
    required this.hint,
    required this.onAttach,
    required this.onDrop,
    required this.onSend,
    this.filesLeft,
  });

  final TextEditingController input;
  final List<_Attach> shots;
  final bool busy;
  final String? error;
  final bool spent;

  /// Сколько роликов ещё даст сервер сегодня. Ноль — кнопки нет.
  final int rewardLeft;
  final bool watching;
  final Future<void> Function() onWatch;
  final Color fill;
  final Color ink;
  final String hint;
  final VoidCallback onAttach;
  final ValueChanged<int> onDrop;
  final VoidCallback onSend;

  /// Сколько файлов и чеков осталось в месяце. Пусто — счётчика нет: либо
  /// подписка открыта, либо сервер ещё не отвечал.
  final int? filesLeft;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final ready = !busy && (input.text.trim().isNotEmpty || shots.isNotEmpty);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          10 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(children: [
          if (error != null) _Banner(text: error!, bad: true),
          if (error == null && spent) _Banner(text: tr('askNoMore'), bad: false),
          // Ролик вместо подписки: человек, которому не хватило трёх вопросов,
          // чаще готов посмотреть минуту рекламы, чем платить.
          if (spent && rewardLeft > 0) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: watching ? null : onWatch,
                icon: const Icon(Myna.play, size: 18),
                label: Text(watching ? tr('askWatchWait') : tr('askWatch')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                trf('askWatchLeft', ['$rewardLeft']),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (filesLeft != null && (shots.isNotEmpty || filesLeft! <= 2))
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  trf('askFilesLeft',
                      ['${filesLeft!}', '${PlusLimits.filesPerMonth}']),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: filesLeft == 0
                        ? tm.expense
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tm.card,
              border: Border.all(color: tm.line),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(children: [
              if (shots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: SizedBox(
                    height: 62,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => _Pending(
                        shot: shots[i],
                        onDrop: () => onDrop(i),
                      ),
                    ),
                  ),
                ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _Round(
                  icon: Myna.paperclip,
                  color: tm.field,
                  ink: tm.textAlpha(0.7),
                  size: 42,
                  onTap: busy ? null : onAttach,
                  tooltip: tr('agentPhotoAdd'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14.5,
                      height: 1.35,
                      color: tm.text,
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14.5,
                        color: tm.textAlpha(0.45),
                      ),
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _Round(
                  icon: busy ? Myna.dots : Myna.arrowUp,
                  color: ready ? fill : tm.field,
                  ink: ready ? ink : tm.textAlpha(0.4),
                  size: 42,
                  onTap: ready ? onSend : null,
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Круглая кнопка ввода: скрепка и отправка одного размера и одной формы.
class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.color,
    required this.ink,
    required this.size,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final Color ink;
  final double size;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: 19, color: ink),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Прикреплённое, ещё не отправленное: снимок плиткой, файл именем.
class _Pending extends StatelessWidget {
  const _Pending({required this.shot, required this.onDrop});

  final _Attach shot;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Stack(clipBehavior: Clip.none, children: [
      shot.isImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                shot.bytes,
                width: 62,
                height: 62,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              width: 104,
              height: 62,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: tm.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Myna.fileText, size: 17, color: tm.textAlpha(0.7)),
                  const SizedBox(height: 5),
                  Text(
                    shot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 11,
                      height: 1,
                      color: tm.text,
                    ),
                  ),
                ],
              ),
            ),
      Positioned(
        right: -4,
        top: -4,
        child: Material(
          color: tm.text,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onDrop,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 20,
              height: 20,
              child: Icon(Myna.x, size: 12, color: tm.bg),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Строка-предупреждение над полем ввода.
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.bad});

  final String text;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: tm.field,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          Icon(
            bad ? Myna.dangerCircle : Myna.sparkles,
            size: 17,
            color: bad ? context.tm.expense : tm.textAlpha(0.7),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                height: 1.35,
                color: bad ? context.tm.expense : tm.textAlpha(0.8),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Уточняющий вопрос с вариантами.
///
/// Модель спрашивает, когда чек читается плохо или не хватает данных. Варианты
/// — кнопки, но человек всегда может ответить своими словами или сказать
/// «всё равно продолжить»: спрашивать дважды об одном и том же хуже, чем
/// записать с тем, что есть.
class _Question extends StatelessWidget {
  const _Question({required this.action, required this.onAnswer});

  final AgentAction action;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tm.personalTint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          action.question,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: tm.text,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in action.options)
            _Chip(title: option, onTap: () => onAnswer(option)),
          _Chip(
            title: tr('agentAnyway'),
            icon: Myna.arrowRight,
            onTap: () => onAnswer(tr('agentAnyway')),
          ),
        ]),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.title, required this.onTap, this.icon});

  final String title;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Material(
      color: tm.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: tm.textAlpha(0.7)),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                height: 1.1,
                fontWeight: FontWeight.w600,
                color: tm.text,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Строка «сделано» внутри блока результата.
class _DoneLine extends StatelessWidget {
  const _DoneLine({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
          ok ? Myna.checkCircle : Myna.dangerCircle,
          size: 16,
          color: ok ? context.tm.text : context.tm.expense,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ok ? text : '$text — ${tr('agentFailed')}',
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              height: 1.4,
              color: tm.textAlpha(0.85),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Прикреплённое к сообщению: снимок или файл.
///
/// Снимок уходит зрячей модели, файл разбирает сервер: PDF-чек и выписка
/// таблицей — обычный текст, и возить их через зрение незачем.
class _Attach {
  _Attach({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  static const _pictures = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'gif'};

  bool get isImage {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return _pictures.contains(name.substring(dot + 1).toLowerCase());
  }
}
