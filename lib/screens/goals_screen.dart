import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'goal_edit_screen.dart';
import '../widgets/amount_field.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/goals.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../logic/reserve.dart';
import '../widgets/app_sheet.dart';
import '../logic/plus.dart';
import '../widgets/plus_meter.dart';
import '../logic/plus_usage.dart';
import '../services/plus.dart';
import '../widgets/plus_gate.dart';
import '../widgets/member_badge.dart';
import '../widgets/goal_vessel.dart';
import '../widgets/money_text.dart';
import '../widgets/reveal.dart';
import '../design/myna.dart';
import '../services/analytics.dart';

/// Цели с вкладами каждого.
///
/// Вклад — это перевод на счёт цели, поэтому «накоплено» всегда равно тому,
/// что лежит, а не обещанию. Чей вклад — говорит бейдж: в паре копят вдвоём,
/// и «сколько внёс я» — первый вопрос к общей копилке.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.store, this.plus});

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
        final goals = allGoals(db);

        return Scaffold(
          appBar: AppBar(
            title: Text(tr('goalsTitle')),
            // Счёт до потолка точками: человек видит, сколько у него осталось,
            // ЗАРАНЕЕ — а не в тот момент, когда его не пустили. У подписчика
            // точек нет вовсе.
            actions: [
              PlusMeter(
                gate: PlusGate.goal,
                count: plusCount(PlusGate.goal,
                    plus: plus?.active ?? true, db: db),
                plus: plus,
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context),
            icon: const Icon(Myna.plus),
            label: Text(tr('goalOne')),
          ),
          body: goals.isEmpty
              ? _empty(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    for (var i = 0; i < goals.length; i++)
                      Reveal(
                        delay: Duration(milliseconds: 40 * (i < 8 ? i : 8)),
                        child: _GoalCard(
                          store: store,
                          progress: goals[i],
                          // Сосуд ужимается, когда целей много: десять
                          // карточек по полтораста точек превращают экран в
                          // бесконечную ленту.
                          vessel: goals.length <= 3
                              ? 84
                              : goals.length <= 6
                                  ? 66
                                  : 54,
                          onEdit: () => _edit(context, goals[i].goal),
                          onDelete: () => _delete(context, goals[i]),
                          onMove: (back) => _move(context, goals[i], back: back),
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
            child: Icon(Myna.flag, size: 62, color: scheme.onSurface),
          ),
          SizedBox(height: 26),
          Text(
            tr('goalsEmpty'),
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
            tr('goalsEmptyHow'),
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

  Future<void> _edit(BuildContext context, [Goal? current]) async {
    // Потолок считается ТОЛЬКО для новой записи: правка существующей идёт
    // мимо калитки, даже когда их больше бесплатного числа.
    if (current == null &&
        !await allowMore(context, plus: plus, gate: PlusGate.goal, have: store.db.goals.length)) {
      return;
    }
    if (!context.mounted) return;
    final next = await editGoal(
      context,
      store: store,
      current: current,
      onDelete: current == null
          ? null
          : () {
              final p = allGoals(store.db)
                  .where((x) => x.goal.name == current.name)
                  .firstOrNull;
              if (p != null) _delete(context, p);
            },
    );
    if (next != null) {
      Analytics.instance.action(current == null ? 'goal_added' : 'goal_edited',
          params: {'reserve': next.isReserve});
      store.saveGoal(next);
    }
  }

  Future<void> _delete(BuildContext context, GoalProgress p) async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.flag,
        tone: Theme.of(context).colorScheme.error,
        title: trf('goalRemoveTitle', [p.goal.name]),
        text: p.saved.abs() < 0.005
            ? tr('goalRemoveEmpty')
            : trf('goalRemoveSaved', [formatMoney(p.saved, p.goal.currency)]),
        action: tr('goalRemove'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !context.mounted) return;

    // На цели лежат деньги, и запись убрать мало: `allGoals` собирает цели и
    // из операций по счёту «Цель: …», поэтому удалённая с деньгами возвращалась
    // на экран сама («цели нельзя удалить», 17.09.2026). Сперва возвращаем
    // накопленное на кошелёк, потом убираем запись.
    if (p.saved.abs() >= 0.005) {
      final wallets = balances(store.db);
      if (wallets.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(tr('goalNeedWallet'))));
        return;
      }
      final to = wallets.length == 1
          ? wallets.first.name
          : await showMoneySheet<String>(
              context,
              builder: (context) => _WalletSheet(
                wallets: wallets,
                title: trf('goalRemoveWhere', [
                  formatMoney(p.saved, p.goal.currency),
                ]),
              ),
            );
      if (to == null) return;
      store.withdrawFromGoal(p.goal, to: to, amount: p.saved);
    }
    store.deleteGoal(p.goal.name);
  }

  Future<void> _move(BuildContext context, GoalProgress p, {required bool back}) async {
    final wallets = balances(store.db);
    if (wallets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('goalNeedWallet'))),
      );
      return;
    }
    final done = await showModalBottomSheet<({String wallet, double amount})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _MoveSheet(store: store, progress: p, back: back),
    );
    if (done == null) return;
    if (back) {
      store.withdrawFromGoal(p.goal, to: done.wallet, amount: done.amount);
      Tap.done();
      return;
    }
    store.contributeToGoal(p.goal, from: done.wallet, amount: done.amount);
    // Цель собирается месяцами и закрывается один раз: вклад, который её
    // добирает, отвечает праздником, обычный — тихо. `left` у цели без суммы
    // ноль, и такой вклад праздником не считается.
    final reached = p.left > 0 && done.amount + 0.005 >= p.left;
    reached ? Tap.cheer() : Tap.done();
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.store,
    required this.progress,
    required this.vessel,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });

  final Store store;
  final GoalProgress progress;

  /// Высота сосуда: её задаёт длина списка, а не карточка.
  final double vessel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool back) onMove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.db;
    final goal = progress.goal;
    final paired = db.pair.members.length > 1;
    // Подушка живёт своими числами: сумма считается из расходов, а не лежит
    // в записи, поэтому и полоса, и подпись берутся у неё.
    final reserve = goal.isReserve ? reserveOf(db, goal) : null;
    // Свой цвет цели сильнее палитры по имени: человек выбрал его руками.
    final own = goal.color == null ? null : Color(goal.color!);
    final color = progress.done
        ? Money.up(context)
        : progress.overdue
            ? Money.down(context)
            : (own ?? labelColorFor(goal.name));

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
          onTap: onEdit,
          onLongPress: onDelete,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                LabelDot(
                  name: goal.name,
                  icon: goal.isReserve
                      ? Myna.shield
                      : goalIcon(goal.name, stored: goal.icon),
                  color: own,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    goal.name,
                    maxLines: 2,
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
                  tooltip: tr('goalRemove'),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  MoneyText(progress.saved,
                      currency: goal.currency, size: 22, weight: FontWeight.w800),
                  if (progress.hasTarget || (reserve != null && reserve.target > 0))
                    Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: Text(
                        trf('goalOfTarget', [formatAmount(reserve?.target ?? goal.target)]),
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 13.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              if (progress.hasTarget || (reserve != null && !reserve.unknown)) ...[
                const SizedBox(height: 12),
                // Цель наливается: доля собранного — это высота воды, а по
                // ней идёт ассорти знаков самой цели. Имя не повторяем, оно
                // стоит в шапке карточки.
                GoalVessel(
                  name: goal.name,
                  showName: false,
                  share: reserve?.share ?? progress.share,
                  badge: '${(((reserve?.share ?? progress.share)).clamp(0.0, 1.0) * 100).round()}%',
                  color: color,
                  icons: goalScatterIcons(goal.name,
                      stored: goal.icon, reserve: goal.isReserve),
                  height: vessel,
                  onTap: onEdit,
                  onLongPress: onDelete,
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _status(progress, reserve: reserve),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: progress.overdue ? Money.down(context) : scheme.onSurfaceVariant,
                ),
              ),
              // Вклады по людям: в паре важнее самой суммы. У одиночки
              // строка не нужна — вклад там всегда один и тот же.
              if (paired && progress.byMember.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final e in _sorted(progress.byMember))
                      _Contribution(
                        member: db.pair.byUid(e.key),
                        isMe: e.key == store.viewer,
                        amount: e.value,
                        currency: goal.currency,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: progress.saved.abs() < 0.005 ? null : () => onMove(true),
                    child: Text(tr('goalTake')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onMove(false),
                    child: Text(tr('goalPut')),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  static List<MapEntry<String, double>> _sorted(Map<String, double> by) {
    final list = by.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Строка под полосой. У подушки она считается месяцами: «2,4 месяца из 6»
  /// говорит человеку больше, чем «осталось 36 000».
  static String _status(GoalProgress p, {Reserve? reserve}) {
    if (reserve != null) {
      if (reserve.unknown) {
        return tr('goalReserveWait');
      }
      final covered = reserve.monthsCovered;
      final head = trf('goalReserveCovers', [_monthsWord(covered), reserve.monthsWanted]);
      if (reserve.done) return trf('goalReserveDone', [head]);
      return trf('goalReserveLeft', [
        head,
        formatMoney(reserve.left, p.goal.currency),
      ]);
    }
    if (p.done) return tr('goalSaved');
    if (!p.hasTarget) return tr('goalNoTarget');
    final parts = <String>[trf('goalLeft', [formatMoney(p.left, p.goal.currency)])];
    final days = p.daysLeft;
    if (days != null) {
      parts.add(days < 0
          ? trf('goalOverdue', ['${-days} ${_days(-days)}'])
          : days == 0
              ? tr('goalDueToday')
              : trf('goalDueIn', ['$days ${_days(days)}']));
    }
    final perDay = p.perDay;
    if (perDay != null && perDay > 0) {
      parts.add(trf('goalPerDay', [formatAmount(perDay)]));
    }
    return parts.join(' · ');
  }

  /// «2,4 месяца», «1 месяц», «5 месяцев» — число с одним знаком после
  /// запятой, иначе «хватит на 2 месяца» при 2,9 звучит обманом. Форму слова
  /// выбирает словарь: у русского их три, у английского две.
  static String _monthsWord(double v) {
    final rounded = (v * 10).round() / 10;
    final whole = rounded == rounded.roundToDouble();
    final text = whole
        ? rounded.round().toString()
        : rounded.toString().replaceAll('.', ',');
    // Дробное число всегда берёт форму «2,4 месяца» — счётную, как у двойки.
    final word = whole ? trn('months', rounded.round()) : trn('months', 2);
    return '$text $word';
  }

  static String _days(int n) => trn('days', n);
}

class _Contribution extends StatelessWidget {
  const _Contribution({
    required this.member,
    required this.isMe,
    required this.amount,
    required this.currency,
  });

  final Member? member;
  final bool isMe;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      MemberBadge(member: member, isMe: isMe),
      const SizedBox(width: 6),
      MoneyText(amount, currency: currency, size: 13.5, weight: FontWeight.w700),
    ]);
  }
}

/// Заведение и правка цели. Имя — ключ, поэтому у заведённой цели оно не
/// меняется: вместе с ним пришлось бы переносить счёт и все вклады.
class _WalletSheet extends StatelessWidget {
  const _WalletSheet({required this.wallets, required this.title});

  final List<AccountBalance> wallets;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(w.name),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(children: [
                      LabelDot(
                        name: w.name,
                        icon: accountIcon(w.name),
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          w.name,
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
                      MoneyText(w.mainAmount,
                          currency: w.mainCurrency, size: 13.5, squeeze: true),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.store, required this.progress, required this.back});

  final Store store;
  final GoalProgress progress;
  final bool back;

  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  final _amount = TextEditingController();
  String? _wallet;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final wallets = balances(db);
    final wallet = _wallet ?? wallets.first.name;
    final walletCurrency =
        db.accounts.where((a) => a.name == wallet).firstOrNull?.currency ?? db.baseCurrency;
    final goal = widget.progress.goal;
    final currency = widget.back ? goal.currency : walletCurrency;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            widget.back ? trf('goalTakeFrom', [goal.name]) : trf('goalPutInto', [goal.name]),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AppTheme.displayFont, fontSize: 20, color: scheme.onSurface),
          ),
          SizedBox(height: 6),
          Text(
            widget.back
                ? trf('goalSavedAmount', [formatMoney(widget.progress.saved, goal.currency)])
                : tr('goalMoveNote'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          // Валюта видна В САМОМ поле, а не подписью над ним: тема гасит
          // `labelText` намертво (`floatingLabelBehavior: never`), и человек
          // видел пустое поле с подсказкой «500», не понимая, в чём сумма —
          // «почему только в системной валюте» (17.09.2026). Меняется она
          // выбором кошелька: уходит именно его валюта.
          AmountField(
            controller: _amount,
            currency: currency,
            autofocus: true,
            hint: '500',
            onChanged: (_) => setState(() {}),
          ),
          if (!widget.back && goal.currency != walletCurrency) ...[
            const SizedBox(height: 8),
            Text(
              trf('currencyConverted', [
                formatMoney(
                  convert(db, parseAmount(_amount.text) ?? 0, walletCurrency) /
                      rateOf(db, goal.currency),
                  goal.currency,
                ),
              ]),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.back ? tr('goalToWallet') : tr('goalFromWallet'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in wallets)
                _WalletPick(
                  name: a.name,
                  on: a.name == wallet,
                  onTap: () => setState(() => _wallet = a.name),
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13.5,
                color: scheme.error,
              ),
            ),
          ],
          SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _done(wallet),
              child: Text(widget.back ? tr('goalTake') : tr('goalPut')),
            ),
          ),
        ]),
      ),
    );
  }

  void _done(String wallet) {
    final value = parseAmount(_amount.text) ?? 0;
    if (value <= 0) {
      setState(() => _error = tr('goalAmountPositive'));
      return;
    }
    if (widget.back && value > widget.progress.saved + 0.005) {
      setState(() => _error = tr('goalNotEnough'));
      return;
    }
    Navigator.of(context).pop((wallet: wallet, amount: value));
  }
}

class _WalletPick extends StatelessWidget {
  const _WalletPick({required this.name, required this.on, required this.onTap});

  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(accountIcon(name),
                  size: 18,
                  color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
