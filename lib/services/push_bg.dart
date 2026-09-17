import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'live.dart';
import 'local_push.dart';

/// Доставка уведомлений в фоне БЕЗ сервисов Google.
///
/// Вторая система целиком: живой канал пары держится в отдельном изоляте
/// внутри Android foreground-сервиса, и уведомление поднимает само приложение.
/// Нужна там, где пуши не дойдут никогда — прошивки без сервисов Google и
/// телефоны, с которых не приехал токен FCM.
///
/// Где пуши работают, сервис НЕ поднимается: у Android 14 на сервисы типа
/// `dataSync` шесть часов в сутки, после которых система его останавливает, а
/// строка о работе в шторке висит у человека весь день. В Togetherly это уже
/// стоило жалобы со снимком — поэтому решение принимается по вердикту [Push],
/// а не «на всякий случай».
///
/// Запускать только пока приложение НА ПЕРЕДНЕМ ПЛАНЕ: Android 12+ не даёт
/// стартовать foreground-сервис из фона.
///
/// iOS не поддерживается: постоянный фоновый сокет там не выживает.
class PushBg {
  PushBg._();

  static const _kToken = 'money.push.token';
  static const _kGroup = 'money.push.group';
  static const _kUid = 'money.push.uid';
  static const _kName = 'money.push.partner';

  static bool _configured = false;

  static void _configure() {
    if (_configured) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'money_delivery',
        channelName: 'Доставка уведомлений',
        channelDescription:
            'Работает, пока пуши Google недоступны на этом телефоне',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Канал событийный, опрашивать нечего. Раз в минуту будим обработчик
        // сторожем: если подписка не встала (сервис поднялся раньше сети),
        // пробуем снова.
        eventAction: ForegroundTaskEventAction.repeat(60000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _configured = true;
  }

  /// Поднять фоновую доставку. Идемпотентно.
  static Future<void> start({
    required String authToken,
    required String groupId,
    required String myUid,
    String partnerName = '',
  }) async {
    if (!Platform.isAndroid) return;
    if (authToken.isEmpty || groupId.isEmpty || myUid.isEmpty) return;
    _configure();

    await FlutterForegroundTask.saveData(key: _kToken, value: authToken);
    await FlutterForegroundTask.saveData(key: _kGroup, value: groupId);
    await FlutterForegroundTask.saveData(key: _kUid, value: myUid);
    await FlutterForegroundTask.saveData(key: _kName, value: partnerName);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Togetherly Wallet на связи',
      notificationText: 'Ждём записи партнёра',
      callback: startPushIsolate,
    );
  }

  /// Погасить: пуши заработали, человек вышел или пара распалась.
  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.stopService();
  }
}

@pragma('vm:entry-point')
void startPushIsolate() {
  FlutterForegroundTask.setTaskHandler(_PushTask());
}

/// Обработчик в изолате: канал, уведомление, повторная попытка.
///
/// Ни [Session], ни [Sync] здесь нет — только токен и номер группы, поэтому
/// подписку держит [PairChannel], а не [Live].
class _PushTask extends TaskHandler {
  final _local = LocalPush();
  PairChannel? _channel;
  String _uid = '';
  String _name = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _local.init();
    await _connect();
  }

  Future<void> _connect() async {
    if (_channel != null) return;
    final token =
        await FlutterForegroundTask.getData<String>(key: PushBg._kToken) ?? '';
    final group =
        await FlutterForegroundTask.getData<String>(key: PushBg._kGroup) ?? '';
    _uid = await FlutterForegroundTask.getData<String>(key: PushBg._kUid) ?? '';
    _name =
        await FlutterForegroundTask.getData<String>(key: PushBg._kName) ?? '';
    if (token.isEmpty || group.isEmpty) return;

    final channel = PairChannel(
      authToken: token,
      groupId: group,
      onMoneyChanged: (by) {
        // Своё изменение — эхо собственной записи, а не новость.
        if (by.isEmpty || by == _uid) return;
        _local.partnerWrote(name: _name);
      },
    );
    if (await channel.connect()) {
      _channel = channel;
      debugPrint('фоновая доставка: слушаю пару $group');
    } else {
      await channel.close();
    }
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) => _connect();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _channel?.close();
    _channel = null;
  }
}
