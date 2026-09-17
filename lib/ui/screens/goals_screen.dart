import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 7 — Цели: вклад каждого виден отдельно, мост к «Хочу с тобой».
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Цели'),
        leading: const BackButton(),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Icon(Myna.plus))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          TmSurface(
            padding: const EdgeInsets.all(TmSpace.xl),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Чип и срок переносятся: «Из «Хочу с тобой»» + «до июня»
              // не помещались в строку даже на 393 dp.
              Wrap(
                spacing: TmSpace.s,
                runSpacing: TmSpace.s,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const TmChip('Из «Хочу с тобой»', scope: TmChipScope.hidden),
                  Text('До июня', style: TmText.label(tm.textAlpha(0.5))),
                ],
              ),
              const SizedBox(height: TmSpace.l),
              Text('Поездка в Тбилиси', style: TmText.titleDisplay(tm.text).copyWith(fontSize: 22)),
              const SizedBox(height: 14),
              Wrap(
                spacing: TmSpace.s,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(const Money(8400000).format(withSymbol: false),
                      style: TmText.balanceXl(tm.text).copyWith(fontSize: 26)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text('из 180 000 ₽',
                        style: TmText.body(tm.textAlpha(0.55)).copyWith(fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: TmSpace.l),
              const TmShareBar(fractionA: 0.28, fractionB: 0.19, height: 14),
              const SizedBox(height: TmSpace.m),
              Row(children: [
                Expanded(
                  child: Text('Артём 50 400 ₽',
                      style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12)),
                ),
                Text('Лена 33 600 ₽',
                    style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12)),
              ]),
              const SizedBox(height: 18),
              Row(spacing: 10, children: [
                Expanded(child: TmButton(label: 'Пополнить', onPressed: () {}, expand: true)),
                Expanded(
                  child: TmButton(
                    label: 'Правила',
                    variant: TmButtonVariant.outline,
                    onPressed: () {},
                    expand: true,
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          _goalRow(tm, 'Подушка на 3 месяца', '234 000 из 300 000 ₽', '78%', context.tm.field),
          const SizedBox(height: 10),
          _goalRow(tm, 'Новый диван', 'Желание Лены · 9 600 из 80 000 ₽', '12%', labelColors[1]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: TmSpace.l),
            decoration: BoxDecoration(
              color: tm.personalFill,
              borderRadius: BorderRadius.circular(TmRadius.tile),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Регулярный вклад', style: TmText.label(context.tm.onAccent)),
              const SizedBox(height: TmSpace.s),
              Text('5-го числа: Артём 6 000 ₽, Лена 4 000 ₽ — по долям дохода',
                  style: TmText.meta(context.tm.onAccent.withValues(alpha: 0.75))
                      .copyWith(fontSize: 12.5, height: 1.45)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _goalRow(TmPalette tm, String title, String note, String pct, Color color) => TmSurface(
        radius: TmRadius.tile,
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 15),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
            child: Text(pct, style: TmText.rowTitle(TmColors.ink)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TmText.rowTitle(tm.text), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 5),
              Text(note, style: TmText.meta(tm.textAlpha(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}
