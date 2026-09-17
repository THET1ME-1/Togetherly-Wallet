import 'package:flutter/material.dart';

import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';

/// Экран 8 — Договорённости: лимит меняется предложением, второй соглашается.
class AgreementsScreen extends StatelessWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Договорённости'),
        leading: const BackButton(),
        actions: const [Padding(padding: EdgeInsets.only(right: 14), child: Icon(Myna.plus))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          TmAgreementCard(
            status: TmAgreementStatus.proposed,
            author: 'Лена предлагает · вчера',
            title: 'Лимит на «Еду»',
            oldValue: '24 000 ₽',
            newValue: '30 000 ₽',
            note: '«Мы четвёртый месяц выходим за лимит, давай признаем реальность»',
            onAccept: () {},
            onDiscuss: () {},
          ),
          const SizedBox(height: TmSpace.xxl),
          const TmGroupLabel('Действуют'),
          const SizedBox(height: TmSpace.m),
          const TmAgreementCard(
            status: TmAgreementStatus.active,
            author: 'Дележ по умолчанию',
            authorInitial: 'А',
            title: 'По доходу — Артём 60%, Лена 40%. С 1 июня.',
          ),
          const SizedBox(height: 10),
          TmSurface(
            radius: TmRadius.tile,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Взнос в общий кошелёк', style: TmText.rowTitle(tm.text))),
                const SizedBox(width: TmSpace.s),
                const TmChip('активно', scope: TmChipScope.income),
              ]),
              const SizedBox(height: 9),
              Text('5-го числа, 70 000 ₽ суммарно',
                  style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12.5)),
              const SizedBox(height: TmSpace.m),
              const TmShareBar(fractionA: 0.6, fractionB: 0.4, height: 10),
            ]),
          ),
          const SizedBox(height: 10),
          TmSurface(
            color: tm.row,
            radius: TmRadius.tile,
            border: BorderSide(color: tm.lineSoft),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text('Лимит на «Развлечения»',
                      style: TmText.rowTitle(tm.textAlpha(0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: TmSpace.s),
                const TmChip('отклонено', scope: TmChipScope.expense),
              ]),
              const SizedBox(height: 9),
              Text('Артём предлагал 8 000 ₽ · 2 сентября',
                  style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 12.5)),
            ]),
          ),
        ],
      ),
    );
  }
}
