import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/card_brands.dart';

void main() {
  group('порядок платёжных систем', () {
    test('в Молдове первыми Visa и Mastercard, МИР последним', () {
      final list = brandsFor('MD');
      expect(list.first, CardBrand.none);
      expect(list[1], CardBrand.visa);
      expect(list[2], CardBrand.mastercard);
      expect(list.last, CardBrand.mir);
    });

    test('в России МИР сразу за «без системы»', () {
      expect(brandsFor('RU')[1], CardBrand.mir);
      expect(brandsFor('BY')[1], CardBrand.mir);
      expect(brandsFor('KZ')[1], CardBrand.mir);
    });

    test('в Китае первым UnionPay', () {
      expect(brandsFor('CN')[1], CardBrand.unionpay);
    });

    test('в Штатах Amex стоит третьим, а не в хвосте', () {
      expect(brandsFor('US')[3], CardBrand.amex);
    });

    test('ничего не прячется: систем всегда столько же', () {
      // Карту могли привезти откуда угодно, и человек с Amex в Кишинёве не
      // должен упираться в стену.
      for (final code in ['MD', 'RU', 'CN', 'US', 'ZZ', null]) {
        expect(brandsFor(code).toSet(), CardBrand.values.toSet());
      }
    });

    test('незнакомая страна даёт европейский порядок', () {
      expect(brandsFor('ZZ'), brandsFor('MD'));
      expect(brandsFor(null), brandsFor('MD'));
    });
  });
}
