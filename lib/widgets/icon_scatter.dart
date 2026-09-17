import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/scatter.dart';

/// Ассорти знаков по площади: та самая фактура, что держит кварталы категорий.
///
/// Вынесено из `quarters.dart`, когда тем же приёмом налилась цель: два
/// одинаковых рисовальщика в двух файлах разошлись бы на первой же правке.
/// Укладку считает `scatterMarks` — без строк и столбцов, знаки четырёх
/// величин, полный оборот, без наложений.
class IconScatterPainter extends CustomPainter {
  const IconScatterPainter({
    required this.icons,
    required this.color,
    required this.seed,
    this.scale = 1,
  });

  /// Знаки набора. Чем их больше, тем живее фактура: одинаковый знак,
  /// повторённый сорок раз, читается обоями.
  final List<IconData> icons;
  final Color color;

  /// Из чего считается бросок: имя даёт свой рисунок каждой площади, но один и
  /// тот же при каждой перерисовке.
  final int seed;

  /// Величина знаков относительно квартала.
  final double scale;

  /// Кегль, которым строится параграф; настоящий размер даёт масштаб.
  static const double _base = 64;

  @override
  void paint(Canvas canvas, Size size) {
    if (icons.isEmpty) return;
    final marks = scatterMarks(
      seed: seed,
      size: size,
      kinds: icons.length,
      scale: scale,
    );
    if (marks.isEmpty) return;

    // Параграф строится ОДИН на знак и рисуется с масштабом: у каждого знака
    // свой размер, а раскладка текста считается один раз. Иначе сотня знаков
    // давала сотню раскладок за кадр.
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
  bool shouldRepaint(IconScatterPainter old) =>
      old.color != color ||
      old.seed != seed ||
      old.scale != scale ||
      old.icons.length != icons.length ||
      !identical(old.icons, icons);
}
