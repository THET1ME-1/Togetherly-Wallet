import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/widgets/card_tile.dart';

/// Премиальные оформления карт.
///
/// Главное правило этого списка старше подписки: ПОРЯДОК МЕНЯТЬ НЕЛЬЗЯ. У
/// счёта хранится НОМЕР оформления, и перестановка перекрашивает чужие карты
/// — так уже вышло 13.09.2026, когда голубая «Карта Салют» стала чёрной.
/// Поэтому платные дописаны в конец, а тест сторожит и порядок, и то, что
/// бесплатный набор не поредел.

void main() {
  test('бесплатные оформления остались на своих местах', () {
    // Первые десять — те же и в том же порядке, что были до подписки.
    const free = [
      'designMint',
      'designLavender',
      'designPeach',
      'designSand',
      'designSky',
      'designCoral',
      'designGraphite',
      'designInk',
      'designSteel',
      'designPaper',
    ];
    expect(
      [for (var i = 0; i < free.length; i++) cardDesigns[i].titleKey],
      free,
    );
    for (var i = 0; i < free.length; i++) {
      expect(cardDesigns[i].plus, isFalse, reason: free[i]);
    }
  });

  test('платные дописаны только в конец', () {
    final firstPlus = cardDesigns.indexWhere((d) => d.plus);
    expect(firstPlus, greaterThan(0));
    // После первого платного бесплатных больше нет: иначе новый цвет когда-то
    // вставили в середину, и чужие карты уже перекрашены.
    for (var i = firstPlus; i < cardDesigns.length; i++) {
      expect(cardDesigns[i].plus, isTrue, reason: cardDesigns[i].titleKey);
    }
  });

  test('у платных оформлений буквы читаются на своей заливке', () {
    // Белым по светлой латуни человек не прочитает ни имени счёта, ни
    // четырёх цифр. Контраст считаем по спецификации — тем же способом, что
    // `inkOn` в палитре приложения.
    double channel(int c) {
      final v = c / 255;
      return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    double luminance(Color c) {
      final argb = c.toARGB32();
      return 0.2126 * channel((argb >> 16) & 0xFF) +
          0.7152 * channel((argb >> 8) & 0xFF) +
          0.0722 * channel(argb & 0xFF);
    }

    for (final d in cardDesigns.where((d) => d.plus)) {
      final a = luminance(d.fill);
      final b = luminance(d.ink);
      final hi = a > b ? a : b;
      final lo = a > b ? b : a;
      expect((hi + 0.05) / (lo + 0.05), greaterThan(4.5), reason: d.titleKey);
    }
  });
}
