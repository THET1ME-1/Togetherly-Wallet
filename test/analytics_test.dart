import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/services/analytics.dart';
import 'package:togetherly_money/services/session.dart';

/// Аналитика Tessera.
///
/// Wallet и Togetherly живут на одной учётной записи, поэтому «сколько людей у
/// Wallet» из общей таблицы не достать. События уезжают под СВОИМ приложением
/// (`wallet`) и со своим ключом — по нему сервер и разводит статистику
/// (просьба человека 18.09.2026).
///
/// Здесь проверяется то, что ломается молча: без ключа не должно уходить
/// ничего (иначе форк слал бы события в чужую панель), очередь не должна расти
/// бесконечно, а отказ сервера не должен съедать накопленное.

({http.Client client, List<Map<String, dynamic>> sent, List<String> keys}) spy(
        {int code = 202}) {
  final sent = <Map<String, dynamic>>[];
  final keys = <String>[];
  final client = MockClient((req) async {
    keys.add(req.headers['X-Tessera-Key'] ?? '');
    sent.add((jsonDecode(req.body) as Map).cast<String, dynamic>());
    return http.Response('{"ok":true}', code);
  });
  return (client: client, sent: sent, keys: keys);
}

void main() {
  test('события уходят под своим приложением и своим ключом', () async {
    final api = spy();
    final a = Analytics.forTest(key: 'ключ-wallet', client: api.client);

    a.funnel('open');
    a.action('op_saved', params: {'kind': 'expense'});
    await a.flush();

    expect(api.sent, hasLength(1));
    final body = api.sent.single;
    expect(body['app'], 'wallet', reason: 'иначе смешается с Togetherly');
    expect(api.keys.single, 'ключ-wallet');

    final events = (body['events'] as List).cast<Map<String, dynamic>>();
    expect(events, hasLength(2));
    expect(events.first['kind'], 'funnel');
    expect(events.last['name'], 'op_saved');
    // Номер события: по нему сервер отбрасывает повтор пачки на плохой связи.
    expect(events.map((e) => e['eid']).toSet(), hasLength(2));
  });

  test('без ключа не уходит ничего', () async {
    // Ключ приходит сборкой, в исходниках его нет. Форк, собравший приложение
    // из открытого репозитория, не должен слать события в чужую панель.
    final api = spy();
    final a = Analytics.forTest(key: '', client: api.client);

    a.action('op_saved');
    await a.flush();

    expect(a.enabled, isFalse);
    expect(a.queued, isZero, reason: 'выключенная аналитика даже не копит');
    expect(api.sent, isEmpty);
  });

  test('отказ сервера не съедает накопленное', () async {
    // 5xx — сервер прилёг; события подождут следующего круга.
    final api = spy(code: 503);
    final a = Analytics.forTest(key: 'k', client: api.client);

    a.action('op_saved');
    await a.flush();

    expect(api.sent, hasLength(1));
    expect(a.queued, 1, reason: 'пачка вернулась в очередь');
  });

  test('кривую пачку сервер отвергает навсегда', () async {
    // 4xx — ключ не тот или тело битое: повторять нечего, иначе очередь
    // застрянет на одной и той же пачке до конца дня.
    final api = spy(code: 400);
    final a = Analytics.forTest(key: 'k', client: api.client);

    a.action('op_saved');
    await a.flush();

    expect(a.queued, isZero);
  });

  test('очередь не растёт бесконечно', () async {
    // Телефон без сети неделю — не повод съесть память: держим последние.
    final api = spy();
    final a = Analytics.forTest(key: 'k', client: api.client);

    for (var i = 0; i < 400; i++) {
      a.action('op_saved');
    }
    expect(a.queued, lessThanOrEqualTo(300));
  });

  test('в событии нет ни сумм, ни категорий', () async {
    // Это деньги пары. В аналитике им не место — только имя действия и числа.
    final api = spy();
    final a = Analytics.forTest(key: 'k', client: api.client);

    a.action('op_saved', params: {'kind': 'expense', 'split': 'equal'});
    await a.flush();

    final raw = jsonEncode(api.sent.single);
    expect(raw.contains('amount'), isFalse);
    expect(raw.contains('note'), isFalse);
    expect(raw.contains('category'), isFalse);
  });

  test('без аккаунта человек считается по номеру устройства', () async {
    // Wallet работает и без входа: человек ведёт деньги один, никуда не
    // входя. Без своего номера он не попал бы в счёт людей вовсе, и вопрос
    // «сколько у Wallet пользователей» отвечал бы только про вошедших.
    final api = spy();
    final a = Analytics.forTest(key: 'k', client: api.client);
    await a.init(Session(), installId: 'abc0123456789def');

    a.funnel('open');
    await a.flush();

    final events = ((api.sent.single['events']) as List)
        .cast<Map<String, dynamic>>();
    expect(events.single['who'], 'abc0123456789def');
  });
}
