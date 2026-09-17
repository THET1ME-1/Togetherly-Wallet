import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 5 — Транзакции: группировка по дням, чип автора, подсказка о дубле.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _filter = 0;
  static const _filters = ['Все', 'Общие', 'Мои', 'Еда'];

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Операции'),
        leading: const BackButton(),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Icon(Myna.search))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          Wrap(spacing: TmSpace.s, runSpacing: TmSpace.s, children: [
            for (var i = 0; i < _filters.length; i++)
              TmChip(
                _filters[i],
                selected: i == _filter,
                onTap: () => setState(() => _filter = i),
              ),
          ]),
          const SizedBox(height: 22),
          const TmGroupLabel('Сегодня · −3 260 ₽'),
          const SizedBox(height: TmSpace.m),
          TmTxRow(
            title: 'Пятёрочка',
            categoryInitials: 'Ед',
            categoryColor: labelColors[1],
            meta: '19:40 · Артём',
            amount: Money(148000),
          ),
          const SizedBox(height: 9),
          TmTxRow(
            title: 'Яндекс Go',
            categoryInitials: 'Тр',
            categoryColor: labelColors[2],
            meta: '14:10 · Лена',
            amount: Money(78000),
          ),
          const SizedBox(height: 9),
          TmTxRow(
            title: 'Кинотеатр',
            categoryInitials: 'Рз',
            categoryColor: labelColors[3],
            meta: '21:00 · оба',
            amount: Money(100000),
          ),
          const SizedBox(height: 22),
          const TmGroupLabel('Вчера · +94 000 ₽'),
          const SizedBox(height: TmSpace.m),
          TmTxRow(
            title: 'Зарплата Лены',
            categoryInitials: 'Зп',
            categoryColor: context.tm.field,
            meta: 'В общий кошелёк',
            amount: Money(9400000),
            income: true,
          ),
          const SizedBox(height: 9),
          TmSurface(
            color: tm.row,
            radius: TmRadius.row,
            border: BorderSide(color: context.tm.muted),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.tm.muted, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Myna.copy, size: 17, color: TmColors.ink),
              ),
              const SizedBox(width: TmSpace.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Возможный дубль', style: TmText.rowTitle(tm.text)),
                  const SizedBox(height: 5),
                  Text('Две записи на 780 ₽ · объединить?', style: TmText.meta(tm.textAlpha(0.6))),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
