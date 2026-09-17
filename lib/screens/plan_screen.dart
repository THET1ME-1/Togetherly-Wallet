import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../widgets/amount_field.dart';
import '../widgets/date_wheel_sheet.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../logic/period.dart';
import '../logic/plan.dart';
import '../logic/plus.dart';
import '../services/plus.dart';
import '../widgets/app_sheet.dart';
import '../widgets/plus_gate.dart';
import 'category_pick_screen.dart';
import '../widgets/money_text.dart';
import '../widgets/reveal.dart';
import '../design/myna.dart';

/// План на месяц: у каждого рубля есть работа.
///
/// Бюджет с нулевым балансом: доход раскладывается по категориям, целям и
/// долгам, пока нераспределённого не останется ноль. Рядом с планом стоит
/// факт — в конце месяца видно не «много ли потратили», а сошлось ли с тем, о
/// чём договаривались.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.store, this.plus});

  final Store store;

  /// Подписка. Пусто — не запираем: так экран поднимается в тестах и у
  /// одиночки без аккаунта.
  final PlusService? plus;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  /// Уехать на другой месяц.
  ///
  /// Вперёд — платное: план на будущее это и есть планирование, за него и
  /// берутся деньги. Назад и на текущий — бесплатно ВСЕГДА: прошлые месяцы
  /// это история человека, а запирать собственные записи значит держать их в
  /// заложниках.
  Future<void> _goMonth(BuildContext context, DateTime next) async {
    final now = DateTime.now();
    final ahead = next.isAfter(DateTime(now.year, now.month));
    if (ahead &&
        !await askPlus(context, plus: widget.plus, gate: PlusGate.planAhead)) {
      return;
    }
    if (!mounted) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final db = widget.store.db;
        final plan = planOf(db, _month);
            // Раскладывать по правилу можно только когда есть что и из чего:
        // доход месяца и хоть какая-то история трат. У нового человека нет ни
        // того, ни другого, и кнопка предлагала ему план из ниоткуда.
        final canDistribute =
            plan.income > 0 && draftPlan(db, _month).isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('planTitle')),
            actions: [
              if (!plan.isEmpty)
                IconButton(
                  onPressed: () => _clearMonth(context),
                  icon: const Icon(Myna.trash),
                  tooltip: tr('planClear'),
                ),
              const SizedBox(width: 4),
            ],
          ),
          // Строку плана можно завести руками: раньше план был только тем, что
          // разложило правило, и своей строки в нём не появлялось никак
          // («их нельзя создать», 13.09.2026).
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addRow(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('planRowNew')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
            children: [
              _MonthBar(
                month: _month,
                onChange: (v) => _goMonth(context, v),
              ),
              const SizedBox(height: 12),
              // Плана НЕТ — экран пустой. Ни разбора дохода по правилу, ни
              // трат месяца строками: всё это выглядело готовым планом,
              // которого человек не заводил и не мог убрать.
              if (plan.isEmpty)
                _Empty(
                  onAdd: () => _addRow(context),
                  onDistribute: canDistribute ? () => _distribute(context) : null,
                )
              else ...[
                Reveal(
                  child: _BalanceCard(
                    plan: plan,
                    currency: db.baseCurrency,
                    onDistribute:
                        canDistribute ? () => _distribute(context) : null,
                  ),
                ),
                SizedBox(height: 12),
                ...[
                  for (var i = 0; i < plan.rows.length; i++)
                    Reveal(
                      delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                      child: _PlanRowCard(
                        row: plan.rows[i],
                        currency: db.baseCurrency,
                        onTap: () => _editRow(context, plan.rows[i]),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  String _ruleLine(Rules r) =>
      '${(r.needsBp / 100).round()}/${(r.wantsBp / 100).round()}/${(r.savingsBp / 100).round()}';

  Future<void> _distribute(BuildContext context) async {
    final draft = draftPlan(widget.store.db, _month);
    if (draft.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('planNeedIncome')),
        ),
      );
      return;
    }
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.sparkles,
        title: tr('planAllocateTitle'),
        text: trf('planAllocateText', [
          _ruleLine(widget.store.db.rules),
          draft.length,
        ]),
        action: tr('planAllocate'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) widget.store.setPlanForMonth(monthKey(_month), draft);
  }

  Future<void> _editRow(BuildContext context, PlanRow row) async {
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _AmountSheet(
        title: row.name,
        note: trf('planActualMonth', [formatMoney(row.actual, widget.store.db.baseCurrency)]),
        value: row.planned,
        currency: widget.store.db.baseCurrency,
        // Ноль и есть удаление, но искать это самому человек не обязан:
        // строка «Убрать из плана» говорит прямо.
        removable: row.planned > 0,
      ),
    );
    if (value == null) return;
    widget.store.setPlanItem(PlanItem(
      month: monthKey(_month),
      kind: row.kind,
      name: row.name,
      amount: value,
    ));
  }

  /// Своя строка плана: категория, цель или долг.
  Future<void> _addRow(BuildContext context) async {
    final db = widget.store.db;
    final kind = await showMoneySheet<PlanItemKind>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.plus,
        title: tr('planRowNew'),
        text: tr('planRowWhat'),
        action: tr('categoryPickTitle'),
        onAction: () => Navigator.of(context).pop(PlanItemKind.category),
        child: Column(children: [
          if (db.goals.isNotEmpty)
            _PickLine(
              icon: Myna.flag,
              title: tr('goalsTitle'),
              onTap: () => Navigator.of(context).pop(PlanItemKind.goal),
            ),
          if (db.debts.isNotEmpty)
            _PickLine(
              icon: Myna.ticket,
              title: tr('debtsTitle'),
              onTap: () => Navigator.of(context).pop(PlanItemKind.debt),
            ),
        ]),
      ),
    );
    if (kind == null || !context.mounted) return;

    String? name;
    switch (kind) {
      case PlanItemKind.category:
        final picked = await pickCategory(context, store: widget.store);
        name = picked?.subcategory ?? picked?.category;
      case PlanItemKind.goal:
        name = await _choose(context, tr('goalsTitle'),
            db.goals.map((g) => g.name).toList());
      case PlanItemKind.debt:
        name = await _choose(context, tr('debtsTitle'),
            db.debts.map((d) => d.name).toList());
    }
    if (name == null || !context.mounted) return;

    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _AmountSheet(
        title: name!,
        note: trf('planPlannedField', [db.baseCurrency]),
        value: 0,
        currency: db.baseCurrency,
      ),
    );
    if (value == null || value <= 0) return;
    widget.store.setPlanItem(PlanItem(
      month: monthKey(_month),
      kind: kind,
      name: name,
      amount: value,
    ));
  }

  /// Выбор из короткого списка: цели и долги, их у пары единицы.
  Future<String?> _choose(
    BuildContext context,
    String title,
    List<String> options,
  ) =>
      showMoneySheet<String>(
        context,
        builder: (context) => SheetScaffold(
          icon: Myna.list,
          title: title,
          text: '',
          action: tr('cancel'),
          onAction: () => Navigator.of(context).pop(),
          child: Column(children: [
            for (final name in options)
              _PickLine(
                icon: Myna.chevronRight,
                title: name,
                onTap: () => Navigator.of(context).pop(name),
              ),
          ]),
        ),
      );

  /// Убрать весь план месяца. Записи и траты это не трогает — исчезают только
  /// плановые суммы.
  Future<void> _clearMonth(BuildContext context) async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.trash,
        tone: Theme.of(context).colorScheme.error,
        title: tr('planClear'),
        text: tr('planClearText'),
        action: tr('planClear'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) {
      widget.store.setPlanForMonth(monthKey(_month), const []);
    }
  }
}

