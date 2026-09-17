import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/services/ads.dart';

/// Блоки РСЯ у приложений РАЗНЫЕ, и перепутать их значит слить чужую
/// статистику и, хуже того, показывать рекламу под чужой площадкой.
/// Android — приложение 20059555, iOS — 20060054 (заведено 16.09.2026).
void main() {
  group('блоки по платформе', () {
    test('Android берёт свои блоки', () {
      expect(Ads.unit(AdSpot.homeTop, ios: false, debug: false),
          'R-M-20059555-1');
      expect(Ads.rewardedUnitFor(ios: false, debug: false), 'R-M-20059555-2');
    });

    test('iPhone берёт свои', () {
      expect(Ads.unit(AdSpot.ledger, ios: true, debug: false),
          'R-M-20060054-1');
      expect(Ads.rewardedUnitFor(ios: true, debug: false), 'R-M-20060054-2');
    });

    test('Отладочная сборка показывает демо, а не боевые блоки', () {
      // Свои показы на эмуляторе портят статистику, а за накрутку площадку
      // отключают.
      expect(Ads.unit(AdSpot.stats, ios: false, debug: true),
          startsWith('demo-'));
      expect(Ads.rewardedUnitFor(ios: true, debug: true), startsWith('demo-'));
    });

    test('Все пять мест знают свой блок', () {
      for (final spot in AdSpot.values) {
        expect(Ads.unit(spot, ios: false, debug: false), isNotEmpty);
        expect(Ads.unit(spot, ios: true, debug: false), isNotEmpty);
      }
    });
  });
}
