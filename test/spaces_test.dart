import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';

const me = Member(uid: 'u_sasha', name: 'Саша');
const anya = Member(uid: 'u_anya', name: 'Аня');
const kirill = Member(uid: 'u_kirill', name: 'Кирилл');

Transaction tx(String id, double amount) => Transaction(
      id: id,
      date: '2026-09-13',
      kind: amount > 0 ? TxKind.income : TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: amount,
      amountBase: amount,
      author: me.uid,
      payer: me.uid,
    );

Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      pair: Pair(groupId: 'g_anya', members: [me, anya], baseCurrency: 'MDL'),
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  return store;
}

void main() {
  group('несколько пар сразу', () {
    test('записи пар не смешиваются', () {
      final store = storeOf();
      store.saveOperation(tx('a', -100));

      // Вторая пара — своё хранилище: у Кирилла нет доступа к тратам с Аней,
      // и наоборот.
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [me, kirill],
        baseCurrency: 'MDL',
      ));
      expect(store.db.transactions, isEmpty);
      store.saveOperation(tx('b', -50));
      expect(store.db.transactions.single.id, 'b');

      store.openSpace(const Pair(
        groupId: 'g_anya',
        members: [me, anya],
        baseCurrency: 'MDL',
      ));
      expect(store.db.transactions.single.id, 'a',
          reason: 'записи первой пары остались на месте');
    });

    test('у каждого пространства своя очередь и своя метка', () {
      final store = storeOf();
      store.saveOperation(tx('a', -100));
      expect(store.outbox, contains('tx:a'));

      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [me, kirill],
        baseCurrency: 'MDL',
      ));
      expect(store.outbox, isEmpty,
          reason: 'очередь первой пары не уезжает во вторую');

      store.applyRemote({'now': 77, 'transactions': const []});
      expect(store.syncMark, 77);

      store.openSpace(const Pair(
        groupId: 'g_anya',
        members: [me, anya],
        baseCurrency: 'MDL',
      ));
      expect(store.syncMark, isNot(77),
          reason: 'метка дельты у каждой пары своя');
      expect(store.outbox, contains('tx:a'));
    });

    test('известные пространства перечислены', () {
      final store = storeOf();
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [me, kirill],
        baseCurrency: 'MDL',
      ));
      expect(store.spaces, containsAll(['g_anya', 'g_kirill']));
      expect(store.space, 'g_kirill');
    });

    test('дельта соседней пары не трогает открытую', () {
      final store = storeOf();
      store.saveOperation(tx('a', -100));
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [me, kirill],
        baseCurrency: 'MDL',
      ));
      store.openSpace(const Pair(
        groupId: 'g_anya',
        members: [me, anya],
        baseCurrency: 'MDL',
      ));

      // Пока человек смотрит на пару с Аней, сервер прислал трату Кирилла.
      store.applyRemoteTo('g_kirill', {
        'now': 42,
        'accounts': [
          {'name': 'Карта', 'currency': 'MDL'},
        ],
        'transactions': [
          {
            'id': 'k1',
            'date': '2026-09-13',
            'kind': 'expense',
            'account': 'Карта',
            'currency': 'MDL',
            'amount': -70,
            'amount_base': -70,
            'author': 'u_kirill',
          },
        ],
      });

      expect(store.db.transactions.single.id, 'a',
          reason: 'открытая пара не шелохнулась');
      expect(store.markOf('g_kirill'), 42);
      expect(store.dbOf('g_kirill').transactions.single.id, 'k1');
    });
  });
}
