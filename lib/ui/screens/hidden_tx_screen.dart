import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';

/// Экран 10 — Скрытая трата. Сумма видна партнёру всегда (иначе баланс врёт),
/// прячется только суть: продавец, категория, заметка.
class HiddenTxScreen extends StatelessWidget {
  const HiddenTxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сюрприз'),
        leading: Padding(
          padding: const EdgeInsets.only(left: TmSpace.l),
          child: Center(
            child: Text('Отмена', style: TmText.body(tm.textAlpha(0.6)).copyWith(fontSize: 16)),
          ),
        ),
        leadingWidth: 92,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: TmSpace.xl),
            child: Center(
              child: Text('Готово',
                  style: TmText.navTitle(tm.dark ? context.tm.accent : context.tm.text)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: tm.personalFill,
              borderRadius: BorderRadius.circular(TmRadius.card),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: TmColors.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Myna.lock, size: 17, color: context.tm.onAccent),
                ),
                const SizedBox(width: 10),
                // Подпись переносится, а не уезжает за край: на 320 dp
                // «Видит только Артём» вылезал на 49 точек.
                Expanded(
                  child: Text('Видит только Артём',
                      style: TmText.label(context.tm.onAccent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
              const SizedBox(height: TmSpace.xl),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(const Money(1200000).format(),
                    style: TmText.balanceXl(context.tm.onAccent).copyWith(fontSize: 34)),
              ),
              const SizedBox(height: 10),
              Text('Серьги, «Золотое яблоко» · копилка на подарки',
                  style: TmText.body(context.tm.onAccent.withValues(alpha: 0.8))
                      .copyWith(fontSize: 13.5, height: 1.4)),
            ]),
          ),
          const SizedBox(height: TmSpace.m),
          TmSurface(
            radius: TmRadius.section,
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Раскрыть', style: TmText.rowTitle(tm.text)),
              const SizedBox(height: 14),
              const Wrap(spacing: TmSpace.s, runSpacing: TmSpace.s, children: [
                TmChip('14 февраля', scope: TmChipScope.personal),
                TmChip('День рождения'),
                TmChip('Вручную'),
              ]),
              const SizedBox(height: 14),
              Text('После даты запись раскроется сама и встанет в общую ленту задним числом.',
                  style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12, height: 1.5)),
            ]),
          ),
          const SizedBox(height: 26),
          const TmGroupLabel('Что увидит Лена'),
          const SizedBox(height: TmSpace.m),
          const TmTxRow(
            title: 'Трата Артёма',
            amount: Money(1200000),
            hidden: true,
            revealLabel: 'Откроется 14 февраля',
          ),
          const SizedBox(height: 14),
          TmSurface(
            color: tm.row,
            radius: TmRadius.row,
            border: BorderSide.none,
            child: Text(
              'Сумма видна всегда — без неё общий баланс врал бы, а врущий баланс хуже скрытой детали.',
              style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12.5, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
