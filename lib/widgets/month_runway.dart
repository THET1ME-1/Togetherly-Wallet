import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../logic/forecast.dart';

/// Лента месяца: прожитое, будущее и точка, где кончаются деньги.
///
/// Прогноз — это разговор про ВРЕМЯ, а не про одно число, и полоса отвечает
/// на вопросы, которые числом не задать: далеко ли до конца месяца, где стоят
/// обязательные платежи и доживут ли деньги до последнего числа.
///
/// Как читается слева направо:
///
/// * сплошная часть — прожитые дни; она уже случилась;
/// * засечка — сегодня;
/// * пунктир — то, что будет при нынешнем темпе. Пунктир, потому что это
///   предположение, и рисовать его сплошным значило бы выдавать догадку за
///   факт (тем же пунктиром отмечено место, которое человек просит у
///   подписки, — это один язык);
/// * штрихи сверху — обязательные платежи на своих датах;
/// * если деньги кончаются раньше конца месяца, с этого места лента идёт
///   цветом расхода. Цвет здесь законен: лента и есть деньги, а не плашка.
class MonthRunway extends StatelessWidget {
  const MonthRunway({
    super.key,
    required this.forecast,
    required this.now,
    this.height = 46,
  });

  final Forecast forecast;
  final DateTime now;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = DateTime(now.year, now.month + 1, 0).day;
    // День, когда деньги кончатся при нынешнем темпе. Ноль — не кончатся.
    var dryDay = 0;
    if (forecast.short && forecast.perDay > 0) {
      final canLast = (forecast.balance - forecast.dueAhead) / forecast.perDay;
      final at = now.day + canLast.floor();
      dryDay = at < days ? math.max(now.day, at) : 0;
    }

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, box) => CustomPaint(
          size: Size(box.maxWidth, height),
          painter: _RunwayPainter(
            days: days,
            today: now.day,
            dryDay: dryDay,
            due: [for (final d in forecast.due) d.day],
            ink: scheme.onSurface,
            line: scheme.outlineVariant,
            alarm: scheme.error,
            label: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RunwayPainter extends CustomPainter {
  _RunwayPainter({
    required this.days,
    required this.today,
    required this.dryDay,
    required this.due,
    required this.ink,
    required this.line,
    required this.alarm,
    required this.label,
  });

  final int days;
  final int today;

  /// День, когда деньги кончатся. Ноль — хватит до конца месяца.
  final int dryDay;
  final List<int> due;
  final Color ink;
  final Color line;
  final Color alarm;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    const bar = 7.0;
    final top = size.height - bar - 14;
    final w = size.width;
    double x(int day) => (day - 1) / (days - 1) * w;

    final track = Paint()
      ..color = line
      ..strokeWidth = bar
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final lived = Paint()
      ..color = ink
      ..strokeWidth = bar
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final y = top + bar / 2;

    // Дорожка всего месяца.
    canvas.drawLine(Offset(bar / 2, y), Offset(w - bar / 2, y), track);

    // Прожитое.
    final nowX = x(today).clamp(bar / 2, w - bar / 2);
    canvas.drawLine(Offset(bar / 2, y), Offset(nowX, y), lived);

    // Будущее пунктиром: это предположение, а не факт. Шаг считается от
    // ширины, чтобы штрихи не сливались на узком экране.
    final dashPaint = Paint()
      ..color = dryDay > 0 ? alarm : ink.withValues(alpha: 0.45)
      ..strokeWidth = bar
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final safePaint = Paint()
      ..color = ink.withValues(alpha: 0.45)
      ..strokeWidth = bar
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    const dash = 7.0;
    const gap = 5.0;
    for (var at = nowX + gap; at < w - bar / 2; at += dash + gap) {
      final end = math.min(at + dash, w - bar / 2);
      // До дня, когда деньги кончились, пунктир обычный; после — тревожный.
      final dry = dryDay > 0 && at >= x(dryDay);
      canvas.drawLine(
          Offset(at, y), Offset(end, y), dry ? dashPaint : safePaint);
    }

    // Обязательные платежи: короткий штрих сверху на своей дате.
    final mark = Paint()
      ..color = ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final day in due) {
      final at = x(day).clamp(bar / 2, w - bar / 2);
      canvas.drawLine(Offset(at, top - 8), Offset(at, top - 2), mark);
    }

    // Сегодня: засечка во всю высоту ленты, чтобы взгляд цеплялся за неё.
    final tick = Paint()
      ..color = ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(nowX, top - 11), Offset(nowX, top + bar + 4), tick);

    // Подписи краёв: первое и последнее число месяца.
    _text(canvas, '1', Offset(0, size.height - 12), label);
    _text(canvas, '$days', Offset(w, size.height - 12), label, right: true);
  }

  void _text(Canvas canvas, String text, Offset at, TextStyle style,
      {bool right = false}) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    p.paint(canvas, Offset(right ? at.dx - p.width : at.dx, at.dy));
  }

  @override
  bool shouldRepaint(_RunwayPainter old) =>
      old.days != days ||
      old.today != today ||
      old.dryDay != dryDay ||
      old.due.length != due.length ||
      old.ink != ink ||
      old.line != line;
}
