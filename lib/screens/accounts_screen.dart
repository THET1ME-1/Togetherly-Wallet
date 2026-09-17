import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import 'account_edit_screen.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../widgets/card_tile.dart';
import '../widgets/money_text.dart';
import '../widgets/reveal.dart';
import '../services/notices.dart';
import '../services/plus.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';

/// Счета списком: имя, остаток в родной валюте и пересчёт в базовую под ним.
/// Валюты одного счёта не складываются — на счёте могут лежать лей и доллар
/// одновременно, и «сумма» из них была бы выдумкой.
class AccountsScreen extends StatelessWidget {
  final Store store;
  final ValueChanged<Transaction> onEdit;

  /// Банки с этого телефона: их логотипы стоят на картах счетов.
  final Notices? notices;

  /// Подписка: премиальные оформления карт открываются ею.
  final PlusService? plus;

  /// Открыть операции счёта. Своего экрана у счёта НЕТ: операции живут во
  /// вкладке «Транзакции», где есть поиск, отбор, сортировка и разбивка по
  /// дням. Отдельная страница повторяла её куском и расходилась с ней
  /// («а зачем, если у нас есть вкладка ТРАНЗАКЦИИ», 16.09.2026).
  final void Function(String account) onAccountOps;

  const AccountsScreen({
    super.key,
    required this.store,
    required this.onEdit,
    required this.onAccountOps,
    this.notices,
    this.plus,
  });

  /// Уходим из списка счетов и ставим отбор: человек оказывается в ленте,
  /// а не в третьем экране поверх второго.
  void onLedger(BuildContext context, String name) {
    Navigator.of(context).pop();
    onAccountOps(name);
  }

  /// Новый счёт заводится именем, дальше правится тем же листом. Без имени
  /// счёт не опознать: имя — его ключ и на сервере тоже.
  Future<void> _newAccount(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr('accountNew'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: tr('accountNameHint'),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: Text(tr('accountCreate')),
            ),
          ),
        ]),
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    store.editAccount(name);
    await showAccountSheet(context,
        store: store, name: name, notices: notices, plus: plus);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final db = store.db;
        final list = balances(db);
        final total = totalBase(list);
        final goals = goalsTotal(db);

        return Scaffold(
          appBar: AppBar(title: Text(tr('accountsTitle'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('accountTotal'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(total, currency: db.baseCurrency, size: 28, weight: FontWeight.w800),
                    if (goals.abs() >= 0.01) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Myna.flag, size: 16, color: scheme.onSurfaceVariant),
                          SizedBox(width: 6),
                          Text(
                            tr('accountInGoals'),
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          MoneyText(goals, currency: db.baseCurrency, size: 13),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final c in currencyTotals(list))
                          Chip(
                            label: Text(formatMoney(c.amount, c.currency)),
                            labelStyle: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                            side: BorderSide.none,
                            backgroundColor: scheme.surfaceContainerHighest,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (list.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Row(children: [
                    Text(
                      tr('accountsCards'),
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _newAccount(context),
                      icon: const Icon(Myna.plus, size: 18),
                      label: Text(tr('accountNewShort')),
                    ),
                  ]),
                ),
                // Карусель, а не список: карту узнают по цвету и четырём
                // цифрам, и она обязана быть размером с карту.
                SizedBox(
                  height: 288 / cardAspect + 4,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    physics: const PageScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final item = list[i];
                      final stored =
                          db.accounts.where((a) => a.name == item.name).firstOrNull;
                      return Reveal(
                        delay: Duration(milliseconds: 30 * (i < 6 ? i : 6)),
                        child: CardTile(
                          name: item.name,
                          account: stored,
                          amount: item.mainAmount,
                          currency: item.mainCurrency,
                          bankLogo: stored?.bank == null
                              ? null
                              : notices?.logos[stored!.bank],
                          extraCurrencies: item.byCurrency
                              .where((c) => c.currency != item.mainCurrency)
                              .toList(),
                          onTap: () => onLedger(context, item.name),
                          onDetails: () => showAccountSheet(
                            context,
                            store: store,
                            name: item.name,
                            notices: notices,
                            plus: plus,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    tr('accountAllTogether'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (var i = 0; i < list.length; i++)
                  _AccountRow(
                    store: store,
                    item: list[i],
                    onTap: () => onLedger(context, list[i].name),
                  ),
              ],
              // Пустой экран обязан ВЕСТИ дальше. Раньше здесь стояла одна
              // строка «счёт появится сам», а кнопка «Новая» пряталась внутри
              // списка карт — при нуле счетов завести первый было НЕЧЕМ, и
              // запись операции молча не срабатывала (замечено 13.09.2026).
              if (list.isEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(2, 28, 2, 8),
                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Myna.creditCard,
                        size: 26,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('accountsNone'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('accountsNoneText'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14.5,
                        height: 1.45,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => _newAccount(context),
                        icon: const Icon(Myna.plus, size: 20),
                        label: Text(tr('accountFirst')),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

String _opsWord(int n) => trn('operations', n);

class _AccountRow extends StatelessWidget {
  final Store store;
  final AccountBalance item;
  final VoidCallback onTap;

  const _AccountRow({required this.store, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.db;
    final at = db.accounts.indexWhere((a) => a.name == item.name);
    final stored = at >= 0 ? db.accounts[at] : null;
    // Цвет кружка — цвет ОФОРМЛЕНИЯ карты, а не хеш имени: иначе голубая карта
    // стоит в списке песочным кружком.
    final color = stored?.color != null
        ? Color(stored!.color!)
        : designOf(stored, item.name).fill;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              LabelDot(
                name: item.name,
                icon: accountIcon(item.name, stored: stored?.icon),
                color: color,
                size: 46,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(children: [
                      // Чей счёт видно сразу: лавандовый замок значит, что
                      // партнёр не увидит ни остаток, ни операции.
                      if (stored != null && !stored.isShared) ...[
                        Icon(Myna.lock,
                            size: 12, color: context.tm.text),
                        SizedBox(width: 4),
                        Text(
                          tr('accountOnlyYou'),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12.5,
                            color: context.tm.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ] else if (stored != null && stored.isPot) ...[
                        Icon(Myna.box, size: 12, color: context.tm.text),
                        SizedBox(width: 4),
                        Text(
                          tr('accountIsShared'),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12.5,
                            color: context.tm.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${item.operations} ${_opsWord(item.operations)}',
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MoneyText(item.mainAmount, currency: item.mainCurrency, size: 15.5),
                  if (item.multiCurrency || item.mainCurrency != db.baseCurrency) ...[
                    const SizedBox(height: 2),
                    MoneyText(
                      item.converted,
                      currency: db.baseCurrency,
                      size: 12,
                      weight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

