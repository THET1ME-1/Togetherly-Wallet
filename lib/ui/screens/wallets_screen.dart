import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 4 — Кошельки. Чужой личный остаток на клиент не приходит вовсе.
class WalletsScreen extends StatelessWidget {
  const WalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кошельки'),
        leading: const BackButton(),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Icon(Myna.plus))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          const TmBalanceCard(
            title: 'Общий кошелёк',
            amount: Money(12864000),
            scope: TmWalletScope.pot,
            compactAmount: true,
          ),
          const SizedBox(height: TmSpace.xxl),
          const TmGroupLabel('Общие'),
          const SizedBox(height: TmSpace.m),
          Row(spacing: 10, children: [
            Expanded(child: _tile(tm, 'Карта Т-Банк', const Money(6410000), context.tm.field)),
            Expanded(child: _tile(tm, 'Наличные дома', const Money(930000), labelColors[0])),
          ]),
          const SizedBox(height: TmSpace.xxl),
          const TmGroupLabel('Мои личные'),
          const SizedBox(height: TmSpace.m),
          _personal(tm, 'Мой Сбер', 'Видит только Артём', const Money(4120000), Myna.creditCard),
          const SizedBox(height: 10),
          _personal(tm, 'Копилка на подарки', 'Скрыта от Лены', const Money(1800000), Myna.gift),
          const SizedBox(height: 10),
          TmSurface(
            color: tm.field,
            radius: TmRadius.tile,
            border: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 15),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: tm.track, borderRadius: BorderRadius.circular(13)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Кошельки Лены', style: TmText.rowTitle(tm.textAlpha(0.7))),
                  const SizedBox(height: 5),
                  Text('Личные — не показываются', style: TmText.meta(tm.textAlpha(0.6))),
                ]),
              ),
              Icon(Myna.eyeOff, size: 18, color: tm.textAlpha(0.4)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tile(TmPalette tm, String name, Money amount, Color color) => TmSurface(
        radius: TmRadius.tile,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 14),
          Text(name, style: TmText.rowTitle(tm.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(amount.format(), style: TmText.amount(tm.text)),
          ),
        ]),
      );

  Widget _personal(TmPalette tm, String name, String note, Money amount, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 15),
        decoration: BoxDecoration(
          color: tm.personalFill,
          borderRadius: BorderRadius.circular(TmRadius.tile),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tm.card,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 17, color: tm.text),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: TmText.rowTitle(tm.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 5),
              Text(note, style: TmText.meta(tm.text.withValues(alpha: 0.7))),
            ]),
          ),
          SizedBox(width: TmSpace.s),
          Text(amount.format(), style: TmText.amount(tm.text)),
        ]),
      );
}
