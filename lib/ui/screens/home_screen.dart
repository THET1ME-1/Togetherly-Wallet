import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 1 — Главный: общий кошелёк, сальдо долга одной строкой, лента пары.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, 110),
            children: [
              Row(children: [
                TmAvatarPair(ringColor: tm.bg),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Артём и Лена',
                        style: TmText.navTitle(tm.text).copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Text('Сентябрь', style: TmText.meta(tm.textAlpha(0.55))),
                  ]),
                ),
                Container(
                  width: kTmMinTap,
                  height: kTmMinTap,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: tm.field, shape: BoxShape.circle),
                  child: Icon(Myna.bell, size: 18, color: tm.text),
                ),
              ]),
              const SizedBox(height: 18),
              TmBalanceCard(
                title: 'Общий кошелёк',
                caption: 'Баланс пары · RUB',
                amount: const Money(12864000),
                scope: TmWalletScope.pot,
                actions: [
                  const TmRoundAction(icon: Myna.plus),
                  const TmRoundAction(icon: Myna.arrowDown),
                  const TmRoundAction(icon: Myna.dollarCircle),
                  Expanded(
                    child: TmButton(
                      label: 'Счета',
                      variant: TmButtonVariant.ink,
                      onPressed: () {},
                      expand: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.m),
              TmBalanceDueCard(text: 'За Леной 740 ₽', onSettle: () {}),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Text('Операции', style: TmText.titleMd(tm.text))),
                Text('Все', style: TmText.label(tm.textAlpha(0.55))),
              ]),
              const SizedBox(height: 14),
              TmTxRow(
                title: 'Пятёрочка',
                categoryInitials: 'Ед',
                categoryColor: labelColors[1],
                meta: 'Артём · поровну',
                amount: Money(148000),
                debtNote: 'За Леной 740',
              ),
              const SizedBox(height: 9),
              TmTxRow(
                title: 'Аренда',
                categoryInitials: 'Жк',
                categoryColor: labelColors[0],
                meta: 'Общий кошелёк · регулярно',
                amount: Money(5200000),
              ),
              const SizedBox(height: 9),
              const TmTxRow(
                title: 'Трата Артёма',
                amount: Money(1200000),
                hidden: true,
                revealLabel: 'Откроется 14 февраля',
              ),
              const SizedBox(height: 9),
              TmTxRow(
                title: 'Зарплата Лены',
                categoryInitials: 'Зп',
                categoryColor: context.tm.field,
                meta: 'В общий кошелёк',
                amount: Money(9400000),
                income: true,
              ),
            ],
          ),
          Positioned(
            left: TmSpace.xl,
            right: TmSpace.xl,
            bottom: 18,
            child: TmTabBar(index: _tab, onChanged: (i) => setState(() => _tab = i)),
          ),
        ]),
      ),
    );
  }
}
