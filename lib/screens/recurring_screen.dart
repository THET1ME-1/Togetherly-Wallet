import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'recurring_edit_screen.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/recurring.dart';
import '../widgets/app_sheet.dart';
import '../logic/plus.dart';
import '../widgets/plus_meter.dart';
import '../logic/plus_usage.dart';
import '../services/plus.dart';
import '../widgets/plus_gate.dart';
import '../widgets/money_text.dart';
import '../widgets/reveal.dart';
import '../design/myna.dart';
import '../design/myna_search.dart';

/// Регулярное: обязательные платежи, доходы и «заплати себе первым».
///
/// Взнос в цель, который срабатывает сам сразу после дохода, — единственный
/// способ откладывать не из того, что осталось к концу месяца. Обе статьи про
/// семейный бюджет называют это правилом номер один.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key, required this.store, this.plus});

  final Store store;

  /// Подписка: потолок бесплатной версии считается только при создании
  /// НОВОЙ записи. Заведённые раньше остаются все до одной — отбирать
  /// выданное нельзя.
  final PlusService? plus;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final db = store.db;
        final items = [...db.recurring]
          ..sort((a, b) {
            if (a.active != b.active) return a.active ? -1 : 1;
            return a.nextDate.compareTo(b.nextDate);
          });
        final due = dueOn(db).length;

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('recurringTitle')),
            // Счёт до потолка точками: человек видит, сколько у него осталось,
            // ЗАРАНЕЕ — а не в тот момент, когда его не пустили. У подписчика
            // точек нет вовсе.
            actions: [
              PlusMeter(
                gate: PlusGate.recurring,
                count: plusCount(PlusGate.recurring,
                    plus: plus?.active ?? true, db: db),
                plus: plus,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('recurringOne')),
          ),
          body: items.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    _Summary(store: store, due: due),
                    const SizedBox(height: 12),
                    for (var i = 0; i < items.length; i++)
                      Reveal(
                        delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                        child: _Card(
                          store: store,
                          item: items[i],
                          onEdit: () => _edit(context, items[i]),
                          onDelete: () => _delete(context, items[i]),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(42),
            ),
            child: Icon(Myna.refresh, size: 62, color: scheme.onSurface),
          ),
          SizedBox(height: 26),
          Text(
            tr('recurringEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: 10),
          Text(
            tr('recurringEmptyHow'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [Recurring? current]) async {
    // Потолок считается ТОЛЬКО для новой записи: правка существующей идёт
    // мимо калитки, даже когда их больше бесплатного числа.
    if (current == null &&
        !await allowMore(context, plus: plus, gate: PlusGate.recurring, have: store.db.recurring.length)) {
      return;
    }
    if (!context.mounted) return;
    final next = await editRecurring(
      context,
      store: store,
      current: current,
      onDelete: current == null ? null : () => _delete(context, current),
    );
    if (next != null) store.saveRecurring(next);
  }

  Future<void> _delete(BuildContext context, Recurring item) async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.repeat,
        tone: Theme.of(context).colorScheme.error,
        title: trf('recurringRemoveTitle', [item.name]),
        text: tr('recurringRemoveText'),
        action: tr('recurringRemove'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) store.deleteRecurring(item.id);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.store, required this.due});

  final Store store;
  final int due;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.db;
    final out = monthlyOf(db, RecurringKind.expense);
    final into = monthlyOf(db, RecurringKind.goal) + monthlyOf(db, RecurringKind.debt);

    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          tr('recurringMonthly'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6),
        MoneyText(out + into, currency: db.baseCurrency, size: 28, weight: FontWeight.w800),
        SizedBox(height: 10),
        Text(
          trf('recurringOutSummary', [formatMoney(out, db.baseCurrency)]) +
          trf('recurringIntoSummary', [formatMoney(into, db.baseCurrency)]),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
        if (due > 0) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Myna.clockCircle, size: 18, color: scheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                trf('recurringDueOnOpen', [due]),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.primary,
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.store,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Store store;
  final Recurring item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final income = item.kindOf == RecurringKind.income;
    // Свой знак сильнее подобранного по виду: человек выбрал его сам.
    final icon = item.icon != null
        ? (mynaByName[item.icon!] ?? categoryIcon(item.name))
        : switch (item.kindOf) {
            RecurringKind.goal => Myna.box,
            RecurringKind.debt => Myna.creditCard,
            RecurringKind.income => Myna.arrowDown,
            RecurringKind.expense => categoryIcon(item.category ?? item.name),
          };

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
          onTap: onEdit,
          onLongPress: onDelete,
          child: Opacity(
            opacity: item.active ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                LabelDot(
                  name: item.name,
                  icon: icon,
                  color: item.color == null ? null : Color(item.color!),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      item.name,
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
                    Text(
                      [
                        recurringKindTitle(item.kindOf),
                        if (item.target.isNotEmpty) '«${item.target}»',
                        // «каждый месяц» не пишем: это умолчание, а строка и
                        // без него не влезала в две строки.
                        if (item.every != RecurringEvery.monthly)
                          everyTitle(item.every, days: item.days),
                        if (item.active) _shortDate(item.nextDate) else tr('recurringOff'),
                      ].join(' · '),
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                MoneyText(
                  income ? item.amount : -item.amount,
                  currency: item.currency,
                  size: 15,
                  weight: FontWeight.w700,
                  colored: true,
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// «06.10» вместо «2026-10-06»: в строке важен день, а год человек знает.
String _shortDate(String iso) {
  final at = DateTime.tryParse(iso);
  if (at == null) return iso;
  final now = DateTime.now();
  final head = '${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}';
  return at.year == now.year ? head : '$head.${at.year}';
}

