import 'package:flutter/material.dart';

import '../ui/theme/tm_scheme.dart';

/// Фон-сетка поверх листа темы.
///
/// Пустой лист человек отверг («пустой экран, мне не нравится», 13.09.2026),
/// но и чернить экран нельзя: у присланного рисунка фон чёрный, и при обычном
/// наложении приветствие уходило к #050505 — темнее всего приложения.
///
/// Поэтому в ассете лежит ПРОЗРАЧНАЯ сетка: яркость исходника стала альфой
/// (`tool/`-скрипта не нужно, файл готов), а цвет точкам даёт тема — белые на
/// графите, чёрные на бумаге. Лист при этом остаётся ровно тем же, что на
/// остальных экранах.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({
    super.key,
    required this.dark,
    this.opacity,
    this.fade = false,
  });

  final bool dark;

  /// Насколько видна сетка. В светлой теме точки должны читаться чёрными:
  /// бледная сетка выглядела засвеченной (13.09.2026).
  final double? opacity;

  /// Гасить ли сетку к низу. Нужно на рабочих экранах: за карточками с
  /// суммами фактура спорит с цифрами, поэтому внизу её нет вовсе.
  final bool fade;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final image = Image.asset(
      'assets/bg/welcome_grid.png',
      fit: BoxFit.cover,
      color: tm.text,
      colorBlendMode: BlendMode.srcIn,
      opacity: AlwaysStoppedAnimation(opacity ?? (dark ? 0.5 : 0.62)),
    );
    return ColoredBox(
      color: tm.bg,
      child: fade
          ? ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                stops: [0.0, 0.55],
              ).createShader(bounds),
              child: image,
            )
          : image,
    );
  }
}
