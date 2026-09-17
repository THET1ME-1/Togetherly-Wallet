import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../logic/haptics.dart';
import 'pick_row.dart';

/// Выбор одного значения — РЯДОМ С ПРОКРУТКОЙ ВБОК.
///
/// Сеткой это было ровно полдня: «МЕНЯ ДОСТАЛО, ЧТО ТЫ ДЕЛАЕШЬ В СТОЛБИК, А НЕ
/// В СТРОКУ С ПРОЛИСТЫВАНИЕМ» (13.09.2026). Правило в проекте общее и старше
/// этого виджета: пилюли лежат одной строкой, а лишнее человек пролистывает
/// пальцем — десять счетов в `Wrap` занимали четыре строки и уносили кнопку
/// сохранения за экран.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.titles,
    required this.index,
    required this.onPick,
    this.icons,
  });

  final List<String> titles;
  final int index;
  final ValueChanged<int> onPick;

  /// Значок перед словом — когда он есть, ряд читается с одного взгляда.
  final List<IconData>? icons;

  @override
  Widget build(BuildContext context) => PickRow(
        height: 46,
        children: [
          for (var i = 0; i < titles.length; i++)
            _Cell(
              title: titles[i],
              icon: icons != null && i < icons!.length ? icons![i] : null,
              on: index == i,
              // Щелчок только на СМЕНЕ: отклик на повторное нажатие уже
              // выбранного обещает пальцу то, чего не произошло.
              onTap: () {
                if (index != i) Tap.pick();
                onPick(i);
              },
            ),
        ],
      );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.title,
    required this.on,
    required this.onTap,
    this.icon,
  });

  final String title;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: on ? scheme.onSecondaryContainer : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? scheme.onSecondaryContainer : scheme.onSurface,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
