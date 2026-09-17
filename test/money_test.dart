import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/ui/money.dart';

void main() {
  group('формат', () {
    test('копейки стоят всегда, даже нулевые', () {
      // «128 640» читается как округление, а округление в деньгах — это
      // чужая сумма. Правило заказчика: 17,00 и 14,67, копейки везде.
      expect(const Money(12864000).format(), '128 640,00 ₽');
    });

    test('копейки показаны, когда есть', () {
      expect(const Money(1480).format(), '14,80 ₽');
    });

    test('минус типографский, а не дефис', () {
      expect(const Money(-148000).format().startsWith('−'), isTrue);
    });

    test('валюта пары, а не всегда рубль', () {
      expect(const Money(100000, currency: 'MDL').format(), '1 000,00 L');
      expect(const Money(100000, currency: 'EUR').format(), '1 000,00 €');
    });
  });

  group('дележ', () {
    test('сумма долей равна сумме операции до копейки', () {
      for (final total in [148000, 10001, 99, 7, 123456789]) {
        for (final shares in [
          [5000, 5000],
          [6000, 4000],
          [7400, 2600],
          [3334, 3333, 3333],
        ]) {
          final parts = Money.split(total, shares);
          expect(parts.fold<int>(0, (a, b) => a + b), total,
              reason: 'total=$total shares=$shares');
        }
      }
    });

    test('остаток достаётся плательщику', () {
      expect(Money.split(10001, [5000, 5000]), [5001, 5000]);
      expect(Money.split(10001, [5000, 5000], payerIndex: 1), [5000, 5001]);
    });

    test('кривые доли отвергаются и в релизе, а не только ассертом', () {
      expect(() => Money.split(100, [5000, 4000]), throwsArgumentError);
      expect(() => Money.split(100, []), throwsArgumentError);
      expect(() => Money.split(100, [10000], payerIndex: 3), throwsRangeError);
    });
  });

  group('арифметика', () {
    test('складываются только одинаковые валюты', () {
      expect((const Money(100) + const Money(50)).minor, 150);
      expect(() => const Money(100, currency: 'MDL') + const Money(50, currency: 'EUR'),
          throwsArgumentError);
    });
  });
}
