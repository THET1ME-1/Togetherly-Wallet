import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'budget_edit_screen.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/envelope.dart';
import '../logic/icons.dart';
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
import '../design/myna_search.dart';

/// Бюджеты: сколько потрачено из лимита за текущий месяц. Считается по тем же
/// правилам, что и категории на других экранах, — иначе одна и та же трата
/// давала бы два разных числа.
class BudgetsScreen extends StatelessWidget {
  final Store store;

  /// Подписка: потолок бесплатной версии считается только при создании
  /// НОВОЙ записи. Заведённые раньше остаются все до одной — отбирать
  /// выданное нельзя.
  final PlusService? plus;
  const BudgetsScreen({super.key, required this.store, this.plus});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final db = store.db;
        // Конверт считается за свой период и помнит перенос с прошлого: у
        // дневного и недельного лимита месячная сумма ничего не значит.
        final envelopes = [for (final b in db.budgets) envelopeOf(db, b)];
        final pair = db.pair.members.length > 1;

        // Предложенное стоит ЗДЕСЬ, а не на отдельном экране договорённостей.
        // Человек, поставивший бюджет вдвоём, шёл на главную и видел «Нет
        // активных бюджетов» — предложение ждало ответа этажом выше, и об
        // этом ему никто не говорил (17.09.2026).
        final waiting = [
          for (final a in db.agreements)
            if (a.status == AgreementStatus.proposed &&
                a.kind == AgreementKind.limit)
              a,
        ];
        // Отказ тоже виден: предложение, исчезнувшее молча, читается как
        // «партнёр не ответил», а он ответил.
        final declined = [
          for (final a in db.agreements)
            if (a.status == AgreementStatus.declined &&
                a.kind == AgreementKind.limit)
              a,
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('budgetsTitle')),
            // Счёт до потолка точками: человек видит, сколько у него осталось,
            // ЗАРАНЕЕ — а не в тот момент, когда его не пустили. У подписчика
            // точек нет вовсе.
            actions: [
              PlusMeter(
                gate: PlusGate.envelope,
                count: plusCount(
                  PlusGate.envelope,
                  plus: plus?.active ?? true,
                  db: db,
                ),
                plus: plus,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('budgetOne')),
          ),
          body: db.budgets.isEmpty && waiting.isEmpty && declined.isEmpty
              ? _empty(context, pair)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    for (final a in waiting)
                      Reveal(
                        child: _ProposalCard(
                          store: store,
                          agreement: a,
                          onEdit: () => _editProposal(context, a),
                        ),
                      ),
                    for (var i = 0; i < envelopes.length; i++)
                      Reveal(
                        delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                        child: _BudgetCard(
                          envelope: envelopes[i],
                          onTap: () => _edit(context, envelopes[i].budget),
                          onDelete: () => _delete(context, envelopes[i].budget),
                        ),
                      ),
                    for (final a in declined)
                      Reveal(
                        child: _ProposalCard(
                          store: store,
                          agreement: a,
                          onEdit: () => _editProposal(context, a),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _empty(BuildContext context, bool pair) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(42),
              ),
              child: Icon(Myna.box, size: 62, color: scheme.onSurface),
            ),
            SizedBox(height: 26),
            Text(
              tr('budgetsEmpty'),
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
              pair ? tr('budgetsEmptyPair') : tr('budgetsEmptyHow'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Budget b) async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.box,
        tone: Theme.of(context).colorScheme.error,
        title: tr('budgetRemoveTitle'),
        text: trf('budgetRemoveText', [b.category]),
        action: tr('budgetRemove'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes == true) {
      store.setBudgets(
        store.db.budgets
            .where(
              (x) =>
                  !(x.category == b.category && x.subcategory == b.subcategory),
            )
            .toList(),
      );
    }
  }

