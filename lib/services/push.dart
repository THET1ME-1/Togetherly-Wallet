import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'session.dart';

/// Нужен ли запасной путь доставки — тот, что работает без сервисов Google.
///
/// Пуши доходят только там, где есть и сервисы Google, и живой токен: на
/// кастомных прошивках первого нет вовсе, а без токена сервер не знает, куда
/// слать. Остаться без уведомлений хуже, чем держать сокет самому, поэтому в
/// обоих случаях включается вторая система.
bool localDeliveryNeeded({
  required bool hasServices,
  required bool hasToken,
}) =>
    !(hasServices && hasToken);

/// Токен устройства для пушей Google.
///
/// Плагин `firebase_messaging` намеренно не подключён — то же решение, что в
/// Togetherly: на iOS он перехватывает делегата APNs через swizzling, а здесь
/// нужен ровно токен на Android. Поэтому FCM живёт нативно (`MoneyFcm.kt`), а
/// сюда приходит каналом `money/fcm`.
///
/// Токен уезжает в СВОЮ таблицу (`money_devices`), а не в `users.fcm_token`:
/// та колонка принадлежит Togetherly, приложения два и токены у них разные —
/// записав свой туда, Money увёл бы чужие уведомления себе.
class Push extends ChangeNotifier {
  Push({MethodChannel? channel, bool? onAndroid})
      : _channel = channel ?? const MethodChannel('money/fcm'),
        // Платформа приходит параметром, чтобы её можно было подставить в
        // тесте: иначе проверить доставку можно только на телефоне.
        onAndroid = onAndroid ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool onAndroid;

  bool _hasServices = false;
  String? _token;
  bool _settled = false;

  String? get token => _token;

  /// Дойдут ли пуши до этого телефона.
  bool get ready => _hasServices && (_token ?? '').isNotEmpty;

  /// Вердикт вынесен: токен либо приехал, либо уже не приедет. Спрашивать
  /// [ready] раньше бесполезно — на этом в Togetherly висела лишняя строка в
  /// шторке у людей с работающими пушами.
  bool get settled => _settled;

  /// Нужна ли вторая система доставки.
  bool get needsLocal => localDeliveryNeeded(
        hasServices: _hasServices,
        hasToken: (_token ?? '').isNotEmpty,
      );

  /// Спросить телефон и запомнить токен на сервере.
  ///
  /// Зовётся при каждом запуске и после входа: токен меняется сам по себе, и
  /// старый остаётся в таблице мёртвым грузом до первого отказа релея.
  Future<void> start(Session session) async {
    if (!onAndroid) {
      _settled = true;
      notifyListeners();
      return;
    }
    try {
      _hasServices = await _channel.invokeMethod<bool>('hasServices') ?? false;
      if (_hasServices) {
        _token = await _channel.invokeMethod<String>('getToken');
      }
    } on PlatformException catch (e) {
      debugPrint('пуши: телефон не ответил ($e)');
    } on MissingPluginException {
      // Тесты и десктоп: канала нет, и это не ошибка.
    }
    _settled = true;
    notifyListeners();

    final token = _token;
    if (token == null || token.isEmpty || !session.signedIn) return;
    try {
      await session.post('/api/money/device', {
        'token': token,
        'platform': 'android',
      });
    } catch (e) {
      debugPrint('пуши: токен не доехал до сервера ($e)');
    }
  }

  /// Забыть устройство: человек вышел из аккаунта на этом телефоне, и слать
  /// сюда чужие уведомления нельзя.
  Future<void> forget(Session session) async {
    final token = _token;
    if (!session.signedIn) return;
    try {
      await session.post('/api/money/device/forget', {'token': token ?? ''});
    } catch (e) {
      debugPrint('пуши: устройство не забылось ($e)');
    }
  }
}
