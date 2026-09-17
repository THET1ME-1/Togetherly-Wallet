import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'debt_edit_screen.dart';
import 'debt_pay_screen.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/debts.dart';
import '../logic/money.dart';
import '../widgets/app_sheet.dart';
import '../logic/plus.dart';
import '../widgets/plus_meter.dart';
import '../logic/plus_usage.dart';
import '../services/plus.dart';
import '../widgets/plus_gate.dart';
import '../widgets/money_text.dart';
import '../widgets/reveal.dart';
import '../design/myna.dart';

/// Долги: сколько осталось, в каком порядке гасить и когда это кончится.
///
/// Остаток считается из платежей, а не из числа в записи. Порядок — «лавина»
/// по ставке (дешевле по деньгам) или «снежный ком» по остатку (дешевле по
/// силе воли); оба способа названы в разборах семейного бюджета, выбор за
/// парой.
class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key, required this.store, this.plus});

  final Store store;

  /// Подписка: потолок бесплатной версии считается только при создании
  /// НОВОЙ записи. Заведённые раньше остаются все до одной — отбирать
  /// выданное нельзя.
  final PlusService? plus;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  PayoffOrder _order = PayoffOrder.avalanche;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final db = widget.store.db;
        final plan = payoffPlan(db, order: _order);
        final totals = debtTotals(db);

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('debtsTitle')),
            // Счёт до потолка точками: человек видит, сколько у него осталось,
            // ЗАРАНЕЕ — а не в тот момент, когда его не пустили. У подписчика
            // точек нет вовсе.
            actions: [
              PlusMeter(
                gate: PlusGate.debt,
                count: plusCount(PlusGate.debt,
                    plus: widget.plus?.active ?? true, db: db),
                plus: widget.plus,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('debtOne')),
          ),
          body: plan.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    Reveal(child: _TotalsCard(totals: totals, currency: db.baseCurrency)),
                    const SizedBox(height: 12),
                    _OrderPicker(
                      order: _order,
                      onChange: (v) => setState(() => _order = v),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < plan.length; i++)
                      Reveal(
                        delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                        child: _DebtCard(
                          state: plan[i],
                          first: i == 0 && !plan[i].closed,
                          onEdit: () => _edit(context, plan[i].debt),
                          onDelete: () => _delete(context, plan[i].debt),
                          onPay: () => _pay(context, plan[i]),
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
            child: Icon(Myna.creditCardCheck, size: 62,
                color: scheme.onSurface),
          ),
          SizedBox(height: 26),
          Text(
            tr('debtsEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('debtsEmptyHow'),
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

  Future<void> _edit(BuildContext context, [Debt? current]) async {
    // Потолок считается ТОЛЬКО для новой записи: правка существующей идёт
    // мимо калитки, даже когда их больше бесплатного числа.
    if (current == null &&
        !await allowMore(context, plus: widget.plus, gate: PlusGate.debt, have: widget.store.db.debts.length)) {
      return;
    }
    if (!context.mounted) return;
    final next = await editDebt(
      context,
      store: widget.store,
      current: current,
      onDelete: current == null ? null : () => _delete(context, current),
    );
    if (next != null) widget.store.saveDebt(next);
  }

  Future<void> _delete(BuildContext context, Debt debt) async {
    final st = stateOf(widget.store.db, debt);
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.ticket,
        tone: Theme.of(context).colorScheme.error,
        title: trf('debtRemoveTitle', [debt.name]),
        text: st.paid.abs() < 0.005
            ? tr('debtRemoveEmpty')
            : trf('debtRemovePaid', [formatMoney(st.paid, debt.currency)]),
        action: tr('debtRemove'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) widget.store.deleteDebt(debt.name);
  }

  Future<void> _pay(BuildContext context, DebtState st) async {
    final wallets = balances(widget.store.db);
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('debtNeedWallet'))),
      );
      return;
    }
    final done = await payDebt(context, store: widget.store, state: st);
    if (done == null) return;
    widget.store.payDebt(st.debt, from: done.wallet, amount: done.amount);
    // Долг, который человек отдавал год, закрывается один раз — и палец имеет
    // право это почувствовать. Обычный платёж отвечает тихо.
    final closed = st.left > 0 && done.amount + 0.005 >= st.left;
    closed ? Tap.cheer() : Tap.done();
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.currency});

  final DebtTotals totals;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          totals.open == 0 ? tr('debtsPaidOff') : tr('debtsLeftTitle'),
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 13,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        MoneyText(totals.left, currency: currency, size: 30, weight: FontWeight.w800,
            color: totals.open == 0 ? Money.up(context) : Money.down(context),
            squeeze: true),
        if (totals.open > 0) ...[
          SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: [
            _Cell(title: tr('debtPaymentsMonth'), value: totals.minPayments, currency: currency),
            // Проценты в месяц — число, ради которого стоит гасить дорогое
            // первым: столько стоит сам факт наличия долга.
            _Cell(title: tr('debtInterestMonth'), value: totals.monthlyInterest,
                currency: currency),
          ]),
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
      MoneyText(value,
          currency: currency, size: 14, weight: FontWeight.w700, squeeze: true),
    ]);
  }
}

