import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../ui/theme/tm_tokens.dart';
import '../logic/icons.dart';
import '../logic/calc.dart';
import '../logic/category_pick.dart';
import '../logic/haptics.dart';
import '../logic/money.dart';
import '../logic/period.dart';
import '../logic/split.dart';
import '../widgets/app_sheet.dart';
import 'categories_edit.dart';
import '../widgets/card_tile.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/money_text.dart';
import '../services/session.dart';
import '../widgets/pick_row.dart';
import 'currency_pick_screen.dart';
import '../design/myna.dart';

/// Запись и правка операции. Форма прокручивается, клавиатура и кнопка стоят
/// внизу неподвижно: липкая кнопка перекрывала нижний ряд клавиш, и «00», «0»
/// и стирание было не нажать.
Route<void> operationRoute(
  Store store, {
  Transaction? edit,
  Session? session,
}) => MaterialPageRoute<void>(
  builder: (_) => OperationScreen(store: store, edit: edit, session: session),
  fullscreenDialog: true,
);

class OperationScreen extends StatefulWidget {
  final Store store;
  final Transaction? edit;

  /// Сессия нужна ровно для одного: подтянуть курс валюты, которой ещё нет в
  /// таблице. Без неё экран работает как прежде.
  final Session? session;

  const OperationScreen({
    super.key,
    required this.store,
    this.edit,
    this.session,
  });

  @override
  State<OperationScreen> createState() => _OperationScreenState();
}

class _OperationScreenState extends State<OperationScreen> {
  late TxKind _kind = widget.edit?.kind ?? TxKind.expense;

  /// Счётная клавиатура: цифры и четыре действия. В магазине сумма редко
  /// бывает готовой — «три по 42», «пополам», «плюс десять процентов».
  late final Calc _calc = widget.edit == null
      ? Calc()
      : Calc.of(widget.edit!.amount.abs());
  late String? _account = widget.edit?.account;

  /// Куда переводим. Только у перевода: у траты и дохода второго счёта нет.
  String? _to;

  /// Валюта операции. Пусто — валюта счёта: так почти всегда, но не всегда.
  /// Заплатить десять долларов с молдавской карты — обычное дело, и запись
  /// такой траты в леях означала бы потерю денег в учёте.
  late String? _currency = widget.edit?.currency;
  late String? _category = widget.edit?.category;
  late String? _sub = widget.edit?.subcategory;

  /// С какой ДРУГОЙ парой разделить трату. Пусто — ни с какой.
  ///
  /// Деньги уходят со счёта той пары, которой счёт принадлежит: скрыть это
  /// нельзя, иначе остаток общей карты соврёт партнёру. А пара, за которую
  /// платили, получает ту же трату расчётом — без чужого счёта.
  String? _shareWith;
  late String _date = widget.edit?.date ?? iso(DateTime.now());

  /// Время, ЧЧ:ММ. Пусто — человек его не задавал, и в подписи его не видно.
  late String? _time = widget.edit?.time;
  late final TextEditingController _note = TextEditingController(
    text: widget.edit?.note ?? '',
  );

  /// Что показывает нижняя панель: клавиши, категории или счета.
  ///
  /// Панель одна, состояний три. До 14.09.2026 всё это лежало рядами с
  /// прокруткой вбок в верхней половине экрана, и выбор приходилось искать
  /// листанием.
  _OpPanel _panel = _OpPanel.keys;

  /// Кто платил и как делим. У одиночки этих полей нет вовсе.
  late String? _payer = widget.edit?.payer ?? widget.store.viewer;
  late SplitMode _split =
      widget.edit?.split ??
      (widget.store.db.pair.members.length > 1
          ? widget.store.db.pair.defaultSplit
          : SplitMode.none);
  late bool _secret = widget.edit?.secret ?? false;
  late String? _revealAt = widget.edit?.revealAt;

  double get _amount => _calc.value;

  /// Можно ли записывать. У перевода мало суммы: нужен второй счёт, иначе
  /// деньги уйдут в никуда.
  bool get _canSave =>
      _amount > 0 &&
      (_kind != TxKind.transfer || (_to != null && _to != _account));



  bool get _paired => widget.store.db.pair.members.length > 1;

  String? get _viewerOrNull =>
      widget.store.viewer.isEmpty ? null : widget.store.viewer;

  /// Когда сюрприз раскроется сам. Без даты он висит скрытым, пока автор не
  /// снимет замок руками — так тоже можно, поэтому дата необязательна.
  Future<void> _pickReveal() async {
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('opRevealWhen'),
      initial: _revealAt == null ? now : (DateTime.tryParse(_revealAt!) ?? now),
      firstYear: now.year,
      lastYear: now.year + 3,
    );
    if (picked != null) setState(() => _revealAt = iso(picked));
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _press(String key) {
    setState(() {
      switch (key) {
        case 'del':
          _calc.backspace();
        case '+':
          _calc.operator(CalcOp.plus);
        case '-':
          _calc.operator(CalcOp.minus);
        case '*':
          _calc.operator(CalcOp.times);
        case '/':
          _calc.operator(CalcOp.divide);
        case '%':
          _calc.percent();
        case '=':
          _calc.equals();
        default:
          _calc.digit(key);
      }
    });
  }