  Future<void> _edit(BuildContext context, [Budget? current]) async {
    // Потолок считается ТОЛЬКО для новой записи: правка существующей идёт
    // мимо калитки, даже когда их больше бесплатного числа.
    if (current == null &&
        !await allowMore(
          context,
          plus: plus,
          gate: PlusGate.envelope,
          have: store.db.budgets.length,
        )) {
      return;
    }
    if (!context.mounted) return;
    // В паре бюджет не ставится молча: он ПРЕДЛАГАЕТСЯ, и второй соглашается.
    // Форма при этом одна и та же — с поиском категории, выбором валюты,
    // периодом и переносом.
    final pair = store.db.pair.members.length > 1;
    final draft = await editBudget(
      context,
      store: store,
      current: current,
      onDelete: current == null ? null : () => _delete(context, current),
      propose: pair,
    );
    if (draft == null) return;
    if (pair) {
      store.proposeBudget(draft.budget, note: draft.note);
      return;
    }
    final next = draft.budget;
    final list = [...store.db.budgets];
    final at = list.indexWhere(
      (x) => x.category == next.category && x.subcategory == next.subcategory,
    );
    if (at >= 0) {
      list[at] = next;
    } else {
      list.add(next);
    }
    store.setBudgets(list);
  }

  /// Своё предложение правится целиком — так же, как бюджет. Чужое не
  /// правится вовсе: на него отвечают «Согласен» или «Не сейчас».
  Future<void> _editProposal(BuildContext context, Agreement a) async {
    final draft = await editBudget(
      context,
      store: store,
      current: a.budget,
      propose: true,
    );
    if (draft == null) return;
    store.proposeBudget(draft.budget, note: draft.note);
  }
}

