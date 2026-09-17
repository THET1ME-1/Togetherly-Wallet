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

/// Токен устройства для пушей: FCM на Android, APNs на iPhone.
///
/// Плагин `firebase_messaging` намеренно не подключён — то же решение, что в
/// Togetherly: на iOS он перехватывает делегата APNs через swizzling, и потом
/// не разобраться, кто съел уведомление. Поэтому каждая платформа отдаёт
/// токен своим мостом: `MoneyFcm.kt` каналом `money/fcm`, `AppDelegate.swift`
/// каналом `money/push`.
///
/// На iPhone второй системы доставки НЕТ и быть не может: фоновый сервис с
/// живым каналом — приём Android. Пока APNs не подключён, уведомление о
/// записи партнёра приходило бы ровно тогда, когда человек и так смотрит в
/// приложение, то есть никогда (17.09.2026).
///
/// Токен уезжает в СВОЮ таблицу (`money_devices`), а не в `users.fcm_token`:
/// та колонка принадлежит Togetherly, приложения два и токены у них разные —
/// записав свой туда, Money увёл бы чужие уведомления себе.
class Push extends ChangeNotifier {
  Push({MethodChannel? channel, bool? onAndroid, bool? onApple})
      // Платформа приходит параметром, чтобы её можно было подставить в
      // тесте: иначе проверить доставку можно только на телефоне.
      : onAndroid = onAndroid ?? Platform.isAndroid,
        onApple = onApple ?? Platform.isIOS,
        _channel = channel ??
            ((onApple ?? Platform.isIOS)
                ? const MethodChannel('money/push')
                : const MethodChannel('money/fcm'));

  final MethodChannel _channel;
  final bool onAndroid;
  final bool onApple;

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
    if (!onAndroid && !onApple) {
      _settled = true;
      notifyListeners();
      return;
    }
    var platform = 'android';
    try {
      if (onApple) {
        // Токен может приехать ПОЗЖЕ ответа: человек думает над разрешением, а
        // Apple отвечает своим темпом. Мост толкает его сюда сам.
        _channel.setMethodCallHandler((call) async {
          if (call.method != 'token') return null;
          final late = (call.arguments as String?) ?? '';
          if (late.isEmpty || late == _token) return null;
          _token = late;
          _hasServices = true;
          notifyListeners();
          await _remember(session, late);
          return null;
        });
        // Разрешение спрашивает сам мост; отказ отдаёт пустой токен, и это не
        // ошибка — приложение работает, просто молча.
        _token = await _channel.invokeMethod<String>('register');
        final sandbox = await _channel.invokeMethod<bool>('sandbox') ?? false;
        // Токен отладочной сборки живёт в песочнице Apple, и в боевой APNs он
        // не годится: сервер разводит их по этой пометке.
        platform = sandbox ? 'ios_sandbox' : 'ios';
        _hasServices = (_token ?? '').isNotEmpty;
      } else {
        _hasServices = await _channel.invokeMethod<bool>('hasServices') ?? false;
        if (_hasServices) {
          _token = await _channel.invokeMethod<String>('getToken');
        }
      }
    } on PlatformException catch (e) {
      debugPrint('пуши: телефон не ответил ($e)');
    } on MissingPluginException {
      // Тесты и десктоп: канала нет, и это не ошибка.
    }
    _settled = true;
    notifyListeners();

    _platform = platform;
    final token = _token;
    if (token == null || token.isEmpty) return;
    await _remember(session, token);
  }

  /// Чем помечено это устройство на сервере: по пометке он выбирает, куда
  /// слать — в FCM, в боевой APNs или в песочницу Apple.
  String _platform = 'android';

  Future<void> _remember(Session session, String token) async {
    if (!session.signedIn) return;
    try {
      await session.post('/api/money/device', {
        'token': token,
        'platform': _platform,
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
