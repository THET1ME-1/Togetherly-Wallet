import 'package:flutter/material.dart';

import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';

/// Экран 9 — Разговор с ИИ. Два контура: личный лавандовый, общий мятный.
/// Контекст собирает сервер; клиент формирует только вопрос.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  int _scope = 0; // 0 — личный, 1 — общий

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final personal = _scope == 0;
    final accent = personal ? context.tm.accent : context.tm.accent;
    final onAccent = personal ? context.tm.onAccent : context.tm.onAccent;
    final ground = personal ? tm.personalTint : tm.bg;

    return Scaffold(
      backgroundColor: ground,
      appBar: AppBar(
        backgroundColor: ground,
        title: const Text('Спросить о деньгах'),
        leading: const BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.l),
        child: Column(children: [
          TmSegmented(
            items: const ['Личный контур', 'Общий'],
            index: _scope,
            activeColor: accent,
            onChanged: (i) => setState(() => _scope = i),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              personal
                  ? 'Видит все мои кошельки. Ответы не уходят Лене, скрытые траты не попадают в общие сводки.'
                  : 'Видит только общие кошельки и общие траты. Личное в контекст не попадает.',
              style: TmText.meta(personal
                      ? (tm.dark ? context.tm.accent : context.tm.text)
                      : (tm.dark ? context.tm.income : context.tm.text))
                  .copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView(children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 13),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text('Сколько я реально трачу на кофе?',
                      style: TmText.body(onAccent).copyWith(fontSize: 14, height: 1.45)),
                ),
              ),
              const SizedBox(height: TmSpace.m),
              TmSurface(
                radius: 20,
                border: BorderSide.none,
                padding: const EdgeInsets.all(TmSpace.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    'За три месяца — 18 400 ₽, в среднем 6 130 ₽ в месяц. Это 7% твоих личных трат и вторая статья после еды.',
                    style: TmText.body(tm.text).copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  Row(spacing: 10, children: [
                    Expanded(child: _stat(tm, '6 130 ₽', 'В месяц', personal)),
                    Expanded(child: _stat(tm, '62', 'Покупки', personal)),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: TmSpace.s, runSpacing: TmSpace.s, children: [
                    TmChip('Сделать целью', scope: personal ? TmChipScope.hidden : TmChipScope.income),
                    const TmChip('Поставить лимит'),
                  ]),
                ]),
              ),
            ]),
          ),
          Container(
            height: 58,
            padding: const EdgeInsets.only(left: 18, right: 8),
            decoration: BoxDecoration(
              color: tm.card,
              borderRadius: BorderRadius.circular(TmRadius.pill),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  personal ? 'Спросить о своих деньгах…' : 'Спросить об общем бюджете…',
                  style: TmText.body(tm.textAlpha(0.45)).copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TmRoundAction(icon: Myna.arrowUp, bg: accent, fg: onAccent),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Осталось 2 бесплатных вопроса · дальше Togetherly+',
              style: TmText.meta(tm.textAlpha(0.6))),
        ]),
      ),
    );
  }

  Widget _stat(TmPalette tm, String value, String label, bool personal) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: personal ? tm.personalTint : context.tm.field,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TmText.amount(personal && tm.dark ? tm.text : TmColors.ink)),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TmText.meta((personal && tm.dark ? tm.text : TmColors.ink).withValues(alpha: 0.6))
                  .copyWith(fontSize: 10.5)),
        ]),
      );
}