class _BudgetCard extends StatelessWidget {
  final Envelope envelope;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.envelope,
    required this.onTap,
    required this.onDelete,
  });

  Budget get budget => envelope.budget;
  double get spent => envelope.spent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = budget.title;
    final share = envelope.share;
    final left = envelope.left;
    final over = envelope.over;
    final color = over
        ? Money.down(context)
        : (budget.color == null
            ? labelColorFor(budget.category)
            : Color(budget.color!));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Свой значок и цвет, как у цели и счёта. Пусто —
                    // подбираются по категории: «Зал» и так узнаётся.
                    LabelDot(
                      name: budget.category,
                      icon: budget.icon == null
                          ? categoryIcon(budget.category)
                          : (mynaByName[budget.icon!] ??
                              categoryIcon(budget.category)),
                      color: budget.color == null ? null : Color(budget.color!),
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: Icon(Myna.trash),
                      color: scheme.onSurfaceVariant,
                      tooltip: tr('budgetRemove'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: MoneyText(
                        spent,
                        currency: budget.currency,
                        size: 22,
                        weight: FontWeight.w800,
                        squeeze: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        trf('budgetOfPeriod', [
                          formatAmount(envelope.allowance),
                          _periodLabel(budget.periodKind),
                        ]),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 13.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: share.toDouble()),
                    duration: const Duration(milliseconds: 560),
                    curve: AppTheme.emphasizedDecelerate,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: scheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  over
                      ? trf('budgetOver', [formatMoney(-left, budget.currency)])
                      : trf('budgetLeft', [formatMoney(left, budget.currency)]),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: over ? Money.down(context) : scheme.onSurfaceVariant,
                  ),
                ),
                // Перенос называется словами: иначе непонятно, почему предел
                // не равен лимиту.
                if (budget.rollover && envelope.carried.abs() >= 0.005) ...[
                  SizedBox(height: 4),
                  Text(
                    envelope.carried > 0
                        ? '${trf('budgetCarriedIn', [_periodLast(budget.periodKind)])}+${formatAmount(envelope.carried)}'
                        : '${trf('budgetCarriedOver', [_periodLast(budget.periodKind)])}−${formatAmount(-envelope.carried)}',
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      color: envelope.carried > 0
                          ? Money.up(context)
                          : Money.down(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _periodLabel(BudgetPeriod p) => switch (p) {
  BudgetPeriod.daily => tr('periodPerDay'),
  BudgetPeriod.weekly => tr('periodPerWeek'),
  BudgetPeriod.monthly => tr('periodPerMonth'),
  BudgetPeriod.custom => tr('periodPerCustom'),
  BudgetPeriod.once => tr('periodPerOnce'),
};

/// «с прошлой недели», «с прошлого месяца». Целая фраза, а не окончание:
/// падежей у английского нет, и склеивать строку из огрызков нельзя.
String _periodLast(BudgetPeriod p) => switch (p) {
  BudgetPeriod.daily => tr('periodLastDay'),
  BudgetPeriod.weekly => tr('periodLastWeek'),
  BudgetPeriod.monthly => tr('periodLastMonth'),
  BudgetPeriod.custom => tr('periodLastCustom'),
  BudgetPeriod.once => '',
};

/// Предложенный бюджет: ждёт ответа второго.
///
/// Стоит в общем списке бюджетов, а не на своём экране: человек ищет
/// поставленный бюджет там, где живут все остальные, и «Нет активных
/// бюджетов» при отправленном предложении читалось как пропажа.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.store,
    required this.agreement,
    required this.onEdit,
  });

  final Store store;
  final Agreement agreement;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.db;
    final me = store.viewer;
    final mine = agreement.proposedBy == me;
    final declined = agreement.status == AgreementStatus.declined;
    final b = agreement.budget;
    final name = b?.subcategory == null
        ? agreement.category
        : '${agreement.category} · ${b!.subcategory}';
    final currency =
        b?.currency ?? '${agreement.payload['currency'] ?? db.baseCurrency}';
    final color = labelColorFor(agreement.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        // Ждущее решения обведено: в списке из восьми бюджетов оно обязано
        // отличаться от уже работающих, иначе его не заметят. Отвергнутое
        // стоит тихо — это уже не вопрос, а след разговора.
        border: Border.all(
          color: declined ? scheme.outlineVariant : scheme.primary,
          width: declined ? 1 : 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          // Чужое предложение не правится: на него отвечают. Отвергнутое
          // своё открывается снова — обычно после разговора цифра меняется.
          onTap: mine || declined ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        categoryIcon(agreement.category),
                        size: 19,
                        color: inkOn(color),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            declined
                                ? trf('budgetDeclinedBy', [
                                    db.pair
                                            .byUid(
                                              agreement.acceptedBy.isEmpty
                                                  ? agreement.proposedBy
                                                  : agreement.acceptedBy,
                                            )
                                            ?.name ??
                                        tr('accountPartner'),
                                  ])
                                : mine
                                ? trf('budgetWaiting', [
                                    db.pair.other(me)?.name ??
                                        tr('accountPartner'),
                                  ])
                                : trf('agreementProposes', [
                                    db.pair.byUid(agreement.proposedBy)?.name ??
                                        tr('accountPartner'),
                                  ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Прежняя сумма зачёркнутой рядом с новой: разговор идёт не о
                    // цифре, а о том, насколько её двигают.
                    if (agreement.oldAmount > 0) ...[
                      Text(
                        formatMoney(agreement.oldAmount, currency),
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    MoneyText(
                      agreement.amount,
                      currency: currency,
                      size: 18,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
                if (agreement.note.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '«${agreement.note}»',
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (declined) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onEdit,
                          child: Text(tr('budgetProposeAgain')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextButton(
                          onPressed: () => store.dropAgreement(agreement.id),
                          child: Text(tr('budgetDropProposal')),
                        ),
                      ),
                    ],
                  ),
                ]
                // Своё предложение принять нельзя: договорённость — это ответ
                // второго, а не способ поставить бюджет в обход него.
                else if (!mine) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => store.acceptAgreement(agreement, me),
                          child: Text(tr('agreementAgree')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => store.saveAgreement(
                            agreement.copyWith(
                              status: AgreementStatus.declined,
                              acceptedBy: me,
                            ),
                          ),
                          child: Text(tr('agreementNotNow')),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
