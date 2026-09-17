import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_primitives.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 6 — Отчёты: столбцы «общие / личные мои» и плитки категорий.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _period = 0;

  static const _days = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
  static const _shared = [0.34, 0.22, 0.62, 0.30, 0.74, 0.48, 0.0];
  static const _personal = [0.12, 0.20, 0.10, 0.26, 0.14, 0.18, 0.0];

  static const _chartHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    // Тёмная карточка графика намеренно одна и та же в обеих темах:
    // это «чернильный» блок системы, а не поверхность.
    final onChart = context.tm.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Отчёты'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          Container(
            padding: const EdgeInsets.all(TmSpace.xl),
            decoration: BoxDecoration(
              color: tm.dark ? context.tm.card : TmColors.ink,
              borderRadius: BorderRadius.circular(TmRadius.card),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Неделя 7–13 сентября',
                  style: TmText.meta(onChart.withValues(alpha: 0.6))),
              const SizedBox(height: 14),
              Text(const Money(1824000).format(), style: TmText.balanceXl(onChart)),
              const SizedBox(height: 22),
              SizedBox(
                height: _chartHeight,
                child: Row(spacing: 9, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if (_shared[i] > 0)
                          _bar(_shared[i], context.tm.accent)
                        else
                          _bar(0.26, context.tm.field),
                        if (_personal[i] > 0) ...[
                          const SizedBox(height: 4),
                          _bar(_personal[i], context.tm.muted),
                        ],
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                for (final d in _days)
                  Expanded(
                    child: Center(
                      child: Text(d,
                          style: TmText.meta(onChart.withValues(alpha: 0.5)).copyWith(fontSize: 11)),
                    ),
                  ),
              ]),
              const SizedBox(height: TmSpace.l),
              Wrap(spacing: 14, runSpacing: TmSpace.s, children: [
                _legend('Общие', context.tm.accent, onChart),
                _legend('Личные мои', context.tm.muted, onChart),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          // Заголовок ужимается, сегменты держат свою ширину: на 320 dp
          // пара «Категории + мес/год» не помещалась в строку.
          Row(children: [
            Expanded(
              child: Text('Категории',
                  style: TmText.titleMd(tm.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: TmSpace.m),
            SizedBox(
              width: 128,
              child: TmSegmented(
                items: const ['Мес', 'Год'],
                index: _period,
                onChanged: (i) => setState(() => _period = i),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 210,
            child: Row(spacing: 10, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _catTile('Жильё', const Money(5200000), '1 платёж', labelColors[0], 0.86)),
              Expanded(child: _catTile('Еда', const Money(2430000), '38 трат', labelColors[1], 0.64)),
              Expanded(child: _catTile('Транспорт', const Money(910000), null, labelColors[2], 0.40)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _bar(double f, Color c) => FractionallySizedBox(
        widthFactor: 1,
        child: Container(
          height: _chartHeight * f,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        ),
      );

  Widget _legend(String label, Color c, Color fg) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TmText.meta(fg.withValues(alpha: 0.65))),
      ]);

  Widget _catTile(String name, Money amount, String? note, Color color, double heightFactor) =>
      FractionallySizedBox(
        heightFactor: heightFactor,
        alignment: Alignment.bottomCenter,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: TmSpace.l),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(TmRadius.section)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(amount.format(withSymbol: false), style: TmText.amount(TmColors.ink)),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name,
                    style: TmText.label(TmColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (note != null) ...[
                  const SizedBox(height: 6),
                  Text(note,
                      style: TmText.meta(TmColors.ink.withValues(alpha: 0.6)).copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ]),
            ],
          ),
        ),
      );
}
