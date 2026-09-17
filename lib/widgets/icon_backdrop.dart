import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/scatter.dart';

/// Ассорти денежных значков на фоне экрана.
///
/// Стоит на входе и регистрации: пустой экран с двумя полями не говорит о
/// приложении ничего, а россыпь продуктов, транспорта, зарплаты и вкладов
/// говорит сразу. Укладку считает `scatterMarks` — тот же код, что держит фон
/// кварталов: без строк и столбцов, знаки разного размера и на полном обороте.
class IconBackdrop extends StatelessWidget {
  const IconBackdrop({
    super.key,
    required this.icons,
    this.color,
    this.opacity = 0.045,
    this.seed = 20260912,
    this.scale = 0.32,
  });

  final List<IconData> icons;
  final Color? color;

  /// Бледность знаков. Фон обязан оставаться фоном: поверх него читают
  /// заголовок и подписи полей, поэтому успокаивают его ИМЕННО бледностью.
  ///
  /// Что уже пробовали и выбросили:
  /// * вуаль (слой цвета поверхности поверх знаков) — это не «мягкий фон», а
  ///   убавленная яркость всему экрану, и заказчик увидел это сразу;
  /// * размытие через `ImageFiltered` — на Android с Impeller размытие
  ///   полупрозрачных знаков на ПРОЗРАЧНОМ слое даёт чёрный фон с цветными
  ///   контурами вместо мягкой фактуры. Экран выглядел сломанным.
  final double opacity;

  final int seed;

  /// Размер знаков относительно кварталов. Фон занимает весь экран, и знаки в
  /// натуральную величину спорили бы с полями ввода.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.onSurface;
    return IgnorePointer(
      child: CustomPaint(
        painter: _Backdrop(
          icons: icons,
          color: tint.withValues(alpha: opacity),
          seed: seed,
          scale: scale,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Backdrop extends CustomPainter {
  const _Backdrop({
    required this.icons,
    required this.color,
    required this.seed,
    required this.scale,
  });

  final List<IconData> icons;
  final Color color;
  final int seed;
  final double scale;

  /// Кегль параграфа; настоящий размер даёт масштаб холста.
  static const double _base = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (icons.isEmpty || size.isEmpty) return;
    final marks = scatterMarks(
      seed: seed,
      size: size,
      kinds: icons.length,
      scale: scale,
    );
    if (marks.isEmpty) return;

    final ready = <int, ui.Paragraph>{};
    ui.Paragraph glyphOf(int index) => ready.putIfAbsent(index, () {
          final icon = icons[index % icons.length];
          final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
            fontFamily: icon.fontFamily,
            fontSize: _base,
          ))
            ..pushStyle(ui.TextStyle(
              color: color,
              fontSize: _base,
              fontFamily: icon.fontFamily,
            ))
            ..addText(String.fromCharCode(icon.codePoint));
          return builder.build()
            ..layout(const ui.ParagraphConstraints(width: _base * 1.4));
        });

    for (final m in marks) {
      final p = glyphOf(m.icon);
      canvas.save();
      canvas.translate(m.center.dx, m.center.dy);
      canvas.rotate(m.turn);
      canvas.scale(m.glyph / _base);
      canvas.drawParagraph(p, const Offset(-_base / 2, -_base / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Backdrop old) =>
      old.color != color ||
      old.seed != seed ||
      old.scale != scale ||
      old.icons.length != icons.length;
}
