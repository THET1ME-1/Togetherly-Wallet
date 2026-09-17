import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/haptics.dart';
import '../logic/money.dart';
import '../logic/notice_match.dart';
import '../logic/period.dart';
import '../logic/stats.dart';
import '../services/ads.dart';
import '../services/notices.dart';
import '../widgets/ad_banner.dart';
import '../widgets/member_badge.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/money_text.dart';
import '../widgets/period_bar.dart';
import '../widgets/reveal.dart';
import 'category_pick_screen.dart';
import '../widgets/settings_kit.dart';
import '../widgets/app_sheet.dart';
import 'filters_sheet.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';

/// Лента операций: поиск, отрезок с итогами, дни группами. Всё, что нужно,
/// чтобы найти одну операцию среди трёх сотен за пару касаний.
class LedgerScreen extends StatefulWidget {
  /// Реклама. Пусто — её нет: подписка, iPhone или тест.
  final Ads? ads;

  final Store store;
  final Period period;
  final ValueChanged<Period> onPeriod;
  final Filter filter;
  final ValueChanged<Filter> onFilter;
  final ValueChanged<Transaction> onEdit;

  /// Логотипы банков: у операции с банковской карты вместо казённого значка
  /// счёта стоит знак самого банка — так строка узнаётся с одного взгляда.
  final Notices? notices;

  const LedgerScreen({
    super.key,
    required this.store,
    this.ads,
    required this.period,
    required this.onPeriod,
    required this.filter,
    required this.onFilter,
    required this.onEdit,
    this.notices,
  });

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  late final TextEditingController _search =
      TextEditingController(text: widget.filter.search);
  final _shown = <Object>{};

  /// Порядок в ленте живёт на экране, а не в отборе: это способ смотреть, а не
  /// условие, и в счётчик отбора он попадать не должен.
  LedgerSort _sort = LedgerSort.dateDesc;

  /// Выбранные записи. Пусто — обычная лента; непусто — режим выбора, и
  /// короткое касание берёт запись в пачку, а не открывает её на правку.
  final _picked = <String>{};

  bool get _selecting => _picked.isNotEmpty;

  void _toggle(Transaction op) {
    setState(() {
      if (!_picked.remove(op.id)) _picked.add(op.id);
    });
    Tap.pick();
  }

  void _startPick(Transaction op) {
    if (_selecting) return _toggle(op);
    setState(() => _picked.add(op.id));
    // Вход в режим отвечает сильнее выбора: человек держал палец и должен
    // почувствовать, что лента сменила поведение.
    Tap.warn();
  }

  void _clearPick() => setState(_picked.clear);

