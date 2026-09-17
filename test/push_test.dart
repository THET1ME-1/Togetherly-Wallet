import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/services/push.dart';
import 'package:togetherly_money/services/session.dart';

/// Сессия на подставном транспорте: вход настоящим путём, дальше «ок».
({Session session, List<String> calls, List<Map<String, dynamic>> bodies})
    signedIn() {
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    if (req.body.isNotEmpty) {
      try {
        bodies.add((jsonDecode(req.body) as Map).cast<String, dynamic>());
      } catch (_) {}
    }
    if (req.url.path.endsWith('auth-with-password')) {
      return http.Response(
        jsonEncode({
          'token': 'tok',
          'record': {'id': 'u_me', 'email': 'me@example.com', 'name': 'Саша'},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(jsonEncode({'ok': true}), 200,
        headers: {'content-type': 'application/json'});
  });
  return (session: Session(client: client), calls: calls, bodies: bodies);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('money/fcm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Подставной телефон: отвечает на те же два вопроса, что и настоящий.
  void phone({required bool services, String? token}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'hasServices':
          return services;
        case 'getToken':
          return token;
      }
      return null;
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('какая система доставки нужна', () {
    test('сервисы есть и токен есть — хватает пушей', () {
      expect(localDeliveryNeeded(hasServices: true, hasToken: true), isFalse);
    });

    test('нет сервисов Google — нужна вторая система', () {
      expect(localDeliveryNeeded(hasServices: false, hasToken: true), isTrue);
    });

    test('токен не приехал — тоже нужна', () {
      // Без токена сервер не знает, куда слать; остаться без уведомлений хуже,
      // чем держать сокет самому.
      expect(localDeliveryNeeded(hasServices: true, hasToken: false), isTrue);
    });

    test('ни того, ни другого', () {
      expect(localDeliveryNeeded(hasServices: false, hasToken: false), isTrue);
    });
  });

  group('токен устройства', () {
    test('уезжает на сервер в свою таблицу', () async {
      phone(services: true, token: 'fcm-abc');
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();
      t.bodies.clear();

      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);

      expect(push.ready, isTrue);
      expect(push.needsLocal, isFalse);
      expect(t.calls, ['POST /api/money/device']);
      // Не `users.fcm_token`: та колонка принадлежит Togetherly, и записав
      // свой токен туда, Money увёл бы чужие уведомления себе.
      expect(t.bodies.single['token'], 'fcm-abc');
      expect(t.bodies.single['platform'], 'android');
    });

    test('без сервисов Google никуда не стучимся', () async {
      phone(services: false);
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);

      expect(push.ready, isFalse);
      expect(push.needsLocal, isTrue);
      expect(t.calls, isEmpty);
      // Вердикт вынесен — вторая система может подниматься, не ожидая сети.
      expect(push.settled, isTrue);
    });

    test('сервисы есть, а токена нет', () async {
      phone(services: true, token: null);
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);

      expect(push.ready, isFalse);
      expect(push.needsLocal, isTrue);
      expect(t.calls, isEmpty);
    });

    test('без входа токен не отправляется', () async {
      phone(services: true, token: 'fcm-abc');
      final t = signedIn();

      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);

      expect(push.token, 'fcm-abc');
      expect(t.calls, isEmpty);
    });

    test('выход забывает устройство', () async {
      phone(services: true, token: 'fcm-abc');
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);
      t.calls.clear();
      t.bodies.clear();

      await push.forget(t.session);

      expect(t.calls, ['POST /api/money/device/forget']);
      expect(t.bodies.single['token'], 'fcm-abc');
    });

    test('телефон ответил отказом — приложение работает', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'ошибка');
      });
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');

      final push = Push(channel: channel, onAndroid: true);
      await push.start(t.session);

      expect(push.ready, isFalse);
      expect(push.needsLocal, isTrue);
      expect(push.settled, isTrue);
    });
  });

  group('iPhone', () {
    // На iOS второй системы доставки нет и быть не может: фоновый сервис с
    // живым каналом — приём Android. Пока APNs не подключён, уведомление о
    // записи партнёра приходило бы ровно тогда, когда человек и так смотрит в
    // приложение, то есть никогда (17.09.2026).
    const apple = MethodChannel('money/push');

    void iphone({String? token, bool sandbox = false, bool granted = true}) {
      messenger.setMockMethodCallHandler(apple, (call) async {
        switch (call.method) {
          case 'register':
            return granted ? token : null;
          case 'sandbox':
            return sandbox;
        }
        return null;
      });
    }

    tearDown(() => messenger.setMockMethodCallHandler(apple, null));

    test('токен APNs уезжает с пометкой ios', () async {
      final api = signedIn();
      await api.session.signIn('me@example.com', 'pass');
      iphone(token: 'apns-token');

      final push = Push(channel: apple, onAndroid: false, onApple: true);
      await push.start(api.session);

      expect(push.token, 'apns-token');
      expect(api.calls, contains('POST /api/money/device'));
      final body = api.bodies.last;
      expect(body['token'], 'apns-token');
      expect(body['platform'], 'ios');
    });

    test('отладочная сборка помечается песочницей', () async {
      // Токен из Xcode живёт в песочнице Apple, и боевой APNs отвечает по нему
      // BadDeviceToken. Сервер разводит их по этой пометке.
      final api = signedIn();
      await api.session.signIn('me@example.com', 'pass');
      iphone(token: 'apns-debug', sandbox: true);

      final push = Push(channel: apple, onAndroid: false, onApple: true);
      await push.start(api.session);

      expect(api.bodies.last['platform'], 'ios_sandbox');
    });

    test('человек отказал — приложение работает молча', () async {
      final api = signedIn();
      await api.session.signIn('me@example.com', 'pass');
      iphone(granted: false);

      final push = Push(channel: apple, onAndroid: false, onApple: true);
      await push.start(api.session);

      expect(push.token, isNull);
      expect(push.settled, isTrue);
      expect(api.calls, isNot(contains('POST /api/money/device')));
    });

    test('поздний токен доезжает сам', () async {
      // Человек думает над разрешением минуту, и Apple отвечает своим темпом:
      // мост толкает токен, когда тот наконец приехал.
      final api = signedIn();
      await api.session.signIn('me@example.com', 'pass');
      iphone(token: null);

      final push = Push(channel: apple, onAndroid: false, onApple: true);
      await push.start(api.session);
      expect(api.calls, isNot(contains('POST /api/money/device')));

      await messenger.handlePlatformMessage(
        'money/push',
        const StandardMethodCodec()
            .encodeMethodCall(const MethodCall('token', 'late-token')),
        (_) {},
      );

      expect(push.token, 'late-token');
      expect(api.bodies.last['token'], 'late-token');
      expect(api.bodies.last['platform'], 'ios');
    });
  });
}
