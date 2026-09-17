import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/money.dart';
import '../logic/notice_match.dart';
import '../logic/notice_rules.dart';
import '../logic/plus.dart';
import '../services/plus.dart';
import '../widgets/app_sheet.dart';
import '../widgets/form_screen.dart';
import '../widgets/money_text.dart';
import '../widgets/pick_row.dart';
import '../widgets/plus_gate.dart';
import '../widgets/settings_kit.dart';
import 'category_pick_screen.dart';

/// Свои правила разбора списаний.
///
/// Движок правил (`logic/notice_rules.dart`) был написан и покрыт тестами
/// задолго до этого экрана, а завести правило человек не мог ничем: витрина
/// обещала функцию платной, в приложении её не существовало вовсе
/// (найдено 17.09.2026).
///
/// Правило человек узнаёт ВЗГЛЯДОМ: в строке стоит условие словами («Wolt ·
/// пн, вт, ср, чт, пт») и действие («Записать молча»). Открывать правило,
/// чтобы вспомнить, что оно делает, — плохой список.
class NoticeRulesScreen extends StatelessWidget {
  const NoticeRulesScreen({super.key, required this.store, this.plus});

  final Store store;
  final PlusService? plus;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final rules = store.noticeRules;
        return Scaffold(
          appBar: AppBar(title: Text(tr('nruleTitle'))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('nruleNew')),
          ),
          body: rules.isEmpty
              ? _Empty(onAdd: () => _edit(context))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
                  children: [
                    SettingsSection(tr('nruleSection'), icon: Myna.filter),
                    // Подпись про порядок стоит НАД списком: приоритет здесь
                    // не догадка приложения, а решение человека, и он должен
                    // знать об этом до того, как заведёт второе правило.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                      child: Text(
                        tr('nruleOrder'),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SettingsGroup([
                      for (final rule in rules)
                        _RuleRow(
                          store: store,
                          rule: rule,
                          onTap: () => _edit(context, rule),
                        ),
                    ]),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, [NoticeRule? current]) async {
    // Калитка стоит только на НОВОМ правиле: у человека, чья подписка
    // кончилась, свои правила остаются — он их не заведёт заново, но и не
    // потеряет написанное. Отобрать выданное нельзя.
    if (current == null &&
        !await askPlus(context, plus: plus, gate: PlusGate.noticeRules)) {
      return;
    }
    if (!context.mounted) return;
    final next = await Navigator.of(context).push<NoticeRule>(
      MaterialPageRoute(
        builder: (_) => RuleEditScreen(store: store, current: current),
      ),
    );
    if (next != null) store.saveNoticeRule(next);
  }
}

/// Строка правила: условие, действие и переключатель.
class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.store, required this.rule, required this.onTap});

  final Store store;
  final NoticeRule rule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final when = ruleWhenParts(
      rule.when,
      senderTitle: senderTitle,
      money: (v) => formatMoney(v, store.db.baseCurrency),
      weekdayNames: [for (var d = 1; d <= 7; d++) tr('weekday$d')],
      anyLabel: tr('nruleAny'),
      fromLabel: tr('nruleFrom'),
      toLabel: tr('nruleTo'),
      cardLabel: tr('nruleCardShort'),
      incomeLabel: tr('nruleIncomeShort'),
      expenseLabel: tr('nruleExpenseShort'),
    );
    // Выключенное правило говорит об этом ПЕРВЫМ словом: иначе человек ищет,
    // почему «Wolt по будням» не срабатывает, а причина в переключателе.
    final act = [
      if (!rule.on) tr('nruleOff'),
      ruleActTitle(rule.act),
      if ((rule.category ?? '').isNotEmpty) rule.category!,
      if ((rule.account ?? '').isNotEmpty) rule.account!,
    ].join(' · ');

    return SettingsRow(
      icon: ruleActIcon(rule.act),
      title: when.join(' · '),
      subtitle: act,
      iconFg: rule.on ? null : scheme.onSurfaceVariant,
      titleColor: rule.on ? null : scheme.onSurfaceVariant,
      onTap: onTap,
      trailing: Switch(
        value: rule.on,
        onChanged: (v) => store.saveNoticeRule(rule.copyWith(on: v)),
      ),
    );
  }
}

/// Знак действия: правило узнаётся по нему раньше, чем прочитано.
IconData ruleActIcon(NoticeDo act) => switch (act) {
      NoticeDo.record => Myna.lightning,
      NoticeDo.ask => Myna.questionCircle,
      NoticeDo.skip => Myna.ban,
    };

String ruleActTitle(NoticeDo act) => switch (act) {
      NoticeDo.record => tr('nruleDoRecord'),
      NoticeDo.ask => tr('nruleDoAsk'),
      NoticeDo.skip => tr('nruleDoSkip'),
    };