class _OrderPicker extends StatelessWidget {
  const _OrderPicker({required this.order, required this.onChange});

  final PayoffOrder order;
  final ValueChanged<PayoffOrder> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in [
          (PayoffOrder.avalanche, tr('debtAvalanche')),
          (PayoffOrder.snowball, tr('debtSnowball')),
        ])
          Material(
            color: order == item.$1 ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onChange(item.$1),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: order == item.$1
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
      SizedBox(height: 8),
      Text(
        order == PayoffOrder.avalanche
            ? tr('debtAvalancheHow')
            : tr('debtSnowballHow'),
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12.5,
          height: 1.35,
          color: scheme.onSurfaceVariant,
        ),
      ),
    ]);
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.state,
    required this.first,
    required this.onEdit,
    required this.onDelete,
    required this.onPay,
  });

  final DebtState state;
  final bool first;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final debt = state.debt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        // Первый в порядке погашения обведён: это и есть ответ «что гасить».
        border: first ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onEdit,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LabelDot(name: debt.name, icon: _icon(debt.kind), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      [
                        debtKindTitle(debt.kind),
                        if (debt.rate > 0) trf('debtRateYear', [_rate(debt.rate)]),
                        if (debt.dueDay > 0) trf('debtDueDayShort', [debt.dueDay]),
                      ].join(' · '),
                      maxLines: 2,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ]),
                ),
                if (first)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(Myna.dangerCircle, size: 20, color: scheme.primary),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(
                  child: Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        MoneyText(state.left, currency: debt.currency, size: 22,
                            weight: FontWeight.w800, squeeze: true),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            trf('goalOfTarget', [formatAmount(debt.principal)]),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 13.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ]),
                ),
                // Платёж — пилюлей рядом с суммой. Кнопка во всю ширину
                // раздувала карточку так, что три долга не помещались на
                // экран («экран долгов тоже уродский», 13.09.2026).
                if (!state.closed)
                  FilledButton(
                    onPressed: onPay,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      minimumSize: const Size(0, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(tr('debtPay')),
                  ),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: state.share),
                  duration: const Duration(milliseconds: 560),
                  curve: AppTheme.emphasizedDecelerate,
                  builder: (context, v, _) => LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                        state.closed ? Money.up(context) : labelColorFor(debt.name)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status(state),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: state.months == null && !state.closed
                      ? Money.down(context)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  static String _rate(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString().replaceAll('.', ',');

  static IconData _icon(DebtKind kind) => switch (kind) {
        DebtKind.card => Myna.creditCard,
        DebtKind.microloan => Myna.dangerTriangle,
        DebtKind.mortgage => Myna.buildingOne,
        DebtKind.loan => Myna.bank,
      };

  static String _status(DebtState st) {
    if (st.closed) return tr('debtPaidOff');
    final months = st.months;
    if (months == null) {
      // Платёж меньше процентов: полосу тут рисовать нельзя, надо сказать
      // прямо, что так долг не кончится.
      return trf('debtNeverEnds', [formatAmount(st.debt.minPayment)]) +
          trf('debtNeverEndsTail', [formatAmount(st.monthlyInterest)]);
    }
    return trf('debtPayoffIn', [formatAmount(st.debt.minPayment)]) +
        trf('debtTermAndInterest', [
          _monthsWord(months),
          formatAmount(st.monthlyInterest),
        ]);
  }

  /// «1 месяц», «5 месяцев», «5 months». Форму слова выбирает словарь.
  static String _monthsWord(int n) =>
      n == 0 ? trn('months', 1) : '$n ${trn('months', n)}';
}