  @override
  void didUpdateWidget(LedgerScreen old) {
    super.didUpdateWidget(old);
    // Отбор могли сбросить снаружи — строка поиска должна это показать.
    if (widget.filter.search != _search.text) _search.text = widget.filter.search;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickSort() async {
    final next = await showModalBottomSheet<LedgerSort>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in LedgerSort.values)
            ListTile(
              onTap: () => Navigator.of(context).pop(s),
              leading: Icon(
                s == _sort ? Myna.checkCircle : Myna.circle,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                ledgerSortTitle(s),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 15,
                  fontWeight: s == _sort ? FontWeight.w700 : FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (next != null) setState(() => _sort = next);
  }

  /// Выбрать всё, что сейчас на экране.
  ///
  /// Именно видимое, а не всю базу: человек пришёл из отбора «Кафе за
  /// сентябрь» и ждёт, что «всё» — это оно, а не десять лет записей.
  void _pickAll(List<Transaction> rows) {
    setState(() {
      if (_picked.length == rows.length) {
        _picked.clear();
      } else {
        _picked
          ..clear()
          ..addAll(rows.map((t) => t.id));
      }
    });
    Tap.pick();
  }

  /// Что можно сделать с пачкой. Лист снизу — правило приложения.
  Future<void> _bulkSheet(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;
    await showMoneySheet<void>(
      context,
      builder: (sheet) => SheetScaffold(
        icon: Myna.checkCircle,
        title: trf('bulkChosen', ['${_picked.length}']),
        action: tr('bulkDelete'),
        tone: scheme.error,
        onAction: () {
          Navigator.of(sheet).pop();
          _deletePicked();
        },
        cancel: tr('close'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SettingsRow(
            icon: Myna.tag,
            title: tr('bulkCategory'),
            subtitle: tr('bulkCategoryNote'),
            trailing: const SettingsChevron(),
            onTap: () {
              Navigator.of(sheet).pop();
              _categorizePicked();
            },
          ),
          SettingsRow(
            icon: Myna.creditCard,
            title: tr('bulkAccount'),
            subtitle: tr('bulkAccountNote'),
            trailing: const SettingsChevron(),
            onTap: () {
              Navigator.of(sheet).pop();
              _movePicked();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _deletePicked() async {
    final count = _picked.length;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (sheet) => SheetScaffold(
        icon: Myna.trash,
        tone: Theme.of(sheet).colorScheme.error,
        title: trf('bulkDeleteTitle', ['$count']),
        text: tr('bulkDeleteText'),
        action: tr('bulkDelete'),
        onAction: () => Navigator.of(sheet).pop(true),
      ),
    );
    if (yes != true || !mounted) return;
    Tap.warn();
    widget.store.deleteMany(_picked.toList());
    _clearPick();
  }

  Future<void> _categorizePicked() async {
    final picked = await pickCategory(context, store: widget.store);
    if (picked == null || !mounted) return;
    Tap.done();
    widget.store.categorizeMany(
      _picked.toList(),
      category: picked.category,
      subcategory: picked.subcategory,
    );
    _clearPick();
  }

  Future<void> _movePicked() async {
    final accounts = [
      for (final a in widget.store.view.accounts)
        if (!isVirtualAccount(a.name)) a.name,
    ];
    if (accounts.isEmpty) return;
    final chosen = await showMoneySheet<String>(
      context,
      builder: (sheet) => SheetScaffold(
        icon: Myna.creditCard,
        title: tr('bulkAccount'),
        text: tr('bulkAccountNote'),
        action: tr('close'),
        onAction: () => Navigator.of(sheet).pop(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final name in accounts)
            SettingsRow(
              icon: Myna.creditCard,
              title: name,
              onTap: () => Navigator.of(sheet).pop(name),
            ),
        ]),
      ),
    );
    if (chosen == null || !mounted) return;
    Tap.done();
    widget.store.moveMany(_picked.toList(), account: chosen);
    _clearPick();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.view;
    final base = db.baseCurrency;
    final rows = visible(db, widget.period, filter: widget.filter, sort: _sort);
    final byDay = ledgerSortByDay(_sort);
    final groups = byDay ? groupByDay(db, rows) : const <DayGroup>[];
    final flow = cashflow(db, widget.period, filter: widget.filter);

    return CustomScrollView(
      slivers: [
        if (_selecting)
          SliverAppBar(
            pinned: true,
            titleSpacing: 6,
            toolbarHeight: 72,
            leading: IconButton(
              onPressed: _clearPick,
              icon: const Icon(Myna.x),
              tooltip: tr('bulkCancel'),
            ),
            title: Text(
              trf('bulkChosen', ['${_picked.length}']),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => _pickAll(rows),
                icon: const Icon(Myna.checkCircle),
                tooltip: tr('bulkAll'),
              ),
              IconButton(
                onPressed: () => _bulkSheet(context),
                icon: const Icon(Myna.dots),
                tooltip: tr('bulkActions'),
              ),
              const SizedBox(width: 6),
            ],
          )
        else
          SliverAppBar(
            pinned: true,
            titleSpacing: 14,
            toolbarHeight: 72,
            title: _SearchField(
              controller: _search,
              onChanged: (v) =>
                  widget.onFilter(widget.filter.copyWith(search: v)),
            ),
          ),
        SliverToBoxAdapter(
          child: PeriodBar(
            period: widget.period,
            onChange: widget.onPeriod,
            filterCount: widget.filter.count,
            onFilter: () async {
              final next = await pickFilter(context, widget.store, widget.filter);
              if (next != null) widget.onFilter(next);
            },
            onSort: _pickSort,
            sorted: _sort != LedgerSort.dateDesc,
          ),
        ),
        // История у пары общая, а разделение по людям человек включает сам.
        if (db.pair.members.length > 1)
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
              child: Row(children: [
                _PersonChip(
                  label: tr('peopleAll'),
                  selected: widget.filter.people.isEmpty,
                  onTap: () => widget.onFilter(widget.filter.copyWith(people: const {})),
                ),
                for (final m in db.pair.members) ...[
                  const SizedBox(width: 8),
                  _PersonChip(
                    member: m,
                    isMe: m.uid == widget.store.viewer,
                    selected: widget.filter.people.contains(m.uid),
                    onTap: () => widget.onFilter(widget.filter.copyWith(
                      people: widget.filter.people.contains(m.uid)
                          ? const {}
                          : {m.uid},
                    )),
                  ),
                ],
              ]),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            // Три суммы делят строку поровну и ужимаются каждая в своей
            // трети: на 320 dp при шрифте 1.3 они не влезали и уезжали за край.
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: MoneyText(flow.income,
                        currency: base, size: 13.5, color: Money.up(context)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: MoneyText(flow.expense,
                        currency: base, size: 13.5, color: Money.down(context)),
                  ),
                ),
                // Зазор обязателен: ужатые миллиарды занимают свою треть
                // целиком и без него слипаются в «…99,99MDL 988…».
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: MoneyText(flow.total,
                        currency: base,
                        size: 13.5,
                        colored: true,
                        weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.filter.count > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Myna.x, size: 18),
                  label: Text(trf('ledgerClearFilter', [widget.filter.count])),
                  onPressed: () => widget.onFilter(const Filter()),
                ),
              ),
            ),
          ),
        // Пустота считается по операциям, а не по дневным блокам: в порядке
        // «по сумме» блоков нет вовсе, и лента показывала «операций нет» при
        // полном списке.
        if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Myna.fileText, size: 54, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    widget.filter.isEmpty
                        ? tr('ledgerEmpty')
                        : tr('ledgerFilterEmpty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 140),
            sliver: byDay
                ? SliverList.builder(
                    // Баннер идёт СТРОКОЙ в ленте, после первого дня операций,
                    // а не липкой полосой внизу: так он не спорит с кнопкой
                    // «плюс» и не перекрывает суммы у правого края.
                    itemCount: groups.length + (widget.ads != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      final ads = widget.ads;
                      if (ads != null && i == 1) {
                        return AdBanner(ads: ads, spot: AdSpot.ledger);
                      }
                      final at = ads != null && i > 1 ? i - 1 : i;
                      final block = _DayBlock(
                        group: groups[at],
                        store: widget.store,
                        onEdit: widget.onEdit,
                        shown: _shown,
                        picked: _picked,
                        selecting: _selecting,
                        onToggle: _toggle,
                        onLongPress: _startPick,
                        logos: widget.notices?.logos ?? const {},
                      );
                      // Мягко выходят ТОЛЬКО первые дни. Дальше задержки
                      // превратили бы долистывание в череду вспышек: у
                      // человека за годы лента длиной в тысячи строк.
                      if (at > 2) return block;
                      return Reveal(
                        group: _shown,
                        id: 'day-${groups[at].date}',
                        delay: Duration(milliseconds: 40 * at),
                        child: block,
                      );
                    },
                  )
                // По сумме список идёт подряд: дни в таком порядке ничего не
                // группируют, а заголовок над каждой строкой читался бы
                // поломкой.
                : SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => OperationRow(
                      store: widget.store,
                      op: rows[i],
                      onTap: () => _selecting
                          ? _toggle(rows[i])
                          : widget.onEdit(rows[i]),
                      onLongPress: () => _startPick(rows[i]),
                      selecting: _selecting,
                      selected: _picked.contains(rows[i].id),
                      logos: widget.notices?.logos ?? const {},
                    ),
                  ),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 15,
          color: scheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: tr('ledgerSearch'),
          hintStyle: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 14.5,
            color: scheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(Myna.search, color: scheme.onSurfaceVariant),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Myna.x),
                  color: scheme.onSurfaceVariant,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: scheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  final DayGroup group;
  final Store store;
  final ValueChanged<Transaction> onEdit;
  final Set<Object> shown;
  final Map<String, Uint8List> logos;

  /// Выбор пачкой: что выбрано, как включить и как переключить строку.
  final Set<String> picked;
  final bool selecting;
  final ValueChanged<Transaction> onToggle;
  final ValueChanged<Transaction> onLongPress;

  const _DayBlock({
    required this.group,
    required this.store,
    required this.onEdit,
    required this.shown,
    required this.picked,
    required this.selecting,
    required this.onToggle,
    required this.onLongPress,
    this.logos = const {},
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = dayCaption(group.date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                caption.number,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.weekday,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      caption.month,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Итог дня встаёт на тот же правый край, что и суммы строк:
              // отступы у дня и у строки одинаковые, значит колонка одна.
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: MoneyText(
                    group.total,
                    currency: store.view.baseCurrency,
                    size: 14,
                    colored: true,
                    weight: FontWeight.w700,
                    squeeze: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < group.rows.length; i++)
          Reveal(
            group: shown,
            id: group.rows[i].id,
            delay: Duration(milliseconds: 16 * (i < 8 ? i : 8)),
            child: OperationRow(
              store: store,
              op: group.rows[i],
              onTap: () => selecting
                  ? onToggle(group.rows[i])
                  : onEdit(group.rows[i]),
              onLongPress: () => onLongPress(group.rows[i]),
              selecting: selecting,
              selected: picked.contains(group.rows[i].id),
              logos: logos,
            ),
          ),
      ],
    );
  }
}

/// Подпись строки не повторяет то, что уже сказано слева. У выплат Togetherly+
/// заметка начинается с имени счёта, и без этого шла колонка
/// «Togetherly+ · Togetherly+ — покупка» одинаковых строк подряд.
String _subtitle(String account, String? note) {
  // Счёт-расчёт — не кошелёк: показывать «Свои деньги: u_sasha» человеку
  // нельзя. Это трата, которую с ним разделили из другой пары.
  if (isOutsideAccount(account)) {
    final text = (note ?? '').trim();
    return text.isEmpty ? tr('opFromOwn') : '${tr('opFromOwn')} · $text';
  }
  final text = (note ?? '').trim();
  if (text.isEmpty) return account;
  final low = text.toLowerCase();
  final head = account.toLowerCase();
  if (low.startsWith(head)) {
    final tail = text.substring(account.length).replaceFirst(RegExp(r'^[\s—–·-]+'), '');
    return tail.isEmpty ? account : '$account · $tail';
  }
  return '$account · $text';
}

/// Как делится — словом. Кто платил, говорит бейдж с аватаром: имя в общей
/// строке стояло последним и обрезалось первым («Общий кошелёк · Linella · Лен…»).
String _splitWord(Transaction op) => switch (op.split) {
      SplitMode.equal => tr('splitEqual'),
      SplitMode.income => tr('splitIncome'),
      SplitMode.payerOnly => tr('splitPayer'),
      SplitMode.custom => tr('splitShares'),
      SplitMode.none => '',
    };

/// Что видно про чужой сюрприз: сумма, счёт и когда он раскроется.
String _revealNote(Transaction op) {
  final reveal = (op.revealAt ?? '').trim();
  // Кто скрыл — говорит бейдж под строкой, поэтому здесь про это молчим.
  if (reveal.isEmpty) return trf('hiddenDetails', [op.account]);
  final day = DateTime.tryParse(reveal);
  if (day == null) return trf('opensLater', [op.account]);
  final date = '${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  return trf('opensOn', [op.account, date]);
}

/// Строка операции. Слева метка категории, справа сумма: в базовой валюте и,
/// если операция была в другой, её родная сумма под ней — иначе непонятно,
/// откуда взялось число.
class OperationRow extends StatelessWidget {
  final Store store;
  final Transaction op;
  final VoidCallback onTap;