/// Строка выбора в листе: цель, долг или раздел.
class _PickLine extends StatelessWidget {
  const _PickLine({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
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
            ]),
          ),
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, required this.onChange});

  final DateTime month;
  final ValueChanged<DateTime> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      IconButton(
        onPressed: () => onChange(DateTime(month.year, month.month - 1)),
        icon: const Icon(Myna.chevronLeft),
      ),
      // Слово месяца — кнопка: листать стрелками на год назад это двенадцать
      // нажатий, а барабан доезжает одним движением.
      Expanded(
        child: InkWell(
          onTap: () async {
            final picked = await showMonthWheel(
              context,
              title: tr('wheelMonth'),
              initial: month,
            );
            if (picked != null) onChange(DateTime(picked.year, picked.month));
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    Period.month(month).label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontSize: 17,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Myna.chevronDown, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
      IconButton(
        onPressed: () => onChange(DateTime(month.year, month.month + 1)),
        icon: const Icon(Myna.chevronRight),
      ),
    ]);
  }
}

/// Нераспределённое — главное число этого экрана.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.plan,
    required this.currency,
    this.onDistribute,
  });

  final MonthPlan plan;
  final String currency;

  /// Пусто — раскладывать не из чего, и кнопки в карточке нет.
  final VoidCallback? onDistribute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = plan.unassigned;
    final color = plan.balanced
        ? Money.up(context)
        : left < 0
            ? Money.down(context)
            : scheme.onSurface;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          plan.balanced
              ? tr('planAllDone')
              : left > 0
                  ? tr('planLeftToPlan')
                  : tr('planOverIncome'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6),
        MoneyText(left, currency: currency, size: 30, weight: FontWeight.w800, color: color),
        SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _Cell(title: tr('planIncome'), value: plan.income, currency: currency),
          _Cell(title: tr('planPlanned'), value: plan.planned, currency: currency),
          _Cell(title: tr('planActual'), value: plan.actual, currency: currency),
        ]),
        // Кнопка раскладки стоит ОДНА и только когда есть что раскладывать:
        // «зачем автоматические планы у новых пользователей, у них даже
        // записей нет» (13.09.2026).
        if (onDistribute != null) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onDistribute,
            icon: const Icon(Myna.sparkles, size: 18),
            label: Text(tr('planAllocateByRule')),
          ),
        ),
        ],
      ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.title, required this.value, required this.currency});

  final String title;
  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        title,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 11.5,
          color: scheme.onSurfaceVariant,
        ),
      ),
      MoneyText(value, currency: currency, size: 14, weight: FontWeight.w700),
    ]);
  }
}

