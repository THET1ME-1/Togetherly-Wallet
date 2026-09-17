import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 2 — Лист траты: «кто платил» и «чья трата» — разные строки.
class TxDetailScreen extends StatelessWidget {
  const TxDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      backgroundColor: tm.field,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: TmSpace.huge),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: tm.card,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(TmRadius.sheet)),
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(TmSpace.xl, 18, TmSpace.xl, TmSpace.huge),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tm.track,
                        borderRadius: BorderRadius.circular(TmRadius.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: TmSpace.xl),
                  Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: labelColors[1],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text('Ед', style: TmText.titleMd(TmColors.ink)),
                    ),
                    const Spacer(),
                    const TmChip('Общая трата', scope: TmChipScope.income),
                  ]),
                  const SizedBox(height: TmSpace.xl),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(const Money(-148000).format(),
                        style: TmText.balanceXxl(tm.text).copyWith(fontSize: 40)),
                  ),
                  const SizedBox(height: 10),
                  Text('Пятёрочка · 12 сентября, 19:40', style: TmText.body(tm.textAlpha(0.65))),
                  const SizedBox(height: 22),
                  _facts(tm, const [
                    ('Платил', 'Артём'),
                    ('Чья трата', 'Обоих · поровну'),
                    ('Кошелёк', 'Общий кошелёк'),
                    ('Категория', 'Еда · продукты'),
                  ]),
                  const SizedBox(height: TmSpace.m),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 14),
                    decoration: BoxDecoration(
                      color: context.tm.field,
                      borderRadius: BorderRadius.circular(TmRadius.row),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Доли', style: TmText.meta(context.tm.textAlpha(0.7))),
                          const SizedBox(height: 7),
                          Text('Артём 740 ₽ · Лена 740 ₽',
                              style: TmText.rowTitle(context.tm.text).copyWith(fontSize: 15)),
                        ]),
                      ),
                      Icon(Myna.chevronRight, color: context.tm.textAlpha(0.7)),
                    ]),
                  ),
                  const SizedBox(height: TmSpace.xl),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TmAvatar(initial: 'Л', color: labelColors[4], size: 28),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: tm.field,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Text('Где взял то вино?', style: TmText.label(tm.text)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: TmSpace.m),
                  const Padding(
                    padding: EdgeInsets.only(left: 38),
                    child: Row(spacing: TmSpace.s, children: [
                      TmChip('♡ 1'),
                      TmChip('Ответить'),
                    ]),
                  ),
                  const SizedBox(height: TmSpace.l),
                  Text('Лена изменила категорию · сегодня 20:03',
                      style: TmText.meta(tm.textAlpha(0.6))),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _facts(TmPalette tm, List<(String, String)> rows) => ClipRRect(
        borderRadius: BorderRadius.circular(TmRadius.row),
        child: ColoredBox(
          color: tm.line,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 1),
              Container(
                color: tm.card,
                padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 14),
                child: Row(children: [
                  Expanded(
                    child: Text(rows[i].$1,
                        style: TmText.body(tm.textAlpha(0.6)).copyWith(fontSize: 14)),
                  ),
                  const SizedBox(width: TmSpace.m),
                  Flexible(
                    child: Text(
                      rows[i].$2,
                      style: TmText.rowTitle(tm.text),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ]),
              ),
            ],
          ]),
        ),
      );
}