  /// Логотипы банков по пакету приложения. Пусто — на месте знака банка
  /// останется обычный значок счёта.
  final Map<String, Uint8List> logos;

  /// Удержание включает выбор пачкой. Пусто — лента работает как раньше.
  final VoidCallback? onLongPress;

  /// Идёт ли выбор прямо сейчас и выбрана ли ЭТА строка. В режиме выбора
  /// короткое касание берёт запись в пачку, а не открывает её на правку:
  /// иначе человек, набирающий десяток записей, будет вылетать в форму.
  final bool selecting;
  final bool selected;

  const OperationRow({
    super.key,
    required this.store,
    required this.op,
    required this.onTap,
    this.logos = const {},
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  /// Кто смотрит: от этого зависит подпись «вы» и то, считается ли трата
  /// чужим сюрпризом. Лежит в Store, чтобы не тащить сессию в каждый экран.
  String get _viewer => store.viewer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final base = db.baseCurrency;
    // Скрытая трата партнёра приходит без категории и заметки — это не
    // «без категории», а сюрприз. Человек должен видеть, что от него скрыли
    // суть, а не решить, что запись битая.
    final secretForMe = op.secret && op.author != null && op.author != _viewer;
    final paired = db.pair.members.length > 1;
    final payerUid = op.payer ?? op.author;
    final payer = db.pair.byUid(payerUid);
    // Плательщик известен, только если он есть в паре или это сам смотрящий.
    // Раньше любой незнакомый uid (например, оставшийся от прежнего аккаунта)
    // рисовался бейджем «Партнёр» — и человек искал партнёра, которого нет
    // («у меня нет вообще человека с именем Партнёр», 13.09.2026).
    final knownPayer = payer != null || payerUid == _viewer;
    final talk = store.commentsOf(op.id).length;
    final name = secretForMe
        ? tr('surprise')
        : (op.category ?? '').trim().isEmpty
            ? (op.kind == TxKind.transfer ? tr('transfer') : tr('noCategory'))
            : op.category!;
    final at = db.categories.indexWhere((c) => c.name == name);
    final stored = at >= 0 ? db.categories[at] : null;
    // Цвет строки наследуется от ПОДКАТЕГОРИИ, когда она есть: «Кофе» и
    // «Рынок» внутри продуктов человек различает по цвету, а не по значку
    // (13.09.2026). Без подкатегории берётся цвет категории.
    final sub = (op.subcategory ?? '').trim();
    final subAt = sub.isEmpty
        ? -1
        : db.categories.indexWhere((c) => c.name == sub && c.parent == name);
    final subStored = subAt >= 0 ? db.categories[subAt] : null;
    final color = secretForMe
        ? context.tm.field
        : op.kind == TxKind.transfer
            ? scheme.onSurfaceVariant
            : sub.isNotEmpty
                ? (subStored?.color != null
                    ? Color(subStored!.color!)
                    : labelColorFor(sub))
                : (stored?.color != null ? Color(stored!.color!) : labelColorFor(name));
    final inBase = convert(db, op.amount, op.currency);

    return Material(
      // Выбранная строка подсвечена заливкой во всю ширину: галочка сбоку
      // теряется среди значков категорий, а заливку видно боковым зрением,
      // когда выбираешь десяток подряд.
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      type: selected ? MaterialType.canvas : MaterialType.transparency,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              if (selecting) ...[
                Icon(
                  selected ? Myna.checkCircle : Myna.circle,
                  size: 22,
                  color: selected ? scheme.onSurface : scheme.outline,
                ),
                const SizedBox(width: 10),
              ],
              LabelDot(
                name: name,
                // Значок тоже от подкатегории: цвет и знак должны говорить
                // об одном и том же.
                icon: secretForMe
                    ? Myna.lock
                    : op.kind == TxKind.transfer
                        ? Myna.arrowLeftRight
                        : sub.isNotEmpty
                            ? categoryIcon(sub, stored: subStored?.icon)
                            : categoryIcon(name, stored: stored?.icon),
                color: color,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      op.subcategory == null ? name : '$name · ${op.subcategory}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _AccountMark(account: op.account, store: store, logos: logos),
                        const SizedBox(width: 5),
                        // Запись из банковского уведомления помечена: человек
                        // должен понимать, откуда взялась строка, которую он
                        // сам не вводил.
                        if (fromNotice(op)) ...[
                          Icon(
                            Myna.bellOn,
                            size: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            secretForMe ? _revealNote(op) : _subtitle(op.account, op.note),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Бейдж стоит и у чужого сюрприза: суть скрыта, а чьи это
                    // деньги — нет. В семье из трёх «партнёр скрыл детали»
                    // никого не называет, бейдж называет.
                    if (paired) ...[
                      const SizedBox(height: 5),
                      // Бейдж целый, слово дележа переносится под него: в
                      // тесной колонке строка уезжала за край.
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (knownPayer)
                            MemberBadge(member: payer, isMe: payerUid == _viewer),
                          if (_splitWord(op).isNotEmpty)
                            Text(
                              _splitWord(op),
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          // Заданный вопрос виден из ленты: иначе он лежит
                          // внутри операции, куда никто не заходит.
                          if (talk > 0)
                            _TalkPill(
                              count: talk,
                              onTap: () => showComments(context, store, op),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Сумма прижата к ПРАВОМУ краю. Гибкая колонка делила строку
              // поровну и ставила число в начало своей половины: суммы
              // начинались с одного места и кончались кто где («суммы не
              // прикреплены к правому краю и у всех разное расстояние»,
              // 16.09.2026). `Align` растягивает колонку на свою долю, а доли
              // теперь три к двум в пользу названия — оно длиннее.
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MoneyText(inBase,
                          currency: base, size: 15, colored: true, squeeze: true),
                      if (op.currency != base) ...[
                        const SizedBox(height: 2),
                        MoneyText(
                          op.amount,
                          currency: op.currency,
                          size: 12,
                          weight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                          squeeze: true,
                        ),
                      ],
                    ],
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

/// Чип человека: аватар и имя. Один выбранный — история сужается до его
/// операций, «Все» возвращает общую.
class _PersonChip extends StatelessWidget {
  const _PersonChip({
    this.member,
    this.label,
    this.isMe = false,
    required this.selected,
    required this.onTap,
  });

  final Member? member;
  final String? label;
  final bool isMe;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.fromLTRB(member == null ? 16 : 6, 6, 16, 6),
          child: Center(
            widthFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (member != null) ...[
                MemberBadge(member: member, isMe: isMe, size: 22, showName: false),
                const SizedBox(width: 8),
              ],
              Text(
                // Чип человека подписан ЕГО именем, и своё — тоже имя:
                // «Мои» рядом с «JB SHARAN» читалось как два разных рода
                // подписи.
                label ??
                    (member!.name.trim().isEmpty
                        ? tr('peopleMine')
                        : member!.name),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Пилюля разговора: значок и число сказанного.
class _TalkPill extends StatelessWidget {
  const _TalkPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Myna.chat, size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Знак счёта в строке операции: настоящий логотип банка, если счёт привязан
/// к банковскому приложению, иначе прежний значок по имени счёта.
class _AccountMark extends StatelessWidget {
  const _AccountMark({
    required this.account,
    required this.store,
    required this.logos,
  });

  final String account;
  final Store store;
  final Map<String, Uint8List> logos;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bank = store.view.accounts
        .where((a) => a.name == account)
        .map((a) => a.bank)
        .firstOrNull;
    final logo = bank == null ? null : logos[bank];

    if (logo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          logo,
          width: 14,
          height: 14,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Icon(
            accountIcon(account),
            size: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Icon(accountIcon(account), size: 13, color: scheme.onSurfaceVariant);
  }
}
