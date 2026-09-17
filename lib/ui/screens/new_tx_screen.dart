import 'package:flutter/material.dart';

import '../money.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../widgets/tm_money_widgets.dart';
import '../widgets/tm_primitives.dart';
import '../../design/myna.dart';
import '../../design/accents.dart' show labelColors;

/// Экран 3 — Новая операция: дележ выбирается здесь же, а не в настройках.
class NewTxScreen extends StatefulWidget {
  const NewTxScreen({super.key});
  @override
  State<NewTxScreen> createState() => _NewTxScreenState();
}

class _NewTxScreenState extends State<NewTxScreen> {
  int _kind = 0;
  int _split = 0;
  int _minor = 148000;

  static const _splits = ['Поровну', 'По доходу', 'Только я', 'Вручную'];
  static const _shares = [
    [5000, 5000],
    [6000, 4000],
    [10000, 0],
    [7400, 2600],
  ];

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        _minor = _minor ~/ 10;
      } else if (k != ',') {
        final d = int.tryParse(k);
        if (d != null && _minor < 1000000000) _minor = _minor * 10 + d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final parts = Money.split(_minor, _shares[_split]);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(TmSpace.xl, 10, TmSpace.xl, TmSpace.l),
          // Клавиатура держит свою высоту, всё над ней прокручивается:
          // на 320×568 при системном шрифте 1.3 экран иначе не помещается
          // и обрезает кнопку «Сохранить».
          child: LayoutBuilder(builder: (context, box) {
            final keypadHeight = (box.maxHeight * 0.38).clamp(203.0, 300.0);
            return Column(children: [
              Row(children: [
                Text('Отмена', style: TmText.body(tm.textAlpha(0.6)).copyWith(fontSize: 16)),
                Expanded(child: Center(child: Text('Новая трата', style: TmText.navTitle(tm.text)))),
                Icon(Myna.undo, size: 20, color: tm.textAlpha(0.6)),
              ]),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    const SizedBox(height: 18),
                    TmSegmented(
                      items: const ['Расход', 'Доход', 'Перевод'],
                      index: _kind,
                      onChanged: (i) => setState(() => _kind = i),
                    ),
                    const SizedBox(height: 26),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(Money(_minor).format(),
                          style: TmText.balanceXxl(tm.text)
                              .copyWith(fontSize: 48, letterSpacing: -1.9)),
                    ),
                    const SizedBox(height: TmSpace.m),
                    Text('Общий кошелёк · 128 640 ₽', style: TmText.label(tm.textAlpha(0.6))),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: TmSpace.s,
                      runSpacing: TmSpace.s,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var i = 0; i < _splits.length; i++)
                          TmChip(
                            _splits[i],
                            selected: i == _split,
                            onTap: () => setState(() => _split = i),
                          ),
                      ],
                    ),
                    const SizedBox(height: TmSpace.l),
                    Row(spacing: 10, children: [
                      Expanded(
                        child: TmSurface(
                          radius: TmRadius.field,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(children: [
                            TmAvatar(initial: 'А', color: labelColors[0], size: 26),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Платил', style: TmText.meta(tm.textAlpha(0.6))),
                                const SizedBox(height: 5),
                                Text('Артём',
                                    style: TmText.label(tm.text),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                      Expanded(
                        child: TmSurface(
                          radius: TmRadius.field,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Доли', style: TmText.meta(tm.textAlpha(0.6))),
                            const SizedBox(height: 5),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${Money(parts[0]).format(withSymbol: false)} / ${Money(parts[1]).format(withSymbol: false)}',
                                style: TmText.label(tm.text),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 18),
                  ]),
                ),
              ),
              SizedBox(height: keypadHeight, child: TmKeypad(onKey: _key)),
              const SizedBox(height: 14),
              TmButton(
                label: 'Сохранить',
                size: TmButtonSize.large,
                expand: true,
                onPressed: _minor == 0 ? null : () {},
              ),
            ]);
          }),
        ),
      ),
    );
  }
}
