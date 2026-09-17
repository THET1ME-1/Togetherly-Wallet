import 'dart:math' as math;
import 'dart:ui';

/// Один знак ассорти: где стоит, какой величины, как повёрнут и который из
/// набора.
class ScatterMark {
  const ScatterMark({
    required this.center,
    required this.radius,
    required this.glyph,
    required this.turn,
    required this.icon,
  });

  /// Середина знака. Может лежать чуть за кромкой: ассорти доходит до краёв.
  final Offset center;

  /// Круг, которым знак держит дистанцию от соседей.
  final double radius;

  /// Сторона знака в точках.
  final double glyph;

  /// Разворот в радианах, полный оборот.
  final double turn;

  /// Номер знака в наборе.
  final int icon;
}

/// Готовые раскладки: ключ — семя, размер квартала с точностью до восьми
/// точек и число знаков в наборе.
///
/// Без кэша укладка считалась бы на каждом кадре переезда кварталов: бросков
/// там сотни, и анимация начинала спотыкаться.
final _packed = <String, List<ScatterMark>>{};

/// Ассорти знаков по всей площади.
///
/// Понятий «строка» и «столбик» здесь нет: каждый знак бросается в свободное
/// место и остаётся там, если не задел уже стоящих. Требование человека —
/// «АССОРТИ, а не ряд иконок в одну строку»; сетка со сдвигом, которая стояла
/// тут раньше, читалась обоями из плитки.
List<ScatterMark> scatterMarks({
  required int seed,
  required Size size,
  required int kinds,
  double scale = 1,
}) {
  if (kinds <= 0 || size.shortestSide < 18) return const [];
  final key = '$seed|${(size.width / 8).round()}|'
      '${(size.height / 8).round()}|$kinds|${(scale * 100).round()}';
  final ready = _packed[key];
  if (ready != null) return ready;

  // Кварталов на экране единицы, отрезков пять, категорий десятки — расти
  // кэшу дальше некуда, но подстраховка дешевле утечки.
  if (_packed.length > 240) _packed.clear();
  final made = _pack(seed, size, kinds, scale);
  _packed[key] = made;
  return made;
}

/// Укладка: крупные знаки бросаются первыми, каждый следующий встаёт только
/// туда, где не задевает уже стоящих.
///
/// Позиции берутся из последовательности Холтона, а не из обычного случая:
/// случайные точки сбиваются в кучу в одном углу и оставляют пустым другой —
/// ровно то, за что человек ругал первую версию. Холтон покрывает площадь
/// равномерно, оставаясь при этом не сеткой.
List<ScatterMark> _pack(int seed, Size size, int kinds, double scale) {
  final short = size.shortestSide;
  final out = <ScatterMark>[];

  // Четыре яруса величины. Крупные идут первыми и задают лицо квартала,
  // последний ярус заполняет щели между ними: без него ассорти дышало пустыми
  // пятнами. «Оставь крупные и средние» относилось к версии, где ВСЕ знаки
  // были мелкими, — крупные там пропали вовсе.
  const tiers = [
    (side: 0.46, cover: 0.34),
    (side: 0.31, cover: 0.30),
    (side: 0.21, cover: 0.26),
    (side: 0.14, cover: 0.22),
  ];
  // Зазор узкий: знаки не касаются, но и полей между ними нет — «почему ты
  // боишься заполнить всё пространство» сказано про первую версию.
  final gap = math.max(1.5, short * 0.016 * scale);
  var step = 0;

  for (var t = 0; t < tiers.length; t++) {
    final tier = tiers[t];
    // Масштаб меньше единицы делает знаки мельче, а их — больше: у фона
    // экрана площадь вчетверо больше квартала, и знаки размером в квартал
    // перетягивали бы на себя внимание с полей ввода.
    final glyph = short * tier.side * scale;
    // Знак мельче одиннадцати точек читается сором, а не знаком.
    if (glyph < 11) continue;

    final spread = _noise(seed, t, 11);
    final want = (size.width * size.height * tier.cover /
            (math.pi * math.pow(glyph * 0.5 + gap / 2, 2)))
        .round()
        // Потолок высокий: фон целого экрана держит сотни мелких знаков, а
        // квартал упирается в площадь сам.
        .clamp(1, 260);

    var placed = 0;
    var tries = 0;
    // Бросков заметно больше, чем знаков: место ищется, пока находится.
    // Случайная укладка кругов насыщается около 55% площади, поэтому щелям
    // нужны сотни попыток, а не десятки.
    while (placed < want && tries < want * 34 + 120) {
      step++;
      tries++;
      // Свой размер у каждого знака: ярус задаёт величину, разброс внутри
      // яруса не даёт фактуре стать плиткой.
      final jitter = 0.86 + _noise(seed, step, 5) * 0.30;
      final side = glyph * jitter;
      // Глиф занимает не всю строку кегля: круг считается от его настоящей
      // ширины, иначе круги раздуваются и укладка редеет.
      final r = side * 0.5 + gap / 2;

      // Центры выходят за кромку не больше чем на треть радиуса: ассорти
      // должно доходить до краёв, но половинки знаков по всему периметру
      // выглядели обрезанной фактурой.
      final edge = r * 0.34;
      final u = _frac(_halton(step, 2) + spread);
      final v = _frac(_halton(step, 3) + spread * 0.7);
      final c = Offset(
        -edge + u * (size.width + edge * 2),
        -edge + v * (size.height + edge * 2),
      );

      var free = true;
      for (final b in out) {
        if ((b.center - c).distance < b.radius + r) {
          free = false;
          break;
        }
      }
      if (!free) continue;

      out.add(ScatterMark(
        center: c,
        radius: r,
        glyph: side,
        // Разворот на ПОЛНЫЙ оборот: у ассорти нет верха, и знаки,
        // наклонённые все в одну сторону, снова читаются как узор.
        turn: _noise(seed, step, 7) * math.pi * 2,
        icon: (_noise(seed, step, 13) * kinds).floor() % kinds,
      ));
      placed++;
    }
  }
  return out;
}

/// Псевдослучайное 0..1 от трёх чисел. Своё, а не `Random`: важна
/// повторяемость без хранения состояния — иначе фон дёргался бы на каждом
/// кадре анимации.
double _noise(int a, int b, int salt) {
  var h = a * 374761393 + b * 668265263 + salt * 3266489917;
  h = (h ^ (h >> 13)) * 1274126177;
  h = h ^ (h >> 16);
  return (h & 0xFFFF) / 0xFFFF;
}

/// Последовательность Холтона: равномерное покрытие без сетки.
double _halton(int index, int base) {
  var result = 0.0, f = 1.0, i = index + 1;
  while (i > 0) {
    f /= base;
    result += f * (i % base);
    i ~/= base;
  }
  return result;
}

double _frac(double v) => v - v.floorToDouble();
