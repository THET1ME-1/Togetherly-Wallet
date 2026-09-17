import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/services/session.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');
const third = Member(uid: 'u_third', name: 'Дима');

/// Сессия на подставном транспорте: записывает, куда стучались, и отвечает
/// «всё хорошо». Проверяем именно порядок обращений — в удалении он и есть
/// суть: данные уходят пока сессия жива, запись человека последней.
({Session session, List<String> calls}) signedIn({
  Map<String, int> status = const {},
}) {
  final calls = <String>[];
  final client = MockClient((req) async {
    calls.add('${req.method} ${req.url.path}');
    final code = status[req.url.path] ?? 200;
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
    return http.Response(
      jsonEncode({'ok': code == 200}),
      code,
      headers: {'content-type': 'application/json'},
    );
  });
  return (session: Session(client: client), calls: calls);
}

void main() {
  group('удаление аккаунта', () {
    test('удаление ТОЛЬКО помечает запись и выходит', () async {
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await t.session.deleteAccount(
        pair: const Pair(groupId: 'g1', members: [me], baseCurrency: 'MDL'),
      );

      // Ничего необратимого. 13.09.2026 учётка заказчика пропала вместе с
      // парой, и вернуть её удалось только ночной копией: удаление в
      // PocketBase окончательное. Теперь запись живёт неделю и возвращается
      // обычным входом.
      expect(t.calls, ['POST /api/account/schedule-delete']);
      // Сессии больше нет: человек вышел, и экраны ему показывать незачем.
      expect(t.session.signedIn, isFalse);
    });

    test('пара НЕ распускается и деньги НЕ стираются', () async {
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await t.session.deleteAccount(
        pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      );

      // Всю неделю отсрочки партнёр видит пару живой, а вернувшийся входом
      // получает её назад. Раньше роспуск шёл первым, и отменить его было
      // нечем даже при удачном возврате записи.
      expect(
        t.calls.any((c) => c.startsWith('PATCH /api/collections/groups')),
        isFalse,
        reason: 'пару распускает уборка на сервере, а не нажатие кнопки',
      );
      expect(
        t.calls.contains('POST /api/money/account/delete'),
        isFalse,
        reason: 'деньги стирать до срока нельзя — вернуть будет нечего',
      );
      expect(t.calls, ['POST /api/account/schedule-delete']);
    });

    test('сервер отказал — сессия всё равно закрывается', () async {
      final t = signedIn(status: {'/api/account/schedule-delete': 500});
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await expectLater(
        t.session.deleteAccount(
          pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
        ),
        throwsA(isA<SessionError>()),
      );

      // Отказ доходит до экрана: человек должен знать, что не вышло, а не
      // думать, что аккаунт удалён.
      expect(t.calls, ['POST /api/account/schedule-delete']);
      expect(t.session.signedIn, isTrue);
    });

    test('без входа удаление никуда не стучится', () async {
      final t = signedIn();
      await t.session.deleteAccount();

      expect(t.calls, isEmpty);
    });
  });

  group('пара после роспуска', () {
    test('распущенная группа не подтягивается обратно', () async {
      final urls = <String>[];
      final client = MockClient((req) async {
        urls.add(req.url.toString());
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
        return http.Response(jsonEncode({'items': []}), 200,
            headers: {'content-type': 'application/json'});
      });
      final session = Session(client: client);
      await session.signIn('me@example.com', 'pass12345');
      urls.clear();

      await session.loadPair();

      // Без этого условия человек нажимал «Распустить», а следующий круг
      // синхронизации возвращал ту же пару обратно.
      expect(urls.single, contains('disbanded'));
    });
  });

  group('роспуск пары', () {
    test('пара из двоих помечается распущенной', () async {
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await t.session.disbandPair(
        const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      );

      // Пара из одного человека — не пара, поэтому группа помечается
      // распущенной: так же это делает Togetherly, а коллекция groups общая.
      expect(t.calls, ['PATCH /api/collections/groups/records/g1']);
    });

    test('втроём уходим только сами, серверным маршрутом', () async {
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await t.session.disbandPair(
        const Pair(groupId: 'g1', members: [me, you, third], baseCurrency: 'MDL'),
      );

      expect(t.calls, ['POST /api/group/leave']);
    });

    test('без пары ничего не делаем', () async {
      final t = signedIn();
      await t.session.signIn('me@example.com', 'pass12345');
      t.calls.clear();

      await t.session.disbandPair(const Pair(groupId: '', members: []));

      expect(t.calls, isEmpty);
    });
  });
}
