import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart' as cent;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'session.dart';
import 'sync.dart';

/// Подписка на канал пары в чистом виде: только токен сессии и номер группы.
///
/// Отдельно от [Live] потому, что тем же кодом слушает фоновый изолят
/// (`push_bg.dart`): у него нет ни [Session], ни [Sync] — там всё, что есть,
/// это токен и имя канала.
class PairChannel {
  PairChannel({
    required this.authToken,
    required this.groupId,
    required this.onMoneyChanged,
    this.apiBase = kApiBase,
    this.ws = Live.wsUrl,
  });

  final String authToken;
  final String groupId;

  /// Кто-то изменил деньги пары. Приходит uid автора: своё изменение не
  /// событие, а эхо собственной записи.
  final void Function(String byUid) onMoneyChanged;

  final String apiBase;
  final String ws;

  cent.Client? _client;
  cent.Subscription? _sub;

  Future<bool> connect() async {
    final channel = 'pair:$groupId';
    try {
      final token = await _token('/api/centrifugo/connection-token');
      if (token == null) return false;

      final client = cent.createClient(ws, cent.ClientConfig(token: token));
      _client = client;
      await client.connect();

      final subToken = await _token(
        '/api/centrifugo/subscription-token',
        body: {'channel': channel},
      );
      if (subToken == null) return false;

      final sub = client.getSubscription(channel) ??
          client.newSubscription(
            channel,
            // Канал пары приватный, поэтому нужен свой токен подписки. Канал
            // уходит в ТЕЛЕ запроса: в адресной строке роут его не видит и
            // отвечает 400, подписка встаёт без токена и молча не получает ни
            // одного события.
            cent.SubscriptionConfig(token: subToken),
          );
      _sub = sub;
      sub.publication.listen((p) {
        Object? data;
        try {
          data = jsonDecode(utf8.decode(p.data));
        } catch (_) {
          return;
        }
        // Нас касается только событие денег: чат и рисование ходят тем же
        // каналом пары, и будить синхронизацию на каждый штрих незачем.
        if (data is Map && data['event'] == 'money_changed') {
          onMoneyChanged('${data['by'] ?? ''}');
        }
      });
      sub.error.listen((e) => debugPrint('живой канал: отказ подписки $e'));
      await sub.subscribe();
      return true;
    } catch (e) {
      debugPrint('живой канал не поднялся: $e');
      return false;
    }
  }

  Future<String?> _token(String path, {Map<String, dynamic> body = const {}}) async {
    try {
      final res = await http.post(
        Uri.parse('$apiBase$path'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authToken,
        },
        body: jsonEncode(body),
      );
      if (res.statusCode != 200) return null;
      final t = ((jsonDecode(res.body) as Map)['token'] ?? '') as String;
      return t.isEmpty ? null : t;
    } catch (e) {
      debugPrint('живой канал: токен $path не выдан ($e)');
      return null;
    }
  }

  Future<void> close() async {
    try {
      await _sub?.unsubscribe();
    } catch (_) {}
    _sub = null;
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
  }
}

/// Живой канал пары: партнёр записал трату, и она появляется сразу, а не
/// после свёртывания приложения.
///
/// В канал уходит только «есть изменения» — ни суммы, ни заметки. Детали в
/// общем канале обошли бы приватность: канал слушают оба, а урезание чужого
/// сюрприза считается на выдаче. Поэтому событие лишь будит синхронизацию.
class Live {
  Live({required this.session, required this.sync, this.onPartnerWrote});

  final Session session;
  final Sync sync;

  /// Партнёр что-то записал. Отсюда растёт уведомление второй системы: пока
  /// приложение свёрнуто, но живо, канал ещё слушает, а пушей на этом телефоне
  /// может не быть вовсе.
  final void Function()? onPartnerWrote;

  static const wsUrl = String.fromEnvironment(
    'CENTRIFUGO_WS',
    defaultValue: 'wss://togetherly.day/connection/websocket',
  );

  cent.Client? _client;
  cent.Subscription? _sub;
  String _channel = '';
  Timer? _retry;

  /// Подписка живёт ровно на одну пару: сменилась — переподписываемся.
  Future<void> follow(String groupId) async {
    if (!session.signedIn || groupId.isEmpty) {
      await stop();
      return;
    }
    final channel = 'pair:$groupId';
    if (_channel == channel && _client != null) return;
    await stop();
    _channel = channel;

    try {
      final token = await _token('/api/centrifugo/connection-token');
      if (token == null) return _later(groupId);

      final client = cent.createClient(wsUrl, cent.ClientConfig(token: token));
      _client = client;
      await client.connect();

      final subToken = await _token(
        '/api/centrifugo/subscription-token',
        body: {'channel': channel},
      );
      if (subToken == null) {
        debugPrint('живой канал: подписка на $channel без токена не встанет');
        return _later(groupId);
      }

      final sub = client.getSubscription(channel) ??
          client.newSubscription(
            channel,
            cent.SubscriptionConfig(
              // Канал пары приватный, поэтому нужен свой токен подписки.
              // Канал уходит в ТЕЛЕ запроса: в адресной строке роут его не
              // видит и отвечает 400, подписка встаёт без токена и молча не
              // получает ни одного события.
              token: subToken,
            ),
          );
      _sub = sub;
      sub.publication.listen((p) {
        // Публикация приходит байтами, а не готовой картой.
        Object? data;
        try {
          data = jsonDecode(utf8.decode(p.data));
        } catch (_) {
          return;
        }
        // Нас касается только событие денег: чат и рисование ходят тем же
        // каналом пары, и будить синхронизацию на каждый штрих незачем.
        if (data is Map && data['event'] == 'money_changed') {
          if (data['by'] != session.uid) {
            sync.run();
            onPartnerWrote?.call();
          }
        }
      });
      sub.error.listen((e) => debugPrint('живой канал: отказ подписки $e'));
      await sub.subscribe();
      debugPrint('живой канал: слушаю $channel');
    } catch (e) {
      debugPrint('живой канал не поднялся: $e');
      _later(groupId);
    }
  }

  /// Повтор через минуту: канал — удобство, а не условие работы. Без него
  /// приложение синхронизируется на возврате из фона, как раньше.
  void _later(String groupId) {
    _retry?.cancel();
    _retry = Timer(const Duration(minutes: 1), () => follow(groupId));
  }

  Future<String?> _token(String path, {Map<String, dynamic> body = const {}}) async {
    try {
      final r = await session.post(path, body);
      final t = (r['token'] ?? '') as String;
      return t.isEmpty ? null : t;
    } catch (e) {
      debugPrint('живой канал: токен $path не выдан ($e)');
      return null;
    }
  }

  Future<void> stop() async {
    _retry?.cancel();
    _retry = null;
    _channel = '';
    try {
      await _sub?.unsubscribe();
    } catch (_) {}
    _sub = null;
    try {
      await _client?.disconnect();
    } catch (_) {}
    _client = null;
  }
}
