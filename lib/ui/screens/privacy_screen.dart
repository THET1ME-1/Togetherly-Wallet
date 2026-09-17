import 'package:flutter/material.dart';

import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_primitives.dart';

/// Экран 11 — Приватность: человеческим языком, что видит партнёр.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _push = true;
  bool _blur = false;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Scaffold(
      appBar: AppBar(title: const Text('Приватность'), leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(TmSpace.xl, TmSpace.s, TmSpace.xl, TmSpace.huge),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.tm.field,
              borderRadius: BorderRadius.circular(TmRadius.section),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Аккаунт общий с Togetherly', style: TmText.rowTitle(context.tm.onAccent)),
              const SizedBox(height: TmSpace.s),
              Text(
                'Пара уже есть — приглашений и кодов здесь нет. Выход из одного приложения не роняет второе.',
                style: TmText.meta(context.tm.onAccent.withValues(alpha: 0.8))
                    .copyWith(fontSize: 12.5, height: 1.45),
              ),
            ]),
          ),
          const SizedBox(height: TmSpace.l),
          _switchRow(tm, 'Пуш о тратах Лены', '«−450 ₽, Пятёрочка, Лена»', _push,
              (v) => setState(() => _push = v)),
          const SizedBox(height: TmSpace.s),
          _switchRow(tm, 'Скрывать суммы на главном', 'На случай чужих глаз в метро', _blur,
              (v) => setState(() => _blur = v)),
          const SizedBox(height: TmSpace.xxl),
          const TmGroupLabel('Что видит Лена прямо сейчас'),
          const SizedBox(height: TmSpace.m),
          _visibility(tm, 'Общий кошелёк и две общие карты', context.tm.accent, tm.card),
          const SizedBox(height: TmSpace.s),
          _visibility(tm, 'Мои траты из общих кошельков', context.tm.accent, tm.card),
          const SizedBox(height: TmSpace.s),
          _visibility(tm, 'Сумма и дата двух скрытых трат', context.tm.accent, tm.personalTint),
          const SizedBox(height: TmSpace.s),
          _visibility(tm, 'Мои личные кошельки — никогда', tm.track, tm.row),
          const SizedBox(height: 18),
          Row(spacing: 10, children: [
            Expanded(
              child: TmButton(
                label: 'Выгрузить CSV',
                variant: TmButtonVariant.outline,
                onPressed: () {},
                expand: true,
              ),
            ),
            Expanded(
              child: TmButton(
                label: 'Удалить данные',
                variant: TmButtonVariant.danger,
                onPressed: () {},
                expand: true,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _switchRow(
    TmPalette tm,
    String title,
    String note,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.l, vertical: 10),
        decoration: BoxDecoration(
          color: tm.card,
          borderRadius: BorderRadius.circular(TmRadius.tile),
          border: Border.all(color: tm.line),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TmText.body(tm.text).copyWith(fontSize: 14, height: 1.2)),
              const SizedBox(height: 5),
              Text(note,
                  style: TmText.meta(tm.textAlpha(0.6)).copyWith(fontSize: 11.5, height: 1.3)),
            ]),
          ),
          const SizedBox(width: TmSpace.m),
          TmToggle(value: value, onChanged: onChanged),
        ]),
      );

  Widget _visibility(TmPalette tm, String text, Color dot, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(TmRadius.field),
          border: Border.all(color: bg == tm.personalTint ? context.tm.accent : tm.line),
        ),
        child: Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TmText.body(tm.text).copyWith(fontSize: 13.5, height: 1.3)),
          ),
        ]),
      );
}
