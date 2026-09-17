/// Ритм, радиусы, длительности. Шаг сетки — 4.
abstract final class TmSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0; // поля экрана
  static const xxl = 24.0;
  static const huge = 32.0;
}

abstract final class TmRadius {
  static const chip = 14.0;
  static const field = 18.0;
  static const row = 20.0;
  static const tile = 22.0;
  static const section = 24.0;
  static const card = 28.0;
  static const sheet = 36.0;
  static const pill = 999.0;
}

abstract final class TmDur {
  static const tap = Duration(milliseconds: 120);
  static const swap = Duration(milliseconds: 300);
}

/// Минимальная высота тапа. Ниже не опускаться никогда.
const double kTmMinTap = 44.0;
