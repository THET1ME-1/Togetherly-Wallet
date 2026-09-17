import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'plus.dart';

/// Где стоит баннер. Место важно не только для приличия, но и для отчёта: у
/// каждого свой блок, и видно, что окупается.
enum AdSpot {
  /// Главная, под балансом и перед счетами.
  homeTop,

  /// Главная, ниже, у кварталов категорий.
  homeLower,

  /// Лента транзакций, строкой после первого дня.
  ledger,

  /// Категории, под кольцом и перед списком.
  categories,

  /// Статистика, после первого графика.
  stats,
}

/// Реклама Яндекса.
///
/// Только РСЯ, без AdMob: у Google в России показов почти нет (за тридцать
/// дней он налил 2% объёма против 98% у Яндекса), а водопад из двух сетей
/// ради этого стоил бы второго SDK в сборке.
///
/// Подписчикам рекламы НЕТ ВООБЩЕ. Это не щедрость, а смысл подписки: человек
/// платит за приложение, которое не торгует его вниманием, и баннер под
/// балансом у платящего читался бы обманом.
class Ads extends ChangeNotifier {
  Ads({required this.plus}) {
    plus.addListener(notifyListeners);
  }

  final PlusService plus;

  /// Блоки заведены 16.09.2026. Приложения в кабинете РСЯ РАЗНЫЕ:
  /// Android `20059555`, iOS `20060054`. Перепутать их значит слить
  /// статистику и показывать рекламу под чужой площадкой.
  static const _android = (banner: 'R-M-20059555-1', rewarded: 'R-M-20059555-2');
  static const _ios = (banner: 'R-M-20060054-1', rewarded: 'R-M-20060054-2');

  /// Блок для места. Своих блоков на каждое место пока нет, все пять ходят в
  /// один баннерный: заведутся новые — меняется только это место.
  static String unit(AdSpot spot, {required bool ios, required bool debug}) =>
      debug ? _demoBanner : (ios ? _ios.banner : _android.banner);

  static String rewardedUnitFor({required bool ios, required bool debug}) =>
      debug ? _demoRewarded : (ios ? _ios.rewarded : _android.rewarded);

  /// Показывать демо-блоки. Отладочная сборка — всегда, релизная — когда её
  /// собрали для проверки (`--dart-define=DEMO_ADS=true`): свои показы и
  /// нажатия Яндекс считает накруткой и за это отключает площадку.
  static const _demoAlways = bool.fromEnvironment('DEMO_ADS');

  static bool get demo => kDebugMode || _demoAlways;

  String unitFor(AdSpot spot) => unit(spot, ios: _isIos, debug: demo);

  bool get _isIos => !kIsTest && Platform.isIOS;

  /// Демонстрационные блоки Яндекса. В отладочной сборке показываем их:
  /// боевые блоки на эмуляторе и на своём телефоне портят статистику, а за
  /// накрутку показов площадку отключают.
  static const _demoBanner = 'demo-banner-yandex';
  static const _demoRewarded = 'demo-rewarded-yandex';

  /// Реклама есть и на iPhone: с 16.09.2026 у него своё приложение в РСЯ.
  static bool get supported => !kIsTest && (Platform.isAndroid || Platform.isIOS);

  /// В тестах каналов к платформе нет.
  static bool get kIsTest => Platform.environment.containsKey('FLUTTER_TEST');

  bool _ready = false;

  /// Показывать ли рекламу этому человеку прямо сейчас.
  bool get show => supported && !plus.active;

  String get rewardedUnit => rewardedUnitFor(ios: _isIos, debug: demo);

  /// Показать ролик за вопрос. Возвращает `true`, если человек досмотрел.
  ///
  /// Награду начисляет СЕРВЕР по отдельному запросу: здесь только показ.
  /// Телефон, который сам решает, что заслужил, — это бесплатная модель для
  /// любого, кто умеет повторить запрос.
  Future<bool> showRewarded() async {
    if (!supported) return false;
    await init();
    if (!_ready) return false;
    var earned = false;
    try {
      final loader = RewardedAdLoader();
      final ad = await loader.loadAd(
        adRequest: AdRequest(adUnitId: rewardedUnit),
      );
      final done = Completer<void>();
      ad.setAdEventListener(
        eventListener: RewardedAdEventListener(
          onRewarded: (_) => earned = true,
          onAdDismissed: () {
            if (!done.isCompleted) done.complete();
          },
          onAdFailedToShow: (_) {
            if (!done.isCompleted) done.complete();
          },
        ),
      );
      await ad.show();
      await done.future;
      await ad.destroy();
    } catch (_) {
      // Ролика нет или сеть молчит — человек ничего не теряет, кнопка просто
      // не сработала.
      return false;
    }
    return earned;
  }

  Future<void> init() async {
    if (!supported || _ready) return;
    try {
      await YandexAds.initialize();
      _ready = true;
    } catch (_) {
      // SDK не поднялся — приложение работает дальше без рекламы.
      _ready = false;
    }
  }

  @override
  void dispose() {
    plus.removeListener(notifyListeners);
    super.dispose();
  }
}
