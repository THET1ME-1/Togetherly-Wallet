import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/services/auth_failure.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/services/sync.dart';

/// Сессия, которая всегда падает заданной бедой: сеть в тесте не нужна.
class _BrokenSession extends Session {
  _BrokenSession(this.failure, {this.status});

  final AuthFailure failure;
  final int? status;

  @override
  bool get signedIn => true;

  @override
  String get uid => 'u_me';

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    // Именованный `timeout` обязателен и здесь: без него `@override` не
    // сходится, и падает загрузка всего файла теста — грабля записана в
    // памяти проекта ещё после снимков чеков.
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      throw SessionError(failure, status: status);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      throw SessionError(failure, status: status);
}

void main() {
  group('обрыв связи', () {
    test('после обрыва назначается повтор, а красной строки нет', () async {
      final store = Store()
        ..importBackupForTest(const Database(baseCurrency: 'MDL'))
        ..syncEnabled = true;
      final sync = Sync(session: _BrokenSession(AuthFailure.offline), store: store);

      await sync.run();

      // Приложение уже само разбирается — пугать человека нечем.
      expect(sync.retrying, isTrue);
      expect(sync.error, isNull);
      sync.dispose();
    });

    test('отказ сервера по существу повторять незачем', () async {
      final store = Store()
        ..importBackupForTest(const Database(baseCurrency: 'MDL'))
        ..syncEnabled = true;
      final sync = Sync(
        session: _BrokenSession(AuthFailure.wrongCredentials, status: 403),
        store: store,
      );

      await sync.run();

      // «Это не ваша пара» не изменится от повтора: человеку надо показать
      // слова сервера, а не крутить круг заново.
      expect(sync.retrying, isFalse);
      expect(sync.error, isNotNull);
      sync.dispose();
    });
  });

  group('очистка устройства', () {
    test('стирание сбрасывает метку синхронизации и очередь', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          accounts: [Account(name: 'Карта', currency: 'MDL')],
        ))
        ..syncEnabled = true;
      store.editAccount('Вторая');
      store.applyRemote(const {'now': 1789000000000});

      expect(store.syncMark, isNot(0));
      expect(store.outbox, isNotEmpty);

      store.wipe();

      // Без сброса метки следующий круг просит «что нового с прошлого раза»,
      // получает пустую дельту — и приложение остаётся пустым, хотя на сервере
      // всё на месте (поймано на живом эмуляторе 13.09.2026).
      expect(store.syncMark, 0);
      expect(store.outbox, isEmpty);
      expect(store.db.accounts, isEmpty);
    });
  });

  group('пара пришла на чистое устройство', () {
    test('метка синхронизации сбрасывается, и история запрашивается заново', () {
      final store = Store()
        ..importBackupForTest(const Database(baseCurrency: 'MDL'))
        ..syncEnabled = true;

      // Первый круг прошёл ещё одиночкой и поставил метку временем сервера.
      store.applyRemote(const {'now': 1789000000000});
      expect(store.syncMark, 1789000000000);

      // Следом приехала пара.
      store.setPair(const Pair(
        groupId: 'g1',
        baseCurrency: 'MDL',
        members: [Member(uid: 'u_me', name: 'Я')],
      ));

      // Без сброса следующий круг попросит «что нового с этого момента», и год
      // общей истории под эту мерку не подойдёт: человек увидит пустое
      // приложение при полном сервере.
      expect(store.syncMark, 0);
    });

    test('та же пара метку не трогает', () {
      const pair = Pair(
        groupId: 'g1',
        baseCurrency: 'MDL',
        members: [Member(uid: 'u_me', name: 'Я')],
      );
      final store = Store()
        ..importBackupForTest(const Database(baseCurrency: 'MDL', pair: pair))
        ..syncEnabled = true;
      store.applyRemote(const {'now': 1789000000000});

      store.setPair(pair);

      // Обновление состава той же пары — не повод просить всю историю заново.
      expect(store.syncMark, 1789000000000);
    });
  });
}
