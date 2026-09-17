import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/scatter.dart';

void main() {
  const big = Size(370, 450);
  const narrow = Size(96, 180);

  List<ScatterMark> marks(Size size, {int seed = 12345, int kinds = 4}) =>
      scatterMarks(seed: seed, size: size, kinds: kinds);

  group('ассорти знаков', () {
    test('знаки НЕ накладываются и не касаются', () {
      final all = marks(big);
      expect(all.length, greaterThan(12));
      for (var i = 0; i < all.length; i++) {
        for (var j = i + 1; j < all.length; j++) {
          final d = (all[i].center - all[j].center).distance;
          expect(
            d,
            greaterThanOrEqualTo(all[i].radius + all[j].radius),
            reason: 'знаки $i и $j задевают друг друга',
          );
        }
      }
    });

    test('заполнено ВСЁ пространство, а не один угол', () {
      final all = marks(big);
      // Считаем знаки по четвертям: «в одном углу кучно, в другом пусто» —
      // прямое замечание человека, и оно не должно вернуться.
      final quarters = List.filled(4, 0);
      for (final m in all) {
        final right = m.center.dx > big.width / 2 ? 1 : 0;
        final down = m.center.dy > big.height / 2 ? 2 : 0;
        quarters[right + down]++;
      }
      for (var q = 0; q < 4; q++) {
        expect(quarters[q], greaterThan(2), reason: 'четверть $q пустует');
      }
      // Ни одна четверть не забирает себе половину знаков.
      expect(quarters.reduce(math.max), lessThan(all.length * 0.5));
    });

    test('размеры РАЗНЫЕ, и крупные знаки есть', () {
      final all = marks(big);
      final sides = all.map((m) => m.glyph).toList()..sort();
      final short = big.shortestSide;

      // Крупный знак — не меньше трети короткой стороны: «где крупные иконки?
      // КАК были изначально крупные».
      expect(sides.last, greaterThan(short * 0.35));
      // И при этом есть заметно мельче — иначе фактура читается плиткой.
      expect(sides.first, lessThan(short * 0.25));
      expect(sides.toSet().length, greaterThan(8));
    });

    test('развороты идут на полный оборот', () {
      final all = marks(big);
      final turns = all.map((m) => m.turn).toList();
      expect(turns.every((t) => t >= 0 && t <= math.pi * 2), isTrue);
      // Знаки повёрнуты во все стороны, а не наклонены все в одну.
      expect(turns.any((t) => t < math.pi / 2), isTrue);
      expect(turns.any((t) => t > math.pi * 1.5), isTrue);
    });

    test('набор знаков расходуется весь', () {
      final all = marks(big, kinds: 4);
      expect(all.map((m) => m.icon).toSet(), {0, 1, 2, 3});
      expect(all.every((m) => m.icon >= 0 && m.icon < 4), isTrue);
    });

    test('рисунок постоянный между вызовами и свой у каждого семени', () {
      final a = marks(big, seed: 7);
      final b = marks(big, seed: 7);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].center, b[i].center);
        expect(a[i].turn, b[i].turn);
      }
      final other = marks(big, seed: 8);
      expect(other.first.center == a.first.center, isFalse);
    });

    test('в узком квартале знаки тоже есть, и они не мельчат', () {
      final all = marks(narrow);
      expect(all.length, greaterThan(4));
      // Мельче одиннадцати точек знак не рисуется вовсе.
      expect(all.every((m) => m.glyph >= 11), isTrue);
    });

    test('в крошечном кусочке ассорти не рисуется', () {
      expect(marks(const Size(14, 40)), isEmpty);
      expect(scatterMarks(seed: 1, size: big, kinds: 0), isEmpty);
    });
  });
}