/// Три доли: сколько по правилу и сколько вышло.
class _PlanRowCard extends StatelessWidget {
  const _PlanRowCard({required this.row, required this.currency, required this.onTap});

  final PlanRow row;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (row.kind) {
      PlanItemKind.goal => Myna.flag,
      PlanItemKind.debt => Myna.creditCard,
      PlanItemKind.category => categoryIcon(row.name),
    };
    final unplanned = row.planned <= 0.005;
    // Превышение плана — плохо только в тратах. Отложить в цель или заплатить
    // по долгу больше запланированного — это успех, и красным он выглядел бы
    // выговором за хорошее.
    final spending = row.kind == PlanItemKind.category;
    final bad = row.over && spending;
    final good = row.over && !spending;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LabelDot(name: row.name, icon: icon, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                MoneyText(row.actual, currency: currency, size: 15, weight: FontWeight.w700),
              ]),
              SizedBox(height: 10),
              if (unplanned)
                Text(
                  spending ? tr('planNotInPlan') : tr('planNotInPlanGood'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: spending ? Money.down(context) : Money.up(context),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: row.share,
                    minHeight: 7,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      bad
                          ? Money.down(context)
                          : good
                              ? Money.up(context)
                              : labelColorFor(row.name),
                    ),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  bad
                      ? trf('planOverRow', [formatMoney(-row.left, currency)]) +
                          trf('goalOfTarget', [formatAmount(row.planned)])
                      : good
                          ? trf('planMoreThanPlan', [formatMoney(-row.left, currency)]) +
                              trf('planPlannedInline', [formatAmount(row.planned)])
                          : '${trf('planPlannedAmount', [
                                formatAmount(row.planned)
                              ])}'
                              '${spending ? tr('planLeftRow') : tr('planLeftToAdd')} '
                              '${formatAmount(row.left)}',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    color: bad
                        ? Money.down(context)
                        : good
                            ? Money.up(context)
                            : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd, this.onDistribute});

  final VoidCallback onAdd;

  /// Пусто — раскладывать не из чего: ни дохода за месяц, ни истории трат.
  final VoidCallback? onDistribute;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: [
        Icon(Myna.clipboard, size: 40, color: scheme.onSurfaceVariant),
        SizedBox(height: 12),
        Text(
          tr('planEmpty'),
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 18,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr('planEmptyHow'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Myna.plus, size: 18),
          label: Text(tr('planRowNew')),
        ),
        if (onDistribute != null)
          TextButton.icon(
            onPressed: onDistribute,
            icon: const Icon(Myna.sparkles, size: 18),
            label: Text(tr('planAllocateByRule')),
          ),
      ]),
    );
  }
}

/// Ввод одной суммы: план на строку.
class _AmountSheet extends StatefulWidget {
  const _AmountSheet({
    required this.title,
    required this.note,
    required this.value,
    required this.currency,
    this.removable = false,
  });

  final String title;
  final String note;
  final double value;
  final String currency;

  /// Показывать «Убрать из плана».
  final bool removable;

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.value > 0 ? formatAmount(widget.value) : '');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: AppTheme.displayFont, fontSize: 20, color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          widget.note,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // Валюта видна в самом поле: `labelText` тема не показывает.
        AmountField(
          controller: _amount,
          currency: widget.currency,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(parseAmount(_amount.text) ?? 0),
            child: Text(tr('planSave')),
          ),
        ),
        if (widget.removable)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0.0),
            child: Text(
              tr('planRowRemove'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontWeight: FontWeight.w600,
                color: scheme.error,
              ),
            ),
          ),
      ]),
    );
  }
}
