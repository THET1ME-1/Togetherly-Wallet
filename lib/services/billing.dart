import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../logic/plus.dart';
import 'plus.dart';
import 'session.dart';

/// Покупка подписки в магазине: Google Play и App Store.
///
/// Чек проверяет СЕРВЕР, а не приложение: до 26 июля 2026 в Togetherly сервер
/// верил клиенту, и выдуманный токен открывал платное даром. Здесь телефон
/// только приносит чек, а срок подписки приходит обратно с сервера.
///
/// Сборки RuStore и GitHub сюда не заходят вовсе: у них своя касса — lava
/// (`PlusService.checkout`).
class Billing {
  Billing({required this.session, required this.plus});

  final Session session;
  final PlusService plus;

  /// У Google подписка ОДНА, а тарифы внутри неё базовыми планами; у Apple
  /// три отдельных товара. Перепутать значит продать не тот срок.
  static const _play = 'wallet_plus';
  static const _apple = <PlusPlan, String>{
    PlusPlan.month: 'wallet_plus_p1m',
    PlusPlan.quarter: 'wallet_plus_p3m',
    PlusPlan.year: 'wallet_plus_p1y',
  };
  static const _basePlans = <PlusPlan, String>{
    PlusPlan.month: 'p1m',
    PlusPlan.quarter: 'p3m',
    PlusPlan.year: 'p1y',
  };

  static String productFor(PlusPlan plan, {required bool ios}) =>
      ios ? (_apple[plan] ?? _apple[PlusPlan.month]!) : _play;

  static String basePlanFor(PlusPlan plan) =>
      _basePlans[plan] ?? _basePlans[PlusPlan.month]!;

  /// Какой тариф купили. Чужой товар подпиской не считается.
  static PlusPlan? planOf(String product) {
    for (final entry in _apple.entries) {
      if (entry.value == product) return entry.key;
    }
    return null;
  }

  static bool get supported =>
      !kIsTest && (Platform.isAndroid || Platform.isIOS);

  static bool get kIsTest => Platform.environment.containsKey('FLUTTER_TEST');

  static bool get _ios => !kIsTest && Platform.isIOS;

  StreamSubscription<List<PurchaseDetails>>? _stream;

  /// Тариф, который сейчас покупают: Google в ответе его не называет, а
  /// серверу надо знать, на сколько продлевать.
  PlusPlan _pending = PlusPlan.month;

  /// Слушать магазин. Покупка приходит сюда и когда её совершили только что,
  /// и когда она восстановлена или доплачена позже.
  void listen() {
    if (!supported || _stream != null) return;
    _stream = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (_) {},
    );
  }

  Future<void> stop() async {
    await _stream?.cancel();
    _stream = null;
  }

  /// Купить тариф. Возвращает пусто при удаче и причину словом при отказе.
  Future<String> buy(PlusPlan plan) async {
    if (!supported) return 'no_store';
    final ready = await InAppPurchase.instance.isAvailable();
    if (!ready) return 'no_store';

    _pending = plan;
    final product = productFor(plan, ios: _ios);
    final found = await InAppPurchase.instance.queryProductDetails({product});
    if (found.productDetails.isEmpty) return 'no_product';

    // У Google один товар на три тарифа, и плагин отдаёт ОТДЕЛЬНУЮ запись на
    // каждый базовый план. Берём ту, где нужный план: без этого человек купил
    // бы месяц вместо года.
    if (!_ios) {
      final wanted = basePlanFor(plan);
      GooglePlayProductDetails? mine;
      for (final item in found.productDetails) {
        if (item is! GooglePlayProductDetails) continue;
        final offers = item.productDetails.subscriptionOfferDetails ?? const [];
        final at = item.subscriptionIndex;
        if (at == null || at >= offers.length) continue;
        if (offers[at].basePlanId == wanted) {
          mine = item;
          break;
        }
      }
      if (mine == null) return 'no_plan';
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: GooglePlayPurchaseParam(productDetails: mine),
      );
      return '';
    }

    await InAppPurchase.instance.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: found.productDetails.first),
    );
    return '';
  }

  /// Цены ИЗ МАГАЗИНА, а не наши.
  ///
  /// Google и Apple показывают человеку свою цену в его валюте и со своими
  /// налогами: наши «799 ₽» в Польше или Казахстане были бы неправдой, а
  /// Apple за расхождение витрины с магазином отправляет на доработку.
  Future<Map<PlusPlan, String>> prices() async {
    if (!supported) return const {};
    final out = <PlusPlan, String>{};
    try {
      if (!await InAppPurchase.instance.isAvailable()) return const {};
      final ids = _ios
          ? _apple.values.toSet()
          : <String>{_play};
      final found = await InAppPurchase.instance.queryProductDetails(ids);
      for (final item in found.productDetails) {
        if (_ios) {
          final plan = planOf(item.id);
          if (plan != null) out[plan] = item.price;
          continue;
        }
        if (item is! GooglePlayProductDetails) continue;
        final offers = item.productDetails.subscriptionOfferDetails ?? const [];
        final at = item.subscriptionIndex;
        if (at == null || at >= offers.length) continue;
        final base = offers[at].basePlanId;
        for (final entry in _basePlans.entries) {
          if (entry.value == base) out[entry.key] = item.price;
        }
      }
    } catch (_) {
      return out;
    }
    return out;
  }

  /// Вернуть покупку: человек сменил телефон или переустановил приложение.
  Future<void> restore() async {
    if (!supported) return;
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _tell(purchase);
      }
      // Завершить покупку обязаны МЫ, иначе магазин вернёт деньги через
      // трое суток, считая, что товар не доставлен.
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  /// Отнести чек серверу. Срок подписки решает он.
  Future<void> _tell(PurchaseDetails purchase) async {
    final plan = planOf(purchase.productID) ?? _pending;
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return;
    try {
      await session.post(
        _ios ? '/api/money/plus/apple' : '/api/money/plus/play',
        {'token': token, 'plan': plan.code, 'seat_uid': plus.seatUid},
      );
      await plus.refresh();
    } on SessionError {
      // Сервер не принял чек: подписка не откроется, и это правильно —
      // отказ приходит от того, кто чек проверил, а не от телефона.
    }
  }
}
