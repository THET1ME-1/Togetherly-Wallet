import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import '../logic/period.dart';
import '../design/accents.dart';
import '../logic/money.dart';
import '../widgets/amount_field.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/form_screen.dart';
import '../widgets/segmented.dart';
import '../widgets/settings_kit.dart';
import '../widgets/accounts_pick_sheet.dart';
import '../widgets/entry_kit.dart';
import 'category_multi_screen.dart';
import 'category_pick_screen.dart';

/// Что вышло из формы: сам бюджет и «почему так».
///
/// Примечание — часть ДОГОВОРЁННОСТИ, а не бюджета: в паре человек объясняет
/// партнёру, откуда взялась цифра, и это объяснение живёт рядом с
/// предложением, а не в записи бюджета.
class BudgetDraft {
  const BudgetDraft(this.budget, {this.note = ''});

  final Budget budget;
  final String note;
}

/// Заведение и правка бюджета — ЭКРАН.
///
/// Листом здесь стояла стена из двадцати шести пилюль с категориями, поле
/// лимита и три пилюли периода: «что это за ужас» (13.09.2026). Теперь
/// главное — сумма, категория выбирается своим экраном с поиском, период
/// стоит ровным рядом.
///
/// В ПАРЕ этим же экраном бюджет ПРЕДЛАГАЕТСЯ. Своя форма на экране
/// договорённостей — выпадающий список категорий без поиска, сумма всегда в
/// базовой валюте, ни периода, ни переноса — прожила до 17.09.2026 и была
/// выброшена: «почему выбор Аванс и ниже это попап а не экран, почему нет
/// поиска и почему нельзя свои создавать». Две формы одного и того же
/// расходятся на первой же правке.
Future<BudgetDraft?> editBudget(
  BuildContext context, {
  required Store store,
  Budget? current,
  VoidCallback? onDelete,
  bool propose = false,
}) => Navigator.of(context).push<BudgetDraft>(
  MaterialPageRoute(
    builder: (_) => BudgetEditScreen(
      store: store,
      current: current,
      onDelete: onDelete,
      propose: propose,
    ),
  ),
);

class BudgetEditScreen extends StatefulWidget {
  const BudgetEditScreen({
    super.key,
    required this.store,
    this.current,
    this.onDelete,
    this.propose = false,
  });

  final Store store;
  final Budget? current;

  /// Удаление прямо из формы: долгое нажатие в списке человек не находит.
  final VoidCallback? onDelete;

  /// В паре бюджет не ставится молча: форма спрашивает «почему так» и
  /// отправляет предложение партнёру.
  final bool propose;

  @override
  State<BudgetEditScreen> createState() => _BudgetEditScreenState();
}

class _BudgetEditScreenState extends State<BudgetEditScreen> {
  late String? _category = widget.current?.category;
  late String? _sub = widget.current?.subcategory;
  late final TextEditingController _limit = TextEditingController(
    text: widget.current == null ? '' : formatAmount(widget.current!.limit),
  );
  late BudgetPeriod _period =
      widget.current?.periodKind ?? BudgetPeriod.monthly;
  late bool _rollover = widget.current?.rollover ?? false;
  late String _currency =
      widget.current?.currency ?? widget.store.db.baseCurrency;
  late int _days = widget.current?.days ?? 10;
  late String _start = widget.current?.startDate ?? _today();
  final TextEditingController _note = TextEditingController();
  late final TextEditingController _name = TextEditingController(
    text: widget.current?.name ?? '',
  );
  late String? _icon = widget.current?.icon;
  late Color? _color = widget.current?.color == null
      ? null
      : Color(widget.current!.color!);
  late List<String> _extra = [...?widget.current?.extraCategories];
  late List<String> _accounts = [...?widget.current?.accounts];