  void _save() {
    var db = widget.store.db;
    if (_amount <= 0) return;

    // Обещание «счёт создастся при первой записи» раньше было ложью: при нуле
    // счетов `_save` молча выходил, человек жал «Записать» и ничего не
    // происходило (замечено 13.09.2026). Теперь счёт действительно заводится.
    if (db.accounts.isEmpty && _account == null) {
      widget.store.editAccount(tr('accountDefaultName'));
      db = widget.store.db;
      _account = tr('accountDefaultName');
    }
    final account = _account ?? db.accounts.firstOrNull?.name;
    if (account == null) return;

    // Перевод — ДВЕ записи: ушло с одного счёта, пришло на другой. Одной он
    // списывал деньги в никуда (13.09.2026).
    if (_kind == TxKind.transfer) {
      final to = _to;
      if (to == null || to == account) return;
      widget.store.transfer(
        from: account,
        to: to,
        amount: _amount,
        date: _date,
        time: _time,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        payer: _paired ? _payer : null,
      );
      Tap.done();
      Navigator.of(context).pop();
      return;
    }
    final currency = _currency ?? _currencyOf(db, account);
    final signed = _kind == TxKind.income ? _amount : -_amount;
    final op = Transaction(
      id: widget.edit?.id ?? 'op-${DateTime.now().microsecondsSinceEpoch}',
      date: _date,
      kind: _kind,
      account: account,
      currency: currency,
      amount: signed,
      amountBase: convert(db, signed, currency),
      category: _category,
      subcategory: _sub,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      author: widget.edit?.author ?? _viewerOrNull,
      payer: _paired ? _payer : null,
      split: _paired ? _split : SplitMode.none,
      secret: _paired && _secret,
      revealAt: _paired && _secret ? _revealAt : null,
      time: _time,
    );
    final label = widget.edit == null ? tr('opSaved') : tr('opChanged');
    widget.store.saveOperation(op, label: label);
    // Самое частое действие в приложении, и до 17.09.2026 оно отвечало
    // человеку одной пропавшей формой. Толчок говорит «легло в ленту» тогда,
    // когда глаза уже ушли с экрана.
    Tap.done();
    final share = _shareWith;
    if (share != null && share != widget.store.space) {
      widget.store.shareWith(share, op);
    }

    // Округление в копилку — только у НОВОЙ траты: на правке оно добавляло бы
    // второй взнос за ту же покупку.
    final extra = widget.edit == null ? widget.store.roundUpAfter(op) : 0.0;

    // Из общего кошелька берут двое. Если пара договорилась предупреждать или
    // держать предел на снятие, приложение говорит это в тот момент, когда
    // человек записывает трату, а не потом в отчёте.
    final notice = _potNotice(op);

    // Мессенджер берётся ДО pop: после закрытия экрана его контекст уже
    // размонтирован, и сообщение не покажется.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (extra > 0 || notice != null) {
      messenger.showSnackBar(
        SnackBar(
          duration: notice != null
              ? Duration(seconds: 6)
              : const Duration(seconds: 4),
          content: Text(
            notice ??
                '${trf('opRoundUp', [formatMoney(extra, op.currency)])}'
                    '(«${widget.store.db.rules.roundUpGoal}»)',
          ),
        ),
      );
    }
  }

  /// Валюта, в которой сейчас идёт запись.
  String _currencyNow(Database db) =>
      _currency ?? _currencyOf(db, _account ?? balances(db).firstOrNull?.name);

  /// Сдвинуть день на сутки вперёд или назад. «Вчера» — одно нажатие.
  void _stepDay(int days) {
    final was = DateTime.tryParse(_date) ?? DateTime.now();
    setState(() => _date = iso(was.add(Duration(days: days))));
  }

  /// Время тем же барабаном, что и дата.
  ///
  /// Раньше здесь стояли `firstYear == lastYear`: колонка года показывала одно
  /// число и не крутилась вовсе («почему нельзя выбрать год», 13.09.2026).
  /// Барабан один и показывает дату целиком — значит и менять он должен всё,
  /// на что смотрит.
  Future<void> _pickTime() async {
    final was = DateTime.tryParse(_date) ?? DateTime.now();
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('opTimeWhen'),
      initial: _time == null
          ? DateTime(was.year, was.month, was.day, now.hour, now.minute)
          : DateTime(
              was.year,
              was.month,
              was.day,
              _hourOf(_time!),
              _minuteOf(_time!),
            ),
      firstYear: 2015,
      lastYear: DateTime.now().year + 2,
      withTime: true,
    );
    if (picked == null) return;
    setState(() {
      _date = iso(picked);
      _time =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  /// Другие пары: с ними можно разделить трату.
  List<String> get _otherSpaces =>
      widget.store.spaces.where((s) => s != widget.store.space).toList();

  /// Чем подписать пару: именем партнёра, а личное — словом.
  String _shareLabel(String groupId) {
    final db = widget.store.dbOf(groupId);
    final other = db.pair.other(_viewerOrNull ?? widget.store.viewer);
    final name = other?.name.trim() ?? '';
    return name.isEmpty ? tr('spaceAlone') : name;
  }

  Future<void> _pickShare() async {
    final picked = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.users,
        title: tr('opShareTitle'),
        text: tr('opShareText'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(
          children: [
            for (final s in _otherSpaces)
              _ShareLine(
                title: _shareLabel(s),
                on: _shareWith == s,
                onTap: () => Navigator.of(context).pop(s),
              ),
            if (_shareWith != null)
              _ShareLine(
                title: tr('opShareNone'),
                on: false,
                onTap: () => Navigator.of(context).pop(''),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _shareWith = picked.isEmpty ? null : picked);
  }

  /// Заметка — отдельным листом, а не полем на экране: она нужна дай бог
  /// каждой десятой записи, а место занимала всегда.
  /// Имя человека, и только имя: «я», «вы» и «партнёр» человек видеть не
  /// должен. Заглушка остаётся ровно на случай, когда имени нет вовсе.
  String _nameOf(Member m) {
    final name = m.name.trim();
    if (name.isNotEmpty) return name;
    return m.uid == widget.store.viewer ? tr('opMe') : tr('accountPartner');
  }

  static String _splitTitle(SplitMode mode) => switch (mode) {
    SplitMode.equal => tr('opSplitEqual'),
    SplitMode.income => tr('opSplitIncome'),
    SplitMode.payerOnly => tr('opSplitPayer'),
    SplitMode.custom => tr('splitShares'),
    SplitMode.none => tr('opSplitNone'),
  };

  /// Доли руками задаются в правилах пары, а не на бегу при записи: там у
  /// человека перед глазами обе зарплаты.
  static List<SplitMode> get _splitChoices => const [
    SplitMode.equal,
    SplitMode.income,
    SplitMode.payerOnly,
    SplitMode.none,
  ];

  /// Как делим — коротким листом снизу: четыре пилюли в ряду читались хуже,
  /// чем четыре строки с объяснением, и занимали две строки экрана.
  Future<void> _pickSplit() async {
    final picked = await showMoneySheet<SplitMode>(
      context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in _splitChoices)
              ListTile(
                leading: Icon(
                  mode == _split ? Myna.checkCircle : Myna.circle,
                  color: mode == _split
                      ? Theme.of(sheet).colorScheme.primary
                      : Theme.of(sheet).colorScheme.onSurfaceVariant,
                ),
                title: Text(_splitTitle(mode)),
                onTap: () => Navigator.pop(sheet, mode),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _split = picked);
  }

  /// Сюрприз: первое касание включает, второе спрашивает, когда открыть.
  Future<void> _secretTap() async {
    if (!_secret) {
      setState(() => _secret = true);
      return;
    }
    final open = await showMoneySheet<bool>(
      context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Myna.calendar),
              title: Text(tr('opRevealWhen')),
              onTap: () => Navigator.pop(sheet, true),
            ),
            ListTile(
              leading: const Icon(Myna.eyeOff),
              title: Text(tr('opSecretOff')),
              onTap: () => Navigator.pop(sheet, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || open == null) return;
    if (open) {
      await _pickReveal();
    } else {
      setState(() {
        _secret = false;
        _revealAt = null;
      });
    }
  }

  /// Доли числом: «Саша 740,00 · Лена 740,00». Человек должен видеть
  /// результат правила, а не догадываться о нём по названию.
  String _partsLine(Database db) {
    if (!_paired || _amount <= 0 || _kind == TxKind.transfer) return '';
    final parts = splitOf(
      Transaction(
        id: '_',
        date: '',
        kind: TxKind.expense,
        account: '',
        currency: _currencyOf(db, _account),
        amount: -_amount,
        amountBase: -_amount,
        payer: _payer ?? widget.store.viewer,
        split: _split,
      ),
      db.pair,
    );
    if (parts.length < 2) return '';
    return parts.entries
        .map(
          (e) =>
              '${_nameOf(db.pair.byUid(e.key) ?? Member(uid: e.key, name: ''))} '
              '${formatMoney(e.value, _currencyOf(db, _account))}',
        )
        .join(' · ');
  }

  Future<void> _editNote() async {
    final controller = TextEditingController(text: _note.text);
    final text = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.pencil,
        title: tr('opNote'),
        text: tr('opNoteWhy'),
        action: tr('wheelDone'),
        onAction: () => Navigator.of(context).pop(controller.text.trim()),
        child: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: tr('opNoteHint')),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
      ),
    );
    if (text == null || !mounted) return;
    setState(() => _note.text = text);
  }

  /// Завести счёт, не уходя с записи. Лист тот же, что на экране счетов:
  /// имя — ключ счёта и на сервере тоже, поэтому спрашивается только оно, а
  /// карта с цветом и цифрами правится потом.
  Future<void> _newAccount() async {
    final controller = TextEditingController();
    final name = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.creditCard,
        title: tr('accountNew'),
        text: tr('accountsNoneText'),
        action: tr('accountCreate'),
        onAction: () => Navigator.of(context).pop(controller.text.trim()),
        child: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: tr('accountNameHint'),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    widget.store.editAccount(name);
    setState(() => _account = name);
  }

  /// Что сказать про снятие из общего кошелька. Пусто — говорить нечего.
  String? _potNotice(Transaction op) {
    if (!_paired || op.kind != TxKind.expense) return null;
    final db = widget.store.db;
    final rules = db.rules;
    final sum = op.amount.abs();
    final partner =
        db.pair.other(widget.store.viewer)?.name ?? tr('opPartnerDative');

    // Крупная трата — договорённость про ЛЮБОЙ счёт, а не только про общий
    // кошелёк: «покупки дороже пяти тысяч обсуждаем».
    if (rules.bigSpend > 0 && sum > rules.bigSpend + 0.005) {
      return trf('opBigSpend', [
        formatMoney(rules.bigSpend, op.currency),
        partner,
      ]);
    }

    final at = db.accounts.indexWhere((a) => a.name == op.account);
    if (at < 0 || !db.accounts[at].isPot) return null;
    if (rules.potMaxOnce > 0 && sum > rules.potMaxOnce + 0.005) {
      return tr('opPotLimit') +
          trf('opPotLimitTail', [
            formatMoney(rules.potMaxOnce, op.currency),
            partner,
          ]);
    }
    if (rules.potNotice) return trf('opPotTell', [partner]);
    return null;
  }

  /// Перенести запись в другую пару целиком.
  ///
  /// Бывает проще, чем делить: человек записал обед в пару с женой, а обедал с
  /// другом. У Splitwise это правка группы траты, и приём людям знаком.
  Future<void> _moveToPair() async {
    final op = widget.edit;
    if (op == null) return;
    final picked = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.users,
        title: tr('opMoveTitle'),
        text: tr('opMoveText'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(
          children: [
            for (final s in _otherSpaces)
              _ShareLine(
                title: _shareLabel(s),
                on: false,
                onTap: () => Navigator.of(context).pop(s),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    widget.store.moveOperation(op, picked);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final op = widget.edit;
    if (op == null) return;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.trash,
        tone: Theme.of(context).colorScheme.error,
        title: tr('opDeleteTitle'),
        text: tr('opDeleteText'),
        action: tr('opDelete'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true && mounted) {
      widget.store.deleteOperation(op.id);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final accounts = balances(db);

    // Категории — СВОИ У КАЖДОГО СЧЁТА: чем платили этим счётом, идёт первым,
    // чужие привязанные не показываются вовсе.
    final cats = <String>{
      if (_category != null) _category!,
      ...categoriesForAccount(
        db,
        account: _account ?? accounts.firstOrNull?.name,
        income: _kind == TxKind.income,
      ),
    }.toList();

    // Подкатегории ЗАВЕДЁННЫЕ плюс встреченные в записях. Раньше здесь стояли
    // только вторые — и тридцать три подкатегории из стартового набора не
    // показывались нигде, кроме экрана категорий («их просто нет нигде»,
    // 13.09.2026).
    final subsAll = <String>{
      if (_category != null)
        for (final c in widget.store.subcategoriesOf(_category!)) c.name,
      for (final t in db.transactions)
        if (t.category == _category && t.subcategory != null) t.subcategory!,
    }.toList();

    final tint = switch (_kind) {
      TxKind.income => Money.up(context),
      TxKind.transfer => scheme.onSurfaceVariant,
      _ => Money.down(context),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? tr('opNew') : tr('opEdit')),
        actions: [
          // Разговор появляется только у записанной операции: под тем, чего
          // ещё нет, спрашивать нечего.
          if (widget.edit != null && _otherSpaces.isNotEmpty)
            IconButton(
              onPressed: _moveToPair,
              icon: const Icon(Myna.userPlus),
              tooltip: tr('opMoveToPair'),
            ),
          if (_paired && widget.edit != null)
            _TalkButton(store: widget.store, op: widget.edit!),
          if (widget.edit != null)
            IconButton(
              onPressed: _delete,
              icon: Icon(Myna.trash),
              tooltip: tr('opDelete'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      // Экран собран вокруг ОДНОГО действия: набрать сумму и записать. Всё
      // остальное — четыре строки сводки, а выбор живёт в нижней панели,
      // которая переключается по нажатию строки («низ экрана меняется по
      // нажатию строки», 14.09.2026). Прокрутки вбок в форме больше нет:
      // категории, подкатегории и счета видны целиком в своей панели.
      body: Column(
        children: [
          // Пока открыта клавиатура поиска, сводка прячется: на 393 dp ей и
          // панели вместе места нет, и кнопка «Записать» наезжала на поле
          // поиска (поймано на живом эмуляторе 14.09.2026).
          if (MediaQuery.viewInsetsOf(context).bottom < 80)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: Column(
              children: [
                _KindSegments(
                  kind: _kind,
                  onChange: (k) => setState(() {
                    _kind = k;
                    if (k == TxKind.transfer) _panel = _OpPanel.wallets;
                    // Сторона сменилась — чужая категория уходит. «Зарплата»
                    // оставалась выбранной после нажатия «Расход» и уезжала в
                    // запись доходной категорией на трату (поймано на живом
                    // эмуляторе 14.09.2026). Та же защита, что при смене
                    // счёта: выбор, который больше не показывается в панели,
                    // не должен доживать до кнопки «Записать».
                    final at = db.categories
                        .where((c) => c.name == _category)
                        .firstOrNull;
                    if (at?.kind != null && at!.isIncome != (k == TxKind.income)) {
                      _category = null;
                      _sub = null;
                    }
                  }),
                ),
                const SizedBox(height: 10),
                // Сумма — главное число экрана. Цвет несёт направление, под
                // ней тонкая черта: это поле ввода, а не заголовок.
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        children: [
                          // Число ужимается, а не обрезается: миллион с
                          // валютой 34-м кеглем не влезает, а терять цифры у
                          // главного числа экрана нельзя.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              // Пока идёт счёт, видно само выражение;
                              // закончили — сумма со знаком направления.
                              _calc.hasExpression
                                  ? '${_currencyNow(db)} ${_calc.display}'
                                  : formatMoney(
                                      _kind == TxKind.income
                                          ? _amount
                                          : -_amount,
                                      _currencyNow(db),
                                    ),
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: AppTheme.displayFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 34,
                                letterSpacing: -1.2,
                                color: _amount == 0
                                    ? scheme.onSurfaceVariant
                                    : tint,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: 1,
                            color: scheme.onSurfaceVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CurrencyButton(
                      code: _currencyNow(db),
                      onTap: () => setState(() {
                        final all = _currencyChoices(db);
                        final at = all.indexOf(_currencyNow(db));
                        _currency = all[(at + 1) % all.length];
                      }),
                      onSearch: _pickOtherCurrency,
                    ),
                  ],
                ),
                if (_otherCurrency(db) || _partsLine(db).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (_otherCurrency(db)) _crossLine(db),
                      if (_partsLine(db).isNotEmpty) _partsLine(db),
                    ].join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Сводка записи: четыре строки, и каждая — вход в свой выбор.
                // Человек видит, что получится, ещё до нажатия «Записать».
                if (accounts.isEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          trf('opAccountNew', [tr('accountDefaultName')]),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 14,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: _newAccount,
                        child: Text(tr('opAccountMake')),
                      ),
                    ],
                  ),
                // Категория доступна и БЕЗ счёта: первая запись заводит счёт
                // сама, и выбирать категорию человек вправе до этого.
                if (accounts.isEmpty && _kind != TxKind.transfer) ...[
                  const SizedBox(height: 6),
                  _SummaryRow(
                    icon: categoryIcon(_sub ?? _category ?? ''),
                    title: _category == null
                        ? tr('opPickCategory')
                        : (_sub == null ? _category! : '$_category · $_sub'),
                    note: _category == null ? tr('opPickCategoryNote') : null,
                    muted: _category == null,
                    open: _panel == _OpPanel.cats,
                    onTap: () => setState(() => _panel = _OpPanel.cats),
                  ),
                ],
                if (accounts.isNotEmpty) ...[
                  _SummaryRow(
                    icon: _kind == TxKind.transfer
                        ? Myna.arrowRight
                        : accountIcon(
                            _account ?? accounts.first.name,
                            stored: db.accounts
                                .where((a) => a.name == _account)
                                .firstOrNull
                                ?.icon,
                          ),
                    title: _kind == TxKind.transfer
                        ? '${_account ?? accounts.first.name} → ${_to ?? tr('opMovePick')}'
                        : (_account ?? accounts.first.name),
                    note: _walletNote(db, accounts),
                    open: _panel == _OpPanel.wallets,
                    onTap: () => setState(() => _panel = _OpPanel.wallets),
                  ),
                  if (_kind != TxKind.transfer) ...[
                    const SizedBox(height: 6),
                    _SummaryRow(
                      icon: categoryIcon(_sub ?? _category ?? ''),
                      title: _category == null
                          ? tr('opPickCategory')
                          : (_sub == null ? _category! : '$_category · $_sub'),
                      note: _category == null ? tr('opPickCategoryNote') : null,
                      muted: _category == null,
                      open: _panel == _OpPanel.cats,
                      onTap: () => setState(() => _panel = _OpPanel.cats),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Когда: «Вчера» — одно нажатие стрелкой, а не открытие
                  // барабана. Часы рядом: время задают редко, но задают.
                  _WhenSummary(
                    label: _whenLabel(),
                    onStep: _stepDay,
                    onDate: _pickDate,
                    onTime: _pickTime,
                    timeSet: _time != null,
                  ),
                  const SizedBox(height: 6),
                  // Мелочи одной строкой: кто платил, как делим, сюрприз,
                  // заметка и делёж с другой парой. Каждая — своим значком,
                  // включённые подсвечены.
                  _SummaryRow(
                    icon: _paired && _kind != TxKind.transfer
                        ? Myna.user
                        : Myna.pencil,
                    title: _paired && _kind != TxKind.transfer
                        ? _payerLabel()
                        : (_note.text.trim().isEmpty
                              ? tr('opNoteShort')
                              : _note.text.trim()),
                    note: _detailsNote(),
                    muted: !_paired && _note.text.trim().isEmpty,
                    onTap: _paired && _kind != TxKind.transfer
                        ? _pickPayer
                        : _editNote,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_paired)
                          _MiniAction(
                            icon: _note.text.trim().isEmpty
                                ? Myna.plus
                                : Myna.pencil,
                            tooltip: tr('opNoteShort'),
                            on: _note.text.trim().isNotEmpty,
                            onTap: _editNote,
                          ),
                        if (_paired && _kind != TxKind.transfer)
                          _MiniAction(
                            icon: Myna.usersGroup,
                            tooltip: tr('opSplitTitle'),
                            on: _split != SplitMode.none,
                            onTap: _pickSplit,
                          ),
                        if (_paired && _kind != TxKind.transfer)
                          _MiniAction(
                            icon: Myna.gift,
                            tooltip: tr('opSecretShort'),
                            on: _secret,
                            onTap: _secretTap,
                          ),
                        // Делёж с ДРУГОЙ парой: деньги уходят со своего счёта,
                        // а вторая пара видит расчёт. Без этой кнопки функция
                        // существовала бы только в памяти проекта.
                        if (_otherSpaces.isNotEmpty &&
                            _kind != TxKind.transfer)
                          _MiniAction(
                            icon: Myna.userPlus,
                            tooltip: tr('opShareWith'),
                            on: _shareWith != null,
                            onTap: _pickShare,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Панель занимает ВЕСЬ остаток экрана: клавиши растут, сетка
          // категорий показывает больше, список счетов не жмётся.
          Expanded(
            child: _PanelHost(
              panel: _panel,
              onPanel: (p) => setState(() => _panel = p),
              showCats: _kind != TxKind.transfer,
              showWallets: accounts.isNotEmpty,
              keys: _Keypad(onKey: _press),
              cats: _CatsPanel(
                categories: cats,
                subcategories: subsAll,
                category: _category,
                subcategory: _sub,
                onCategory: (c) => setState(() {
                  _category = _category == c ? null : c;
                  _sub = null;
                }),
                onSubcategory: (s) => setState(() => _sub = _sub == s ? null : s),
                onNew: _newCategory,
              ),
              wallets: _WalletsPanel(
                accounts: accounts,
                db: db,
                transfer: _kind == TxKind.transfer,
                from: _account ?? accounts.firstOrNull?.name,
                to: _to,
                onFrom: (name) => setState(() {
                  _account = name;
                  final fits = db.categories
                      .where((c) => c.name == _category)
                      .firstOrNull;
                  if (fits != null &&
                      fits.accounts.isNotEmpty &&
                      !fits.accounts.contains(name)) {
                    _category = null;
                    _sub = null;
                  }
                }),
                onTo: (name) => setState(() => _to = _to == name ? null : name),
                onNew: _newAccount,
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: SizedBox(
                width: double.infinity,
                // Пока идёт счёт, главная кнопка читается «=» и закрывает
                // выражение: две кнопки под большим пальцем спорили бы.
                child: FilledButton(
                  onPressed: _calc.hasExpression
                      ? () => _press('=')
                      : (_canSave ? _save : null),
                  child: Text(
                    _calc.hasExpression
                        ? '='
                        : (_kind == TxKind.transfer && _to == null
                              ? tr('opMovePick')
                              : (widget.edit == null
                                    ? tr('opSave')
                                    : tr('opSaveWord'))),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Остаток выбранного счёта строкой под его именем.
  String _walletNote(Database db, List<AccountBalance> accounts) {
    final name = _account ?? accounts.firstOrNull?.name;
    final at = accounts.where((a) => a.name == name).firstOrNull;
    if (at == null) return '';
    return formatMoney(at.mainAmount, at.mainCurrency);
  }

  /// «Сегодня · 14:20» — одной строкой, время только если его задали.
  String _whenLabel() {
    final day = DateTime.tryParse(_date) ?? DateTime.now();
    final today = DateTime.now();
    final diff = DateTime(day.year, day.month, day.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    final word = switch (diff) {
      0 => tr('opToday'),
      -1 => tr('opYesterday'),
      1 => tr('opTomorrow'),
      _ => Period(PeriodKind.day, day).label,
    };
    return _time == null ? word : '$word · $_time';
  }

  /// Что ещё висит на записи: заметка, делёж, сюрприз. Пусто — строка молчит.
  String? _detailsNote() {
    final shared = _paired && _kind != TxKind.transfer;
    final parts = <String>[
      // Заметка попадает в подпись только когда строка озаглавлена именем
      // плательщика: иначе она уже стоит заголовком и повторять её незачем.
      if (shared && _note.text.trim().isNotEmpty) _note.text.trim(),
      if (shared && _split != SplitMode.none) _splitTitle(_split),
      if (shared && _secret) tr('opSecretShort'),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Кто платил: имя, а не «Вы» — в паре у обоих есть имя.
  String _payerLabel() {
    final who = _payer ?? widget.store.viewer;
    final m = widget.store.db.pair.members
        .where((x) => x.uid == who)
        .firstOrNull;
    return m == null ? tr('peopleMine') : _nameOf(m);
  }

  /// Выбор плательщика — нижним листом: в паре их двое, а не двадцать.
  Future<void> _pickPayer() async {
    final members = widget.store.db.pair.members;
    if (members.length < 2) return;
    final picked = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.user,
        title: tr('opPayerTitle'),
        text: tr('opPayerNote'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(
          children: [
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ShareLine(
                  title: _nameOf(m),
                  on: (_payer ?? widget.store.viewer) == m.uid,
                  onTap: () => Navigator.of(context).pop(m.uid),
                ),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _payer = picked);
  }


  /// Валюты на выбор — ТОЛЬКО свои: валюта счёта, базовая, валюты остальных
  /// счетов и те, которыми уже платили. Курсы сервер отдаёт на полторы сотни
  /// валют, и если показать их все, экран записи траты превращается в
  /// справочник валют мира. Остальные — за кнопкой «Другая».
  List<String> _currencyChoices(Database db) {
    final own = _currencyOf(db, _account ?? db.accounts.firstOrNull?.name);
    return <String>{
      own,
      db.baseCurrency,
      ...db.accounts.map((a) => a.currency),
      ...db.transactions.map((t) => t.currency),
      if (_currency != null) _currency!,
    }.where((c) => c.isNotEmpty).toList()..sort();
  }

  /// Валюта вне своего списка: тот же экран поиска, что в настройках, — с
  /// флагами и названиями. Голые коды пилюлями человек отверг прямо:
  /// «почему валюта вот так тупо» (13.09.2026).
  Future<void> _pickOtherCurrency() async {
    final db = widget.store.db;
    final picked = await pickCurrency(
      context,
      current: _currency,
      mine: _currencyChoices(db),
    );
    if (picked == null || !mounted) return;
    setState(() => _currency = picked);
    // Курса у новой валюты может не быть вовсе, и тогда пересчёт врёт один к
    // одному. Спрашиваем сервер сразу, молча: человек за этим не следит.
    await _ensureRate(picked);
  }

  /// Подтянуть курс валюты, если его нет. Без входа в аккаунт молчим: сказать
  /// об этом есть кому — подпись под суммой.
  Future<void> _ensureRate(String code) async {
    final store = widget.store;
    final db = store.db;
    if (code == db.baseCurrency) return;
    final have = db.rates[code];
    if (have != null && have > 0) return;
    final session = widget.session;
    if (session == null || !session.signedIn) return;
    try {
      final r = await session.get('/api/money/rates?base=${db.baseCurrency}');
      final table = (r['rates'] as Map?) ?? const {};
      final value = (table[code] as num?)?.toDouble();
      if (value != null && value > 0) {
        store.setRate(code, value);
        if (mounted) setState(() {});
      }
    } on SessionError {
      // Молча: курс задаётся руками в настройках, и подпись под суммой уже
      // говорит, что его нет.
    }
  }

  /// Валюта операции отличается от валюты счёта.
  bool _otherCurrency(Database db) {
    final own = _currencyOf(db, _account ?? db.accounts.firstOrNull?.name);
    return _currency != null && _currency != own;
  }

  /// Пересчёт под суммой: человек видит, во что это превратится в итогах, и
  /// замечает, если курс не задан.
  String _crossLine(Database db) {
    final code = _currency!;
    final base = db.baseCurrency;
    if (code == base) return tr('opSameAmount');
    final rate = db.rates[code];
    if (rate == null || rate <= 0) {
      return trf('opRateMissing', [code]);
    }
    return '≈ ${formatMoney(convert(db, _amount, code), base)} '
        '${trf('opRate', [formatAmount(rate, decimals: 4)])}';
  }

  String _currencyOf(Database db, String? account) {
    if (account == null) return db.baseCurrency;
    final at = db.accounts.indexWhere((a) => a.name == account);
    return at >= 0 ? db.accounts[at].currency : db.baseCurrency;
  }

  /// Дата и время одним барабаном. Время необязательно: пока человек его не
  /// тронул, операция стоит в начале дня и минуты нигде не мозолят глаз.
  Future<void> _pickDate() async {
    final was = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('wheelWhen'),
      initial: _time == null
          ? was
          : DateTime(
              was.year,
              was.month,
              was.day,
              _hourOf(_time!),
              _minuteOf(_time!),
            ),
      firstYear: 2015,
      lastYear: DateTime.now().year + 2,
      withTime: true,
    );
    if (picked == null) return;
    setState(() {
      _date = iso(picked);
      _time =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  static int _hourOf(String time) => int.tryParse(time.split(':').first) ?? 0;
  static int _minuteOf(String time) => int.tryParse(time.split(':').last) ?? 0;

  /// Завести категорию, не уходя с записи.
  ///
  /// Тем же листом, что и на экране категорий: со значком, цветом, долей и
  /// видом. Раньше здесь спрашивали одно имя и не сохраняли ничего — категория
  /// жила до закрытия экрана.
  Future<void> _newCategory() async {
    final name = await addCategorySheet(
      context,
      widget.store,
      kind: _kind == TxKind.income ? CatKind.income : CatKind.expense,
    );
    if (name == null || !mounted) return;
    setState(() {
      _category = name;
      _sub = null;
    });
  }
}

/// Кнопка разговора со счётчиком сказанного: без числа непонятно, есть ли
/// там вопрос, и туда не заходят.
class _TalkButton extends StatelessWidget {
  const _TalkButton({required this.store, required this.op});

  final Store store;
  final Transaction op;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final count = store.commentsOf(op.id).length;
        return IconButton(
          onPressed: () => showComments(context, store, op),
          tooltip: tr('opTalk'),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Myna.chat),
          ),
        );
      },
    );
  }
}


/// Подпись над рядом карт в переводе: «Откуда» и «Куда».
///

class _Pick extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  const _Pick({
    required this.name,
    required this.icon,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(name),
      selected: on,
      // Галочка выбора ЗАКРЫВАЛА значок категории: Material подменяет ею
      // avatar. Человек выбирал «Тест» и переставал видеть, какой у неё знак
      // (13.09.2026). Выбор и так виден заливкой.
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

/// Валюта рядом с суммой: касание перебирает свои, значок поиска открывает
/// все. Рядом пилюль под суммой не осталось — из-за него категории уезжали за
/// нижний край экрана.
class _CurrencyButton extends StatelessWidget {
  const _CurrencyButton({
    required this.code,
    required this.onTap,
    required this.onSearch,
  });

  final String code;
  final VoidCallback onTap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Text(
                code,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: scheme.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSearch,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: tr('opCurrencyOther'),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(Myna.search, size: 18, color: scheme.onSurface),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KindSegments extends StatelessWidget {
  final TxKind kind;
  final ValueChanged<TxKind> onChange;
  const _KindSegments({required this.kind, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (TxKind.expense, tr('opSpending')),
      (TxKind.income, tr('opIncome')),
      (TxKind.transfer, tr('opTransfer')),
    ];
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final (value, name) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChange(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: AppTheme.emphasized,
                  decoration: BoxDecoration(
                    color: kind == value ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kind == value
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Своя клавиатура: системная на телефоне занимает половину экрана и прячет
/// счёт с категорией, а из знаков нужны десять цифр и стирание.
class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  const _Keypad({required this.onKey});

  /// Высота клавиши. Ниже 46 палец не ловит, выше 56 клавиатура выглядит
  /// растянутой и начинает теснить форму.
  static const double _keyHeight = 46;
  static const double _keyHeightMax = 56;

  /// Сколько клавиатура занимает как минимум. По этому числу экран отводит ей
  /// место раньше формы.
  static const double minHeight = 4 * _keyHeight + 8;

  static bool _isOp(String key) =>
      const ['+', '-', '*', '/', '%'].contains(key);

  /// Что написано на клавише. В коде знаки латинские, на экране — настоящие:
  /// звёздочка вместо умножения выглядит опечаткой.
  static String _face(String key) => switch (key) {
    '*' => '×',
    '/' => '÷',
    '-' => '−',
    _ => key,
  };

  /// Четыре столбца: три цифровых и один со знаками действия.
  ///
  /// Знаки стоят СПРАВА, а не слева, как в подсмотренном приложении: правая
  /// кромка ближе к большому пальцу, а цифры человек ищет глазами по сетке и
  /// от края они не зависят.
  static const _rows = [
    ['1', '2', '3', '/'],
    ['4', '5', '6', '*'],
    ['7', '8', '9', '-'],
    ['00', '0', 'del', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      // Клавиша высокая НАРОЧНО: свободное место на экране лучше отдать ей,
      // чем оставить пустотой под формой. Палец попадает без прицела.
      constraints: const BoxConstraints(
        minHeight: minHeight,
        maxHeight: 4 * _keyHeightMax + 8,
      ),
      child: Column(
        children: [
          for (final row in _rows)
            Expanded(
              child: Row(
                children: [
                  for (final key in row)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: SizedBox(
                          height: double.infinity,
                          child: Material(
                            // Знаки действия отличаются НАЧЕРТАНИЕМ, а не
                            // заливкой: на печатной палитре между
                            // `surfaceContainer` и `surfaceContainerHighest`
                            // контраст 1,07 — тонировка была задумана, но на
                            // экране её не существовало, и четыре клавиши
                            // выглядели надписями без кнопок.
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => onKey(key),
                              child: Center(
                                child: key == 'del'
                                    ? Icon(
                                        Myna.delete,
                                        size: 20,
                                        color: scheme.onSurface,
                                      )
                                    : Text(
                                        _face(key),
                                        style: TextStyle(
                                          fontFamily: AppTheme.bodyFont,
                                          fontSize: _isOp(key) ? 24 : 21,
                                          fontWeight: _isOp(key)
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Валюты, которые встречаются у нас чаще прочих. Нужны, когда курсов ещё нет
/// вовсе: без них поиск «Другая» был бы пустым на новом устройстве.

/// Поиск валюты: тот же приём, что у банков в уведомлениях — своё наверху,
/// остальное за полем ввода.

/// Строка выбора пары для дележа.
class _ShareLine extends StatelessWidget {
  const _ShareLine({
    required this.title,
    required this.on,
    required this.onTap,
  });

  final String title;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: on
              ? BorderSide(color: scheme.primary, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (on) Icon(Myna.check, size: 20, color: scheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



/// Что показывает нижняя панель экрана записи.
enum _OpPanel { keys, cats, wallets }

/// Строка сводки: значок, что выбрано, и вход в свой выбор.
///
/// Строки заменили ряды пилюль с прокруткой вбок. В ряду было видно две с
/// половиной категории из двадцати шести, и человек искал свою вслепую
/// («не нравится, что надо пролистывать данные», 14.09.2026). Строка говорит,
/// что выбрано сейчас, а выбор целиком живёт в панели снизу.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    this.note,
    this.trailing,
    this.open = false,
    this.muted = false,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? note;

  /// Мелкие действия справа: время, заметка, делёж, сюрприз.
  final Widget? trailing;

  /// Строка открыта — её панель сейчас снизу.
  final bool open;

  /// Ничего не выбрано: подпись приглушена, как подсказка поля.
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      // Material принимает ЛИБО shape, ЛИБО borderRadius — вместе валят
      // ассерт material.dart:209, и в релизе это молчит.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: open
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                    if (note != null && note!.isNotEmpty)
                      Text(
                        note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 11.5,
                          height: 1.25,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing! else
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Myna.chevronRight,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка «когда»: шаг дня стрелками, дата по центру, часы справа.
///
/// Стрелки остались от прежней формы нарочно: «Вчера» — одно нажатие, а не
/// открытие барабана, и по записям это самый частый случай после «Сегодня».
class _WhenSummary extends StatelessWidget {
  const _WhenSummary({
    required this.label,
    required this.onStep,
    required this.onDate,
    required this.onTime,
    required this.timeSet,
  });

  final String label;
  final ValueChanged<int> onStep;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final bool timeSet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
        child: Row(
          children: [
            _MiniAction(
              icon: Myna.chevronLeft,
              tooltip: tr('opYesterday'),
              onTap: () => onStep(-1),
            ),
            Expanded(
              child: InkWell(
                onTap: onDate,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            _MiniAction(
              icon: Myna.chevronRight,
              tooltip: tr('opTomorrow'),
              onTap: () => onStep(1),
            ),
            // Часы отделены чертой: это не шаг дня, а другое поле, и без
            // черты три круглые кнопки подряд читались одной группой.
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: scheme.outlineVariant,
            ),
            _MiniAction(
              icon: Myna.clockCircle,
              tooltip: tr('opTime'),
              on: timeSet,
              onTap: onTime,
            ),
          ],
        ),
      ),
    );
  }
}

/// Мелкое действие в строке сводки: время, заметка, делёж, сюрприз.
class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.on = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: on ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 17,
              color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Нижняя панель с вкладками: клавиши, категория, счёт.
///
/// Одна панель на три состояния вместо трёх рядов, вылезающих за край.
class _PanelHost extends StatelessWidget {
  const _PanelHost({
    required this.panel,
    required this.onPanel,
    required this.showCats,
    required this.showWallets,
    required this.keys,
    required this.cats,
    required this.wallets,
  });

  final _OpPanel panel;
  final ValueChanged<_OpPanel> onPanel;
  final bool showCats;
  final bool showWallets;
  final Widget keys;
  final Widget cats;
  final Widget wallets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tabs = <(_OpPanel, String)>[
      (_OpPanel.keys, tr('opTabKeys')),
      if (showCats) (_OpPanel.cats, tr('opTabCategory')),
      if (showWallets) (_OpPanel.wallets, tr('opTabWallet')),
    ];
    final shown = tabs.any((t) => t.$1 == panel) ? panel : _OpPanel.keys;

    // Панель — ЦЕЛЬНЫЙ блок со скруглённым верхом, а не полоса под чертой.
    // Острый край с линией сверху человек отверг прямо: «он острый, так ещё у
    // него есть бордер» (14.09.2026). Глубину держит ступень поверхности —
    // панель светлее листа, — и этого довольно.
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TmRadius.sheet),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (tabs.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: PickRow(
                height: 38,
                children: [
                  for (final t in tabs)
                    ChoiceChip(
                      label: Text(t.$2),
                      selected: shown == t.$1,
                      showCheckmark: false,
                      onSelected: (_) => onPanel(t.$1),
                    ),
                ],
              ),
            ),
          Expanded(
            child: switch (shown) {
              _OpPanel.keys => keys,
              _OpPanel.cats => cats,
              _OpPanel.wallets => wallets,
            },
          ),
        ],
      ),
    );
  }
}

/// Панель категорий: поиск, подкатегории выбранной и сетка всех остальных.
///
/// Подкатегории тут обязательны: «снова игнорируешь подкатегории»
/// (14.09.2026). Они стоят прямо над сеткой и выбираются одним касанием —
/// отдельного экрана для них нет и не нужно.
///
/// Поиск — правило системы: список длиннее десятка всегда с поиском, а
/// категорий в стартовом наборе двадцать шесть.
class _CatsPanel extends StatefulWidget {
  const _CatsPanel({
    required this.categories,
    required this.subcategories,
    required this.category,
    required this.subcategory,
    required this.onCategory,
    required this.onSubcategory,
    required this.onNew,
  });

  final List<String> categories;
  final List<String> subcategories;
  final String? category;
  final String? subcategory;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onSubcategory;
  final VoidCallback onNew;

  @override
  State<_CatsPanel> createState() => _CatsPanelState();
}

class _CatsPanelState extends State<_CatsPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.categories
        : widget.categories
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    final subs = q.isEmpty
        ? widget.subcategories
        : widget.subcategories
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    // При поиске подкатегории показываются ЛЮБОЙ категории: человек ищет
    // «кофе», а не «продукты → кофе».
    final showSubs = q.isEmpty
        ? widget.category != null && widget.subcategories.isNotEmpty
        : subs.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: SizedBox(
            height: 40,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                color: scheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                hintText: tr('opCategorySearch'),
                prefixIcon: Icon(
                  Myna.search,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        if (showSubs) ...[
          const SizedBox(height: 8),
          PickRow(
            height: 38,
            children: [
              for (final sub in subs)
                _Pick(
                  name: sub,
                  icon: categoryIcon(sub),
                  on: widget.subcategory == sub,
                  onTap: () => widget.onSubcategory(sub),
                ),
            ],
          ),
        ],
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              // Считаем от ШИРИНЫ, а не от числа колонок: на 320 dp встают
              // три плитки, на 430 — четыре, и ни одна не расплющивается.
              maxCrossAxisExtent: 112,
              // Высота под ДВЕ строки подписи: «Покупки в магазинах» и
              // «Разработка ST STATICS» иначе обрезались на второй строке.
              mainAxisExtent: 94,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: shown.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _CatCell(
                  name: tr('opSplitOwn'),
                  icon: Myna.plus,
                  on: false,
                  tint: scheme.surfaceContainerHighest,
                  onTap: widget.onNew,
                );
              }
              final c = shown[i - 1];
              return _CatCell(
                name: c,
                icon: categoryIcon(c),
                on: widget.category == c,
                tint: labelColorFor(c),
                onTap: () => widget.onCategory(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Плитка категории: цветная метка со значком и имя под ней.
class _CatCell extends StatelessWidget {
  const _CatCell({
    required this.name,
    required this.icon,
    required this.on,
    required this.tint,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final bool on;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primary : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: inkOn(tint)),
              ),
              const SizedBox(height: 5),
              // Имя ужимается до размера плитки, а не режется на полуслове:
              // «Связь и подписки» обрывалось на «Связь и подпи…».
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: 100,
                    child: Text(
                      name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 11,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        color: on ? scheme.onPrimary : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Панель счетов: те же карты, что в галерее, только в два столбца и целиком
/// на виду — листать вбок, чтобы найти свою, больше не нужно.
class _WalletsPanel extends StatelessWidget {
  const _WalletsPanel({
    required this.accounts,
    required this.db,
    required this.transfer,
    required this.from,
    required this.to,
    required this.onFrom,
    required this.onTo,
    required this.onNew,
  });

  final List<AccountBalance> accounts;
  final Database db;

  /// У перевода счетов ДВА: откуда и куда. Первое касание меняет «откуда»,
  /// второе по другой карте — «куда».
  final bool transfer;
  final String? from;
  final String? to;
  final ValueChanged<String> onFrom;
  final ValueChanged<String> onTo;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (transfer)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              to == null ? tr('opMoveFrom') : tr('opMoveTo'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 190,
              mainAxisExtent: 62,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: accounts.length + 1,
            itemBuilder: (context, i) {
              if (i == accounts.length) {
                return _WalletCell(
                  name: tr('opAccountMake'),
                  note: '',
                  icon: Myna.plus,
                  tint: scheme.surfaceContainerHighest,
                  state: _WalletState.none,
                  onTap: onNew,
                );
              }
              final a = accounts[i];
              final stored = db.accounts
                  .where((x) => x.name == a.name)
                  .firstOrNull;
              final color = stored?.color != null
                  ? Color(stored!.color!)
                  : designOf(stored, a.name).fill;
              final state = a.name == from
                  ? _WalletState.from
                  : (transfer && a.name == to
                        ? _WalletState.to
                        : _WalletState.none);
              return _WalletCell(
                name: a.name,
                note: formatMoney(a.mainAmount, a.mainCurrency),
                icon: accountIcon(a.name, stored: stored?.icon),
                tint: color,
                state: state,
                onTap: () {
                  if (transfer && a.name != from) {
                    onTo(a.name);
                  } else {
                    onFrom(a.name);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _WalletState { none, from, to }

/// Строка счёта в панели: метка, имя и остаток.
class _WalletCell extends StatelessWidget {
  const _WalletCell({
    required this.name,
    required this.note,
    required this.icon,
    required this.tint,
    required this.state,
    required this.onTap,
  });

  final String name;
  final String note;
  final IconData icon;
  final Color tint;
  final _WalletState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = state != _WalletState.none;
    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: on
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: inkOn(tint)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // У перевода видно, какая карта «откуда», а какая «куда».
              if (state == _WalletState.to)
                Icon(Myna.arrowRight, size: 16, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}