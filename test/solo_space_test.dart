import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/services/sync.dart';

const me = Member(uid: 'u_fedea', name: 'Федя');
const partner = Member(uid: 'u_thet1me', name: 'THET1ME');

const pair = Pair(
  groupId: 'g_pair',
  members: [me, partner],
  baseCurrency: 'MDL',
);

/// Сессия с живой парой на сервере: ровно то, что видит человек, выбравший
/// «Только я» и не распустивший пару.
class _PairedSession extends Session {
  @override
  bool get signedIn => true;

  @override
  String get uid => me.uid;

  @override
  Future<List<Pair>> loadPairs() async => const [pair];

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      <String, dynamic>{};
}

/// Хранилище в паре, как на телефоне тестировщика.
Store pairedStore() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Наличные', currency: 'MDL')],
      pair: pair,
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  return store;
}

/// Выбрать «Только я» тем же путём, что и чип в шапке.
void pickSolo(Store store) {
  store.setViewAll(false);
  store.setPairChoice(me.uid);
  store.openSpace(const Pair(
    groupId: 'u_fedea',
    members: [me],
    baseCurrency: 'MDL',
  ));
}

void main() {
  group('«Только я»', () {
    test('выбор личного пространства переживает круг синхронизации', () async {
      final store = pairedStore();
      pickSolo(store);
      expect(store.space, me.uid, reason: 'сразу после выбора');

      final sync = Sync(session: _PairedSession(), store: store);
      await sync.run();
      sync.dispose();

      // Жалоба тестировщика 22.09.2026: «Кнопка только я не работает. После
      // нажатия просто обновляется страница».
      expect(store.space, me.uid,
          reason: 'круг синхронизации вернул пару поверх выбора');
    });

    test('записи личного пространства не пропадают после круга', () async {
      final store = pairedStore();
      pickSolo(store);
      store.saveOperation(const Transaction(
        id: 'solo-1',
        date: '2026-09-22',
        kind: TxKind.expense,
        account: 'Наличные',
        currency: 'MDL',
        amount: -240,
        amountBase: -240,
        author: 'u_fedea',
        payer: 'u_fedea',
      ));
      store.clearOutbox(store.outbox);

      final sync = Sync(session: _PairedSession(), store: store);
      await sync.run();
      sync.dispose();

      expect(store.db.transactions.map((t) => t.id), contains('solo-1'));
    });

    test('без выбора пара по-прежнему подтягивается сама', () async {
      final store = Store()
        ..importBackupForTest(const Database(baseCurrency: 'MDL'))
        ..syncEnabled = true;
      store.viewer = me.uid;

      final sync = Sync(session: _PairedSession(), store: store);
      await sync.run();
      sync.dispose();

      expect(store.db.pair.groupId, 'g_pair',
          reason: 'одиночке пара с сервера нужна');
    });
  });
}