  static const _periods = [
    BudgetPeriod.daily,
    BudgetPeriod.weekly,
    BudgetPeriod.monthly,
    BudgetPeriod.custom,
    BudgetPeriod.once,
  ];

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void dispose() {
    _limit.dispose();
    _note.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _category != null && (parseAmount(_limit.text) ?? 0) > 0;

  void _save() {
    final limit = parseAmount(_limit.text) ?? 0;
    if (limit <= 0 || _category == null) return;
    Navigator.of(context).pop(
      BudgetDraft(
        Budget(
          category: _category!,
          subcategory: _sub,
          limit: limit,
          currency: _currency,
          period: budgetPeriodName(_period),
          // Предел без периода не обнуляется, переносить ему нечего и некуда.
          rollover: _period == BudgetPeriod.once ? false : _rollover,
          days: _period == BudgetPeriod.custom ? _days : null,
          startDate:
              _period == BudgetPeriod.daily ||
                  _period == BudgetPeriod.weekly ||
                  _period == BudgetPeriod.monthly
              ? null
              : _start,
        ),
        note: _note.text,
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await pickCategory(
      context,
      store: widget.store,
      category: _category,
      subcategory: _sub,
      expenseOnly: true,
    );
    if (picked == null) return;
    setState(() {
      _category = picked.category;
      _sub = picked.subcategory;
    });
  }

  /// Дата для человека: «1 сентября 2026», а не «2026-09-01».
  String get _startTitle {
    final at = DateTime.tryParse(_start);
    if (at == null) return _start;
    final head = '${at.day} ${monthOf(at.month)}';
    return at.year == DateTime.now().year ? head : '$head ${at.year}';
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('budgetStart'),
      initial: DateTime.tryParse(_start) ?? now,
      firstYear: now.year - 3,
      lastYear: now.year + 3,
    );
    if (picked != null) {
      setState(() => _start = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _pickDays() async {
    final picked = await showNumberWheel(
      context,
      title: tr('budgetDays'),
      initial: _days,
      first: 2,
      last: 365,
      label: (n) => trf('budgetDaysValue', ['$n']),
    );
    if (picked != null) setState(() => _days = picked);
  }

  @override
  Widget build(BuildContext context) {
    final name = _category == null
        ? tr('categoryPickNone')
        : (_sub == null ? _category! : '$_category · $_sub');

    return FormScreen(
      title: widget.propose
          ? tr('budgetPropose')
          : (widget.current == null ? tr('budgetNew') : tr('budgetOne')),
      action: widget.propose ? tr('budgetProposeAction') : tr('budgetSave'),
      onAction: _ready ? _save : null,
      danger: widget.onDelete == null ? null : tr('budgetRemove'),
      onDanger: widget.onDelete == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
      children: [
        AmountField(
          controller: _limit,
          currency: _currency,
          onChanged: (_) => setState(() {}),
          onCurrency: () async {
            final picked = await askCurrency(
              context,
              store: widget.store,
              current: _currency,
            );
            if (picked != null) setState(() => _currency = picked);
          },
        ),
        const SizedBox(height: 6),

        SettingsSection(tr('budgetName'), icon: Myna.tag),
        SettingsGroup([
          SettingsBlock(
            child: EntryIdentity(
              name: _name,
              icon: _icon,
              color: _color,
              hint: _category ?? tr('budgetNameHint'),
              onChanged: (_) => setState(() {}),
              onIcon: (v) => setState(() => _icon = v),
              onColor: (v) => setState(() => _color = v),
            ),
          ),
        ]),

        SettingsSection(tr('budgetCategoriesTitle'), icon: Myna.tag),
        SettingsGroup([
          SettingsRow(
            // Значок и цвет выбранной категории прямо в строке: человек
            // узнаёт её так же, как в ленте и на кварталах.
            icon: categoryIcon(_category ?? ''),
            iconBg: _category == null ? null : labelColorFor(_category!),
            iconFg: _category == null ? null : inkOn(labelColorFor(_category!)),
            title: name,
            subtitle: _category == null ? tr('budgetPickHint') : null,
            trailing: const SettingsChevron(),
            onTap: _pick,
          ),
          // Бюджет на машину — это бензин, мойка и страховка вместе: по
          // отдельности их никто не планирует.
          SettingsRow(
            icon: Myna.layersTwo,
            title: tr('budgetCategoriesMoreTitle'),
            subtitle: _extra.isEmpty
                ? tr('budgetCategoriesNone')
                : _extra.join(', '),
            trailing: const SettingsChevron(),
            onTap: () async {
              final picked = await pickCategories(
                context,
                store: widget.store,
                chosen: _extra,
              );
              if (picked != null) setState(() => _extra = picked);
            },
          ),
          SettingsRow(
            icon: Myna.creditCard,
            title: tr('budgetAccounts'),
            subtitle: _accounts.isEmpty
                ? tr('budgetAllAccounts')
                : _accounts.join(', '),
            trailing: const SettingsChevron(),
            onTap: () async {
              final picked = await pickAccounts(
                context,
                store: widget.store,
                chosen: _accounts,
              );
              if (picked != null) setState(() => _accounts = picked);
            },
          ),
        ]),

        SettingsSection(tr('budgetPeriodTitle'), icon: Myna.calendar),
        SettingsGroup([
          SettingsBlock(
            child: Segmented(
              titles: [for (final p in _periods) _periodName(p)],
              index: _periods.indexOf(_period),
              onPick: (i) => setState(() => _period = _periods[i]),
            ),
          ),
          // Длина своего отрезка: «каждые десять дней» не выражается ни
          // неделей, ни месяцем.
          if (_period == BudgetPeriod.custom)
            SettingsRow(
              icon: Myna.clockCircle,
              title: tr('budgetDays'),
              subtitle: trf('budgetDaysValue', ['$_days']),
              trailing: const SettingsChevron(),
              onTap: _pickDays,
            ),
          if (_period == BudgetPeriod.custom || _period == BudgetPeriod.once)
            SettingsRow(
              icon: Myna.calendarCheck,
              title: tr('budgetStart'),
              subtitle: _period == BudgetPeriod.once
                  ? tr('budgetOnceNote')
                  : null,
              trailing: Text(
                _startTitle,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: _pickStart,
            ),
          if (_period != BudgetPeriod.once)
            SettingsRow(
              icon: Myna.refresh,
              title: tr('budgetCarry'),
              subtitle: trf('budgetCarryNote', [_periodWord(_period)]),
              trailing: Switch(
                value: _rollover,
                onChanged: (v) => setState(() => _rollover = v),
              ),
            ),
        ]),

        // «Почему так» спрашивается только в паре: партнёру отвечать на голую
        // цифру нечем, а с объяснением разговор о деньгах занимает минуту.
        if (widget.propose) ...[
          SettingsSection(tr('budgetWhySo'), icon: Myna.message),
          SettingsGroup([
            SettingsInput(controller: _note, hint: tr('budgetWhySoHint')),
          ]),
        ],
      ],
    );
  }
}

String _periodName(BudgetPeriod p) => switch (p) {
  BudgetPeriod.daily => tr('periodDay'),
  BudgetPeriod.weekly => tr('periodWeek'),
  BudgetPeriod.monthly => tr('periodMonth'),
  BudgetPeriod.custom => tr('periodCustom'),
  BudgetPeriod.once => tr('periodOnce'),
};

String _periodWord(BudgetPeriod p) => switch (p) {
  BudgetPeriod.daily => tr('periodNextDay'),
  BudgetPeriod.weekly => tr('periodNextWeek'),
  BudgetPeriod.monthly => tr('periodNextMonth'),
  BudgetPeriod.custom => tr('periodNextCustom'),
  BudgetPeriod.once => '',
};
