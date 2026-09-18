import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../logic/store_kind.dart';

/// Сбор падений: свой Bugsink (Sentry-совместимый) на нашем сервере.
///
/// У Togetherly он же, но ПРОЕКТ другой: Wallet шлёт в `/2`, Togetherly в
/// `/1`. Один список падений на два приложения был бы бесполезен — половина
/// записей про чужие экраны, и «у нас упало» пришлось бы выяснять по стеку
/// (18.09.2026, перед закрытым тестированием).
///
/// Сверх проекта каждое событие подписано: `release` вида
/// `togetherly_wallet@0.6.1+26`, тег `app: wallet` и тег магазина, откуда
/// сборка. Так видно и приложение, и версию, и канал раздачи.
class Crash {
  const Crash._();

  /// Адрес приёма приходит сборкой: `--dart-define=BUGSINK_DSN=...`.
  ///
  /// DSN — не секрет (это публичный ключ проекта), но в открытом репозитории
  /// ему не место: форк, собранный из исходников, слал бы свои падения нам, и
  /// разбирать пришлось бы чужие сборки.
  static const String _dsn = String.fromEnvironment('BUGSINK_DSN');

  static bool get enabled => _dsn.isNotEmpty && !kDebugMode;

  /// Запустить приложение под присмотром.
  ///
  /// Без DSN [run] просто выполняет [body]: ни в отладке, ни у форка ничего
  /// никуда не уходит.
  static Future<void> run(FutureOr<void> Function() body) async {
    if (!enabled) {
      await body();
      return;
    }

    var version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // Версия — подпись события, а не условие его отправки.
    }

    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = 'production';
        // Только падения: следы производительности на трекере денег никому не
        // нужны, а трафик у людей не бесконечный.
        options.tracesSampleRate = 0.0;
        options.attachStacktrace = true;
        options.release = 'togetherly_wallet@$version';
        // Приложение, версия и канал раздачи стоят на КАЖДОМ событии: список
        // падений читают на бегу, и «это Wallet или Togetherly» должно быть
        // видно из строки, а не из стека.
        options.beforeSend = (event, hint) {
          if (_noise(event.throwable)) return null;
          event.tags = {
            ...?event.tags,
            'app': 'wallet',
            'store': kStore,
          };
          return event;
        };
      },
      appRunner: () async => body(),
    );
  }

  /// Кто сейчас пользуется приложением. Без имени и почты: в списке падений
  /// нужен только признак «те же грабли у того же человека».
  static Future<void> follow(String uid) async {
    if (!enabled) return;
    await Sentry.configureScope((scope) => scope.setUser(SentryUser(id: uid)));
  }

  /// Сетевой шум — не падение приложения.
  ///
  /// Обрыв сокета, отказ сервера, мёртвый Wi-Fi в кафе: у Togetherly такие
  /// записи тоннами забивали панель и топили настоящие ошибки. Здесь их
  /// отсекаем сразу.
  static bool _noise(Object? error) {
    if (error == null) return false;
    if (error is SocketException || error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('handshakeexception') ||
        text.contains('connection closed') ||
        text.contains('connection reset') ||
        text.contains('connection refused') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('software caused connection abort');
  }

  /// Та же проверка для тестов: шум не должен доехать до панели.
  @visibleForTesting
  static bool noiseForTest(Object? error) => _noise(error);
}
