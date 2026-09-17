import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../l10n/strings.dart';
import '../logic/stats.dart';

/// Кольцо долей. Сегменты разделены зазором, поэтому соседние цвета не
/// слипаются; пустое кольцо остаётся видимым бледной дорожкой — иначе экран без
/// операций выглядит сломанным, а не пустым.
class Donut extends StatelessWidget {
  final List<({double share, Color color})> parts;
  final double thickness;
  final Widget? center;

  const Donut({
    super.key,
    required this.parts,
    this.thickness = 22,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: AppTheme.emphasizedDecelerate,
      builder: (context, t, _) => CustomPaint(
        painter: _DonutPainter(
          parts: parts,
          thickness: thickness,
          track: scheme.surfaceContainerHighest,
          progress: t,
        ),
        // Центр живёт ВНУТРИ кольца: без этого миллиард наезжал на саму
        // дугу — текст ужимался по ширине карточки, а не по дырке в бублике.
        child: Center(
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.biggest.shortestSide - thickness * 2 - 16;
              return SizedBox(
                width: side > 0 ? side : 0,
                child: Center(child: center),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<({double share, Color color})> parts;
  final double thickness;
  final Color track;
  final double progress;

  _DonutPainter({
    required this.parts,
    required this.thickness,
    required this.track,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side - thickness,
      height: side - thickness,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    // Дорожка под сегментами: она же остаётся одна, когда долей нет.
    canvas.drawArc(rect, 0, math.pi * 2, false, stroke..color = track);

    if (parts.isEmpty) return;
    // Зазор в радианах. На узких долях его срезаем, иначе тонкий сегмент
    // исчезает целиком и в кольце появляется дырка без причины.
    const gap = 0.035;
    var angle = -math.pi / 2;
    for (final p in parts) {
      final full = math.pi * 2 * p.share * progress;
      if (full <= 0) continue;
      final trim = math.min(gap, full * 0.35);
      canvas.drawArc(
        rect,
        angle + trim / 2,
        math.max(full - trim, 0.004),
        false,
        stroke..color = p.color,
      );
      angle += full;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.thickness != thickness ||
      old.track != track ||
      old.parts.length != parts.length ||
      _changed(old.parts, parts);

  static bool _changed(
    List<({double share, Color color})> a,
    List<({double share, Color color})> b,
  ) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].share != b[i].share || a[i].color != b[i].color) return true;
    }
    return false;
  }
}

/// Кривая по дням с заливкой под ней. Ось значений — слева, даты — снизу.
/// Подписи считаются здесь же: у графика и у чисел под ним должен быть один
/// источник, иначе они расходятся на округлении.
class DayChart extends StatelessWidget {
  final List<Point> points;
  final Color color;

  /// Заливка под кривой уходит вниз до нуля. Для остатка, который бывает
  /// отрицательным, ноль лежит внутри поля, и заливка идёт от него.
  final bool signed;
  final String Function(double) labelOf;
  final double height;

  const DayChart({
    super.key,
    required this.points,
    required this.color,
    required this.labelOf,
    this.signed = false,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (points.length < 2) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: Center(
          child: Text(
            tr('nothingToDraw'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final values = points.map((p) => p.value).toList();
    var top = values.reduce(math.max);
    var bottom = signed ? values.reduce(math.min) : 0.0;
    if (!signed) top = math.max(top, 0);
    if (top == bottom) {
      top += top.abs() < 1 ? 1 : top.abs() * 0.2;
      bottom -= bottom.abs() < 1 ? 1 : bottom.abs() * 0.2;
    }
    // Круглые деления по оси: 0, 35, 70… читаются, а 33,7 — нет.
    final step = _niceStep((top - bottom) / 4);
    top = (top / step).ceilToDouble() * step;
    bottom = (bottom / step).floorToDouble() * step;

    final ticks = <double>[];
    for (var v = bottom; v <= top + step / 2; v += step) {
      ticks.add(v);
    }

    return SizedBox(
      // Ширина задаётся явно: CustomPaint без ребёнка сжимается до нуля по
      // свободной оси, и график молча пропадал.
      width: double.infinity,
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: AppTheme.emphasizedDecelerate,
        builder: (context, t, _) => CustomPaint(
          painter: _ChartPainter(
            points: points,
            color: color,
            top: top,
            bottom: bottom,
            ticks: ticks,
            labelOf: labelOf,
            progress: t,
            ink: scheme.onSurfaceVariant,
            grid: scheme.outlineVariant.withValues(alpha: 0.4),
            font: AppTheme.bodyFont,
          ),
        ),
      ),
    );
  }
}

double _niceStep(double raw) {
  if (raw <= 0) return 1;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final pick = norm <= 1 ? 1.0 : (norm <= 2 ? 2.0 : (norm <= 5 ? 5.0 : 10.0));
  return pick * mag;
}

class _ChartPainter extends CustomPainter {
  final List<Point> points;
  final Color color;
  final double top;
  final double bottom;
  final List<double> ticks;
  final String Function(double) labelOf;
  final double progress;
  final Color ink;
  final Color grid;
  final String font;

  _ChartPainter({
    required this.points,
    required this.color,
    required this.top,
    required this.bottom,
    required this.ticks,
    required this.labelOf,
    required this.progress,
    required this.ink,
    required this.grid,
    required this.font,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPad = 20.0;
    // Ширину оси меряем по самой длинной подписи: обрезанная сумма хуже, чем
    // немного более узкое поле графика.
    var axisWidth = 0.0;
    final painted = <TextPainter>[];
    for (final v in ticks) {
      final tp = _text(labelOf(v), 10.5, ink);
      painted.add(tp);
      axisWidth = math.max(axisWidth, tp.width);
    }
    final left = axisWidth + 8;
    final field = Rect.fromLTRB(left, 4, size.width, size.height - bottomPad);
    if (field.width <= 4 || field.height <= 4) return;

    double y(double v) =>
        field.bottom - (v - bottom) / (top - bottom) * field.height;

    for (var i = 0; i < ticks.length; i++) {
      final yy = y(ticks[i]);
      canvas.drawLine(
        Offset(field.left, yy),
        Offset(field.right, yy),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      painted[i].paint(canvas, Offset(field.left - 8 - painted[i].width, yy - painted[i].height / 2));
    }

    final dx = field.width / (points.length - 1);
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final px = field.left + dx * i;
      final py = y(points[i].value);
      if (i == 0) {
        line.moveTo(px, py);
      } else {
        // Сглаживание по горизонтали: кривая идёт мягко, но не выезжает за
        // свои точки — сумма дня должна лежать ровно на своей отметке.
        final prevX = field.left + dx * (i - 1);
        final prevY = y(points[i - 1].value);
        final midX = (prevX + px) / 2;
        line.cubicTo(midX, prevY, midX, py, px, py);
      }
    }

    final zeroY = y(bottom <= 0 && top >= 0 ? 0 : bottom).clamp(field.top, field.bottom);
    final fill = Path.from(line)
      ..lineTo(field.right, zeroY)
      ..lineTo(field.left, zeroY)
      ..close();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(
      field.left,
      field.top - 4,
      field.left + field.width * progress,
      field.bottom + 1,
    ));
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.02)],
        ).createShader(field),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.restore();

    // Подписи дат: только края и середина, иначе они наезжают друг на друга.
    final marks = points.length < 4
        ? [0, points.length - 1]
        : [0, points.length ~/ 3, points.length * 2 ~/ 3, points.length - 1];
    for (final i in marks.toSet()) {
      final d = points[i].date;
      final tp = _text('${d.day}.${d.month.toString().padLeft(2, '0')}', 10.5, ink);
      var px = field.left + dx * i - tp.width / 2;
      px = px.clamp(field.left, field.right - tp.width);
      tp.paint(canvas, Offset(px, size.height - bottomPad + 4));
    }
  }

  TextPainter _text(String s, double size, Color c) => TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(fontFamily: font, fontSize: size, color: c),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.progress != progress ||
      old.points.length != points.length ||
      old.top != top ||
      old.bottom != bottom ||
      old.color != color;
}

/// Мини-график без осей и подписей: он стоит в свёрнутой карточке рядом с
/// суммой и отвечает на один вопрос — росло или падало.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 44,
    this.width = 96,
  });

  final List<Point> points;
  final Color color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(width: width, height: height);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(points: points, color: color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.points, required this.color});

  final List<Point> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.value).toList();
    var top = values.reduce(math.max);
    var bottom = values.reduce(math.min);
    if (top == bottom) {
      top += 1;
      bottom -= 1;
    }

    double x(int i) => size.width * i / (points.length - 1);
    double y(double v) =>
        size.height - (v - bottom) / (top - bottom) * size.height;

    final line = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }

    // Заливка под кривой — тем же цветом, но почти прозрачная: она даёт
    // объём без второго цвета в карточке.
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.points != points || old.color != color;
}

