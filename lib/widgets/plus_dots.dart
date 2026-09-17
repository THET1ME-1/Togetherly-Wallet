import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Счёт до потолка точками.
///
/// Форма выбрана человеком 17.09.2026 из трёх (подпись, число на кнопке,
/// точки). Причина, по которой точки работают лучше числа: «осталось 2 из 5»
/// человек читает, а точки он ВИДИТ — как патроны в обойме, не переводя их в
/// слова. На узком экране они занимают втрое меньше места, чем подпись, и
/// потому влезают в строку заголовка, где число бы её разорвало.
///
/// Устройство ряда:
///
/// * занятое место — залитый круг;
/// * свободное — кольцо в линию, той же величины: ряд не «схлопывается», пока
///   человек заводит записи, и длина ряда всегда говорит о потолке;
/// * место, которое человек просит прямо сейчас, — пунктирное кольцо. Оно
///   стоит ШЕСТЫМ у пяти бесплатных и есть весь смысл стены: вот то, за что
///   просят денег, вот сколько у вас уже занято.
///
/// Точка растёт вместе с системным шрифтом: при увеличении 1.3 ряд из пяти
/// точек рядом с крупными буквами иначе выглядит мусором на строке.
class PlusDots extends StatelessWidget {
  const PlusDots({
    super.key,
    required this.have,
    required this.limit,
    this.size = 7,
    this.gap = 5,
    this.pending = false,
    this.animate = true,
  });

  /// Сколько занято. Может быть больше потолка: у человека, который вёл семь
  /// бюджетов до появления подписки, остаются все семь.
  final int have;

  /// Сколько даётся бесплатно.
  final int limit;

  /// Диаметр точки при обычном шрифте.
  final double size;

  /// Зазор между точками.
  final double gap;

  /// Дорисовать пунктирное место — то, которое человек просит.
  final bool pending;

  /// Заливать новую точку движением. Выключается там, где ряд появляется
  /// сразу целиком (стена), — иначе он «набирается» на глазах у человека,
  /// который и так упёрся.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final dot = size * scale;
    final step = gap * scale;
    // Точек рисуется не больше потолка: семь занятых при потолке в пять дают
    // пять залитых и подпись «+2» рядом — её ставит PlusMeter.
    final shown = math.min(have, limit);
    final slots = limit + (pending ? 1 : 0);
    final width = slots * dot + (slots - 1) * step;
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: shown.toDouble(), end: shown.toDouble()),
      duration: animate && !still
          ? const Duration(milliseconds: 260)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (context, filled, _) => CustomPaint(
        size: Size(width, dot),
        painter: _DotsPainter(
          filled: filled,
          limit: limit,
          dot: dot,
          step: step,
          pending: pending,
          ink: scheme.onSurface,
          line: scheme.outlineVariant,
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.filled,
    required this.limit,
    required this.dot,
    required this.step,
    required this.pending,
    required this.ink,
    required this.line,
  });

  final double filled;
  final int limit;
  final double dot;
  final double step;
  final bool pending;
  final Color ink;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final r = dot / 2;
    final fill = Paint()..color = ink..isAntiAlias = true;
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      // Толщина линии растёт с точкой, но не тоньше волоса: на плотном экране
      // кольцо в 0,8 px пропадает совсем.
      ..strokeWidth = math.max(1.2, dot * 0.17)
      ..isAntiAlias = true;

    for (var i = 0; i < limit; i++) {
      final c = Offset(r + i * (dot + step), r);
      final part = (filled - i).clamp(0.0, 1.0);
      if (part <= 0) {
        canvas.drawCircle(c, r - stroke.strokeWidth / 2, stroke);
      } else if (part >= 1) {
        canvas.drawCircle(c, r, fill);
      } else {
        // Точка наливается: кольцо остаётся на месте, внутри растёт заливка.
        canvas.drawCircle(c, r - stroke.strokeWidth / 2, stroke);
        canvas.drawCircle(c, r * part, fill);
      }
    }

    if (!pending) return;
    // Место, которое человек просит: пунктирное кольцо цветом текста, а не
    // линии, — оно главное в стене и обязано читаться первым.
    final wanted = Offset(r + limit * (dot + step), r);
    final dash = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, dot * 0.17)
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const parts = 8;
    final radius = r - dash.strokeWidth / 2;
    final rect = Rect.fromCircle(center: wanted, radius: radius);
    // Дуга и пропуск равной длины: зубчатое кольцо читается как «место есть,
    // но его не выдали», а сплошное — как ещё одна свободная ячейка.
    final sweep = math.pi * 2 / parts;
    for (var i = 0; i < parts; i += 2) {
      canvas.drawArc(rect, i * sweep, sweep, false, dash);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.filled != filled ||
      old.limit != limit ||
      old.dot != dot ||
      old.step != step ||
      old.pending != pending ||
      old.ink != ink ||
      old.line != line;
}
