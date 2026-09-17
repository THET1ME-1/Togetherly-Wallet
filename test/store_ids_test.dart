import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/services/billing.dart';

/// Идентификаторы товаров в магазинах РАЗНЫЕ, и перепутать их значит продать
/// не тот срок или не продать ничего. У Google подписка одна с тремя базовыми
/// планами, у Apple — три отдельных товара (заведены 16.09.2026).
void main() {
  group('товары магазинов', () {
    test('У Google одна подписка на все тарифы', () {
      for (final plan in PlusPlan.values) {
        expect(Billing.productFor(plan, ios: false), 'wallet_plus');
      }
    });

    test('Базовый план Google свой у каждого тарифа', () {
      expect(Billing.basePlanFor(PlusPlan.month), 'p1m');
      expect(Billing.basePlanFor(PlusPlan.quarter), 'p3m');
      expect(Billing.basePlanFor(PlusPlan.year), 'p1y');
    });

    test('У Apple три отдельных товара', () {
      expect(Billing.productFor(PlusPlan.month, ios: true), 'wallet_plus_p1m');
      expect(Billing.productFor(PlusPlan.quarter, ios: true), 'wallet_plus_p3m');
      expect(Billing.productFor(PlusPlan.year, ios: true), 'wallet_plus_p1y');
    });

    test('Тариф узнаётся обратно по товару', () {
      expect(Billing.planOf('wallet_plus_p1y'), PlusPlan.year);
      expect(Billing.planOf('wallet_plus_p3m'), PlusPlan.quarter);
      // Чужой товар не притворяется подпиской.
      expect(Billing.planOf('coins_10'), isNull);
    });
  });
}
