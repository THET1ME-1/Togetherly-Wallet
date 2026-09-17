import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/strings.dart';

/// Уведомления БЕЗ сервисов Google.
///
/// Вторая система доставки, независимая от FCM: событие приходит живым каналом
/// (Centrifugo), а уведомление приложение поднимает само. Работает там, где
/// пушей не будет никогда — прошивки без сервисов Google, телефоны, с которых
/// не приехал токен.
///
/// Текст такой же нейтральный, как у пуша: «есть новая запись», без суммы и
/// категории. На экране блокировки деньги показывать нечего.
class LocalPush {
  LocalPush({FlutterLocalNotificationsPlugin? plugin})
      : _ln = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _ln;

  static const _channelId = 'money_partner';
  static String get _channelName => tr('pushChannelName');
  static String get _channelDescription => tr('pushChannelNote');

  bool _inited = false;

  /// Один и тот же номер: новое уведомление заменяет прежнее в шторке, а не
  /// копится десятком одинаковых баннеров.
  static const _id = 41;

  Future<void> init() async {
    if (_inited || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await _ln.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          // Разрешение на iOS спрашивает нативный мост вместе с
          // регистрацией в APNs (`AppDelegate.swift`): два источника одного
          // запроса — верный способ показать человеку системное окно дважды
          // и получить отказ.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final android = _ln.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ));
      // С Android 13 разрешение спрашивается у человека. Отказ — не ошибка:
      // приложение работает, просто молча.
      await android?.requestNotificationsPermission();
      _inited = true;
    } catch (e) {
      debugPrint('local notifications: init failed ($e)');
    }
  }

  /// Партнёр что-то записал.
  Future<void> partnerWrote({String? name}) async {
    if (!_inited) await init();
    if (!_inited) return;
    final who = (name ?? '').trim();
    try {
      await _ln.show(
        id: _id,
        title: 'Togetherly Wallet',
        body: who.isEmpty ? tr('pushPartnerWrote') : trf('pushNewFrom', [who]),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('local notifications: show failed ($e)');
    }
  }
}
