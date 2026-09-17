import 'package:flutter/widgets.dart';

/// Unbounded — суммы и заголовки. Onest — весь интерфейсный текст.
/// Третьего шрифта в продукте нет.
///
/// Шрифты подшиты в assets и переменные: вес задаётся ОСЬЮ `wght`, а не только
/// `fontWeight`. Один `fontWeight` на переменном файле не меняет начертание —
/// текст остаётся в дефолтном 400, и вся типографика схлопывается в один вес.
///
/// Цвет у стилей необязательный. Не передан — текст наследует цвет темы
/// (`onSurface`), поэтому тёмная тема работает сама. Раньше здесь стоял
/// дефолт `TmColors.ink`, и на тёмном фоне он давал контраст 1.2:1.
abstract final class TmText {
  static const _display = 'Unbounded';
  static const _bodyFamily = 'Onest';

  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static TextStyle _d({
    required double size,
    required double height,
    required int weight,
    double? tracking,
    Color? color,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        height: height,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        letterSpacing: tracking,
        color: color,
        fontFeatures: tabular ? _tabular : null,
      );

  static TextStyle _b({
    required double size,
    required double height,
    required int weight,
    double? tracking,
    Color? color,
  }) =>
      TextStyle(
        fontFamily: _bodyFamily,
        fontSize: size,
        height: height,
        fontWeight: FontWeight.values[(weight ~/ 100) - 1],
        fontVariations: [FontVariation('wght', weight.toDouble())],
        letterSpacing: tracking,
        color: color,
      );

  // Суммы. Всегда табличные цифры — иначе прыгают при живом обновлении.
  static TextStyle balanceXxl([Color? c]) =>
      _d(size: 36, height: 1.0, weight: 500, tracking: -1.08, color: c, tabular: true);

  static TextStyle balanceXl([Color? c]) =>
      _d(size: 30, height: 1.0, weight: 500, tracking: -0.9, color: c, tabular: true);

  static TextStyle amount([Color? c]) =>
      _d(size: 16, height: 1.0, weight: 500, color: c, tabular: true);

  static TextStyle amountRow([Color? c]) =>
      _d(size: 13.5, height: 1.0, weight: 500, color: c, tabular: true);

  static TextStyle titleLg([Color? c]) =>
      _d(size: 28, height: 1.1, weight: 400, tracking: -0.56, color: c);

  static TextStyle titleDisplay([Color? c]) =>
      _d(size: 20, height: 1.2, weight: 400, tracking: -0.4, color: c);

  static TextStyle titleMd([Color? c]) => _b(size: 17, height: 1.2, weight: 600, color: c);

  static TextStyle navTitle([Color? c]) => _b(size: 16, height: 1.0, weight: 600, color: c);

  static TextStyle body([Color? c]) => _b(size: 15, height: 1.5, weight: 400, color: c);

  static TextStyle rowTitle([Color? c]) => _b(size: 14, height: 1.2, weight: 500, color: c);

  static TextStyle label([Color? c]) => _b(size: 13, height: 1.35, weight: 500, color: c);

  static TextStyle meta([Color? c]) => _b(size: 11.5, height: 1.2, weight: 400, color: c);

  static TextStyle button([Color? c]) => _b(size: 15, height: 1.0, weight: 600, color: c);

  /// Служебный заголовок группы: 11px, +10% трекинг, капс.
  static TextStyle eyebrow([Color? c]) =>
      _b(size: 11, height: 1.0, weight: 500, tracking: 1.1, color: c);
}
