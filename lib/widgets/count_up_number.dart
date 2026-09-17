import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Число, которое при изменении «набегает» от старого значения к новому и
/// слегка подпрыгивает (M3 pop). При уменьшении (отмена хода) — мягче.
///
/// Умеет и целые (счёт, серия), и дробные ([fractionDigits] — среднее
/// настроение «4,1»). Разделитель дробной части берётся у языка интерфейса:
/// в русском это запятая.
///
/// Цвет/шрифт берутся из [style]. На первом построении значение показывается
/// сразу, без анимации.
class CountUpNumber extends StatefulWidget {
  final double value;
  final TextStyle style;
  final Duration duration;

  /// Сколько знаков после запятой. 0 — целое число.
  final int fractionDigits;

  /// Сокращать ли тысячи: 8200 → «8,2к». Нужно там, где число живёт в плитке
  /// и не может расти в ширину.
  final bool compact;

  /// Как называется «тысяча» на языке интерфейса (к / k).
  final String thousandSuffix;

  const CountUpNumber({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 480),
    this.fractionDigits = 0,
    this.compact = false,
    this.thousandSuffix = 'k',
  });

  /// Удобный конструктор для целых.
  const CountUpNumber.int({
    Key? key,
    required int value,
    required TextStyle style,
    Duration duration = const Duration(milliseconds: 480),
  }) : this(
          key: key,
          value: value + 0.0,
          style: style,
          duration: duration,
        );

  @override
  State<CountUpNumber> createState() => _CountUpNumberState();
}

class _CountUpNumberState extends State<CountUpNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  double _from = 0;
  bool _increased = false;

  @override
  void initState() {
    super.initState();
    _from = widget.value;
  }

  @override
  void didUpdateWidget(covariant CountUpNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = old.value;
      _increased = widget.value > old.value;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (widget.compact && v.abs() >= 1000) {
      final k = v / 1000;
      final text = k % 1 == 0
          ? '${k.toInt()}'
          : k.toStringAsFixed(1).replaceAll('.', _separator);
      return '$text${widget.thousandSuffix}';
    }
    final text = v.toStringAsFixed(widget.fractionDigits);
    if (widget.fractionDigits == 0) return text;
    return text.replaceAll('.', _separator);
  }

  /// Запятая как разделитель там, где так принято (ru/de/fr/es/it/pt).
  String get _separator =>
      Localizations.localeOf(context).languageCode == 'en' ? '.' : ',';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        if (!_c.isAnimating) {
          return Text(_format(widget.value), maxLines: 1, style: widget.style);
        }
        final t = _c.value;
        final e = Curves.easeOut.transform(t);
        final shown = _from + (widget.value - _from) * e;
        final pop = 1 + (_increased ? 0.16 : 0.05) * math.sin(t * math.pi);
        return Transform.scale(
          scale: pop,
          child: Text(_format(shown), maxLines: 1, style: widget.style),
        );
      },
    );
  }
}
