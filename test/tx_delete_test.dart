import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';

Transaction tx(String id) => Transaction(
      id: id,
      date: '2026-09-13',
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -100,
      amountBase: -100,
      category: 'Продукты',
      author: 'u_me',
      payer: 'u_me',
    );

Store storeOf() {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      transactions: [tx('a')],
    ));
  store.viewer = 'u_me';
  store.syncEnabled = true;
  return store;
}

void main() {
  group('удаление операции', () {
    test('уезжает флагом и остаётся в очереди до ответа сервера', () {
      final store = storeOf();
      store.deleteOperation('a');
      expect(store.db.transactions, isEmpty);
      expect(store.outbox, contains('tx:a'));
    });

    test('не возвращается дельтой, пока удаление не отправлено', () {
      final store = storeOf();
      store.deleteOperation('a');
      // Сервер ещё не знает об удалении и отдаёт запись живой.
      store.applyRemote({
        'now': 10,
        'transactions': [
          {
            'id': 'a',
            'date': '2026-09-13',
            'kind': 'expense',
            'account': 'Карта',
            'currency': 'MDL',
            'amount': -100,
            'amount_base': -100,
            'author': 'u_me',
          },
        ],
      });
      expect(store.db.transactions, isEmpty,
          reason: 'своя неотправленная правка сильнее серверной');
    });

    test('чужое удаление убирает запись с устройства', () {
      final store = storeOf();
      store.applyRemote({
        'now': 11,
        'transactions': [
          {'id': 'a', 'account': 'Карта', 'deleted': true},
        ],
      });
      expect(store.db.transactions, isEmpty);
    });

    test('после ответа сервера очередь чистится, запись не воскресает', () {
      final store = storeOf();
      store.deleteOperation('a');
      store.clearOutbox(store.outbox.toSet());
      store.applyRemote({
        'now': 12,
        'transactions': [
          {'id': 'a', 'account': 'Карта', 'deleted': true},
        ],
      });
      expect(store.db.transactions, isEmpty);
      expect(store.outbox, isEmpty);
    });
  });

  test('запись с призрачным автором удаляется как своя', () {
    // Автор остался от прежнего аккаунта: ни я, ни партнёр. Такую запись
    // человек обязан мочь убрать, иначе она висит вечно.
    final store = Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта', currency: 'MDL')],
        transactions: [
          const Transaction(
            id: 'ghost',
            date: '2026-09-13',
            kind: TxKind.income,
            account: 'Карта',
            currency: 'USD',
            amount: 1500,
            amountBase: 25950.44,
            author: 'u_old',
            payer: 'u_old',
          ),
        ],
      ));
    store.viewer = 'u_me';
    store.syncEnabled = true;

    store.deleteOperation('ghost');
    expect(store.db.transactions, isEmpty);
    expect(store.outbox, contains('tx:ghost'));
  });
}