String ruleActNote(NoticeDo act) => switch (act) {
      NoticeDo.record => tr('nruleDoRecordNote'),
      NoticeDo.ask => tr('nruleDoAskNote'),
      NoticeDo.skip => tr('nruleDoSkipNote'),
    };

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Myna.filter, size: 26, color: scheme.onSurface),
            ),
            const SizedBox(height: 14),
            Text(
              tr('nruleEmptyTitle'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 21,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('nruleEmptyText'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Правка правила.
///
/// Экран, а не нижний лист: полей здесь два десятка, и лист во весь экран это
/// просто экран, которому мешает ручка сверху (правило проекта от 13.09.2026).
class RuleEditScreen extends StatefulWidget {
  const RuleEditScreen({super.key, required this.store, this.current});

  final Store store;
  final NoticeRule? current;

  @override
  State<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends State<RuleEditScreen> {
  late final _merchant = TextEditingController(
      text: widget.current?.when.merchant ?? '');
  late final _last4 =
      TextEditingController(text: widget.current?.when.last4 ?? '');
  late final _min = TextEditingController(
      text: widget.current?.when.min == null
          ? ''
          : formatAmount(widget.current!.when.min!));
  late final _max = TextEditingController(
      text: widget.current?.when.max == null
          ? ''
          : formatAmount(widget.current!.when.max!));
  late final _note = TextEditingController(text: widget.current?.note ?? '');

  late final Set<int> _days = {...?widget.current?.when.weekdays};
  late bool? _income = widget.current?.when.income;
  late NoticeDo _act = widget.current?.act ?? NoticeDo.ask;
  late String? _category = widget.current?.category;
  late String? _subcategory = widget.current?.subcategory;
  late String? _account = widget.current?.account;
  late SplitMode? _split = widget.current?.split;

  /// Чего не хватает. Пусто — правило можно сохранять.
  String _problem = '';

  @override
  void dispose() {
    _merchant.dispose();
    _last4.dispose();
    _min.dispose();
    _max.dispose();
    _note.dispose();
    super.dispose();
  }

  NoticeWhen get _when => NoticeWhen(
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        last4: _last4.text.trim().isEmpty ? null : _last4.text.trim(),
        min: parseAmount(_min.text),
        max: parseAmount(_max.text),
        weekdays: _days.length == 7 ? const {} : _days,
        income: _income,
      );

  void _save() {
    final when = _when;
    // Пустое условие подошло бы к ЛЮБОМУ списанию и съело бы все остальные
    // правила: `ruleFor` такие пропускает, и заводить их нельзя.
    if (when.isEmpty) {
      setState(() => _problem = tr('nruleNeedWhen'));
      return;
    }
    Navigator.of(context).pop(
      NoticeRule(
        id: widget.current?.id ??
            'rule-${DateTime.now().millisecondsSinceEpoch}',
        when: when,
        act: _act,
        category: _category,
        subcategory: _subcategory,
        account: _account,
        split: _split,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        on: widget.current?.on ?? true,
      ),
    );
  }

  Future<void> _remove() async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.trash,
        tone: Theme.of(context).colorScheme.error,
        title: tr('nruleRemove'),
        text: tr('nruleEmptyText'),
        action: tr('nruleRemove'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !mounted) return;
    widget.store.removeNoticeRule(widget.current!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final currency = db.baseCurrency;

    return FormScreen(
      title: tr('nruleEditTitle'),
      action: tr('nruleSave'),
      onAction: _save,
      danger: widget.current == null ? null : tr('nruleRemove'),
      onDanger: widget.current == null ? null : _remove,
      children: [
        SettingsSection(tr('nruleWhen'), icon: Myna.filter),
        SettingsGroup([
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(tr('nruleMerchant')),
                SettingsInput(
                  controller: _merchant,
                  hint: tr('nruleMerchantHint'),
                  onChanged: (_) => _clearProblem(),
                ),
              ],
            ),
          ),
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('${tr('nruleAmount')}, $currency'),
                Row(children: [
                  Expanded(
                    child: SettingsInput(
                      controller: _min,
                      hint: tr('nruleMin'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _clearProblem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SettingsInput(
                      controller: _max,
                      hint: tr('nruleMax'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => _clearProblem(),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(tr('nruleSide')),
                // Ряд с прокруткой, а не столбик: правило проекта, и на
                // 320 dp три пилюли в `Wrap` рвались на две строки.
                PickRow(children: [
                  ChoiceChip(
                      label: Text(tr('nruleSideAny')),
                      selected: _income == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _income = null),
                    ),
                  ChoiceChip(
                      label: Text(tr('nruleExpenseShort')),
                      selected: _income == false,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _income = false),
                    ),
                  ChoiceChip(
                      label: Text(tr('nruleIncomeShort')),
                      selected: _income == true,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _income = true),
                    ),
                ]),
              ],
            ),
          ),
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(tr('nruleDays')),
                PickRow(
                  height: 40,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      ChoiceChip(
                        // Короткое имя дня берётся СВОИМ ключом, а не
                        // обрезкой длинного: «Четверг» по двум буквам даёт
                        // «Че», а «Суббота» — «Су».
                        label: Text(tr('weekdayShort$d')),
                        selected: _days.contains(d),
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          _days.contains(d) ? _days.remove(d) : _days.add(d);
                          _clearProblem();
                        }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label(tr('nruleCard')),
                SettingsInput(
                  controller: _last4,
                  hint: tr('nruleCardHint'),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  onChanged: (_) => _clearProblem(),
                ),
              ],
            ),
          ),
        ]),
        if (_problem.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              _problem,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                color: scheme.error,
              ),
            ),
          ),
        const SizedBox(height: 16),
        SettingsSection(tr('nruleDo'), icon: Myna.lightning),
        SettingsGroup([
          for (final act in NoticeDo.values)
            SettingsRow(
              icon: ruleActIcon(act),
              title: ruleActTitle(act),
              subtitle: ruleActNote(act),
              trailing: _act == act
                  ? Icon(Myna.checkCircle, size: 20, color: scheme.onSurface)
                  : null,
              onTap: () => setState(() => _act = act),
            ),
        ]),
        // Заполнять поля у пропущенного списания нечего: записи не будет.
        if (_act != NoticeDo.skip) ...[
          const SizedBox(height: 16),
          SettingsSection(tr('nruleFill'), icon: Myna.edit),
          SettingsGroup([
            SettingsRow(
              icon: Myna.tag,
              title: tr('nruleCategory'),
              subtitle: _categoryLabel(),
              trailing: const SettingsChevron(),
              onTap: _pickCategory,
            ),
            SettingsRow(
              icon: Myna.creditCard,
              title: tr('nruleAccount'),
              subtitle: _account ?? tr('nruleKeep'),
              trailing: const SettingsChevron(),
              onTap: () => _pickAccount(db),
            ),
            if (db.pair.members.length > 1)
              SettingsBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Label(tr('nruleSplit')),
                    PickRow(children: [
                      ChoiceChip(
                      label: Text(tr('nruleKeep')),
                      selected: _split == null,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _split = null),
                    ),
                      ChoiceChip(
                      label: Text(tr('opSplitEqual')),
                      selected: _split == SplitMode.equal,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _split = SplitMode.equal),
                    ),
                      ChoiceChip(
                      label: Text(tr('opSplitNone')),
                      selected: _split == SplitMode.none,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _split = SplitMode.none),
                    ),
                    ]),
                  ],
                ),
              ),
            SettingsBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label(tr('nruleNote')),
                  SettingsInput(controller: _note, hint: tr('nruleKeep')),
                ],
              ),
            ),
          ]),
        ],
      ],
    );
  }

  void _clearProblem() {
    if (_problem.isEmpty) return;
    setState(() => _problem = '');
  }

  String _categoryLabel() {
    if ((_category ?? '').isEmpty) return tr('nruleKeep');
    if ((_subcategory ?? '').isEmpty) return _category!;
    return '$_category · $_subcategory';
  }

  Future<void> _pickCategory() async {
    final picked = await pickCategory(context, store: widget.store);
    if (picked == null || !mounted) return;
    setState(() {
      _category = picked.category;
      _subcategory = picked.subcategory;
    });
  }

  Future<void> _pickAccount(Database db) async {
    // Главная кнопка листа снимает выбор: «как разобралось» — это решение, а
    // не отказ от него, и прятать его в «Отмену» нельзя.
    final picked = await showMoneySheet<String>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.creditCard,
        title: tr('nruleAccount'),
        action: tr('nruleKeep'),
        onAction: () => Navigator.of(context).pop(''),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in db.accounts)
              SettingsRow(
                icon: Myna.creditCard,
                title: a.name,
                trailing: _account == a.name
                    ? Icon(Myna.checkCircle,
                        size: 20, color: Theme.of(context).colorScheme.onSurface)
                    : null,
                onTap: () => Navigator.of(context).pop(a.name),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _account = picked.isEmpty ? null : picked);
  }
}

/// Подпись над полем.
///
/// Строкой НАД полем, а не плавающей меткой Material: заливка и рамка вместе
/// дают перечёркнутую подпись, и в теме плавающие метки выключены совсем.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
