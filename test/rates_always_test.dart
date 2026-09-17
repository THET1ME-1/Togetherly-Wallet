import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/currencies.dart';
import 'package:togetherly_money/logic/money.dart';

void main() {
  group('курс есть всегда', () {
    test('без своей таблицы берётся встроенный, а не единица', () {
      const db = Database(baseCurrency: 'MDL');
      // Доллар дороже лея в разы — приложение не имеет права считать их равными.
      expect(rateOf(db, 'USD'), greaterThan(10));
      expect(rateOf(db, 'EUR'), greaterThan(rateOf(db, 'USD')));
    });

    test('свой курс сильнее встроенного', () {
      const db = Database(baseCurrency: 'MDL', rates: {'USD': 20});
      expect(rateOf(db, 'USD'), 20);
    });

    test('база считается через доллар в любую сторону', () {
      const rub = Database(baseCurrency: 'RUB');
      // Лей в рублях — единицы рублей, а не тысячи и не единица.
      final mdl = rateOf(rub, 'MDL');
      expect(mdl, greaterThan(1));
      expect(mdl, lessThan(20));
    });

    test('незнакомая валюта остаётся единицей', () {
      const db = Database(baseCurrency: 'MDL');
      expect(rateOf(db, 'ZZZ'), 1);
      expect(fallbackRate('ZZZ', 'MDL'), 0);
    });

    test('в таблице есть все ходовые валюты справочника', () {
      final missing = currencyTable.keys
          .where((c) => c != 'XAU' && c != 'BTC' && c != 'USDT')
          .where((c) => (usdPrice[c] ?? 0) <= 0)
          .toList();
      expect(missing, isEmpty, reason: 'без курса: ${missing.join(', ')}');
    });
  });
}
