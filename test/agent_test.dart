import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/agent.dart';

Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Карта', currency: 'MDL'),
        Account(name: 'Доллары', currency: 'USD'),
      ],
      categories: [Category(name: 'Продукты')],
      rates: {'USD': 17.3},
    ));
  store.viewer = 'u_me';
  store.syncEnabled = true;
  return store;
}

AgentAction act(String kind, Map<String, dynamic> args) =>
    AgentAction.fromJson({'do': kind, 'args': args});

void main() {
  group('чат делает то, что просили', () {
    test('записывает трату', () {
      final store = storeOf();
      final ok = runAgent(
        store,
        act('add_transaction', {
          'kind': 'expense',
          'amount': 417.6,
          'account': 'Карта',
          'category': 'Продукты',
          'date': '2026-09-13',
        }),
      );
      expect(ok, isTrue);
      final tx = store.db.transactions.single;
      expect(tx.amount, -417.6);
      expect(tx.category, 'Продукты');
      expect(store.outbox, contains('tx:${tx.id}'));
    });

    test('чужая валюта пересчитывается в базовую', () {
      final store = storeOf();
      runAgent(
        store,
        act('add_transaction', {
          'kind': 'expense',
          'amount': 10,
          'account': 'Доллары',
          'currency': 'USD',
        }),
      );
      final tx = store.db.transactions.single;
      expect(tx.currency, 'USD');
      expect(tx.amountBase, closeTo(-173, 0.01));
    });

    test('ставит лимит и убирает его', () {
      final store = storeOf();
      runAgent(store, act('set_budget', {'category': 'Кафе', 'limit': 1200}));
      expect(store.db.budgets.single.limit, 1200);
      runAgent(store, act('delete_budget', {'category': 'Кафе'}));
      expect(store.db.budgets, isEmpty);
    });

    test('заводит счёт, категорию и подкатегорию', () {
      final store = storeOf();
      runAgent(store, act('add_account', {'name': 'Наличные', 'kind': 'cash'}));
      runAgent(store, act('add_category', {'name': 'Кафе'}));
      runAgent(store, act('add_category', {'name': 'Кофе', 'parent': 'Кафе'}));
      expect(store.db.accounts.map((a) => a.name), contains('Наличные'));
      expect(store.subcategoriesOf('Кафе').single.name, 'Кофе');
    });

    test('правит и удаляет запись', () {
      final store = storeOf();
      runAgent(
        store,
        act('add_transaction', {'kind': 'expense', 'amount': 100, 'account': 'Карта'}),
      );
      final id = store.db.transactions.single.id;

      runAgent(store, act('update_transaction', {'id': id, 'amount': 250}));
      expect(store.db.transactions.single.amount, -250);

      runAgent(store, act('delete_transaction', {'id': id}));
      expect(store.db.transactions, isEmpty);
    });

    test('без суммы и без счёта ничего не пишет', () {
      final store = storeOf();
      expect(runAgent(store, act('add_transaction', {'kind': 'expense'})), isFalse);
      expect(store.db.transactions, isEmpty);
      expect(runAgent(store, act('delete_transaction', {'id': 'нет-такой'})), isFalse);
    });

    test('вопрос человеку действием не считается', () {
      final a = act('ask_user', {
        'question': 'Какой счёт?',
        'options': ['Карта', 'Наличные'],
      });
      expect(a.isQuestion, isTrue);
      expect(a.options, ['Карта', 'Наличные']);
    });

    test('удаляет несколько последних записей', () {
      final store = storeOf();
      for (var i = 0; i < 6; i++) {
        runAgent(
          store,
          act('add_transaction', {
            'kind': 'expense',
            'amount': 10 + i,
            'account': 'Карта',
            'date': '2026-09-0${i + 1}',
          }),
        );
      }
      expect(store.db.transactions.length, 6);

      runAgent(store, act('delete_last', {'count': 5}));
      expect(store.db.transactions.length, 1);
      expect(store.db.transactions.single.date, '2026-09-01',
          reason: 'осталась самая старая');
    });

    test('больше двадцати за раз не удаляет', () {
      final store = storeOf();
      for (var i = 0; i < 25; i++) {
        runAgent(
          store,
          act('add_transaction', {
            'kind': 'expense',
            'amount': 5,
            'account': 'Карта',
            'date': '2026-08-${(i + 1).toString().padLeft(2, '0')}',
          }),
        );
      }
      runAgent(store, act('delete_last', {'count': 99}));
      expect(store.db.transactions.length, 5);
    });

    test('выписка пишется пачкой и отменяется одним касанием', () {
      final store = storeOf();
      runAgent(
        store,
        act('add_transactions', {
          'items': [
            {'kind': 'expense', 'amount': 250, 'account': 'Карта', 'date': '2026-09-10', 'note': 'Linella'},
            {'kind': 'expense', 'amount': 89.5, 'account': 'Карта', 'date': '2026-09-11', 'note': 'Tucano'},
            {'kind': 'income', 'amount': 1500, 'account': 'Карта', 'date': '2026-09-12'},
          ],
        }),
      );
      expect(store.db.transactions.length, 3);
      expect(store.db.transactions.where((t) => t.amount > 0).length, 1);

      // Вся пачка — одна ступень отмены: иначе человек убрал бы одну строку
      // из ста и решил, что приложение сломалось.
      store.undoLast();
      expect(store.db.transactions, isEmpty);
    });

    test('битые строки пропускаются, остальные пишутся', () {
      final store = storeOf();
      final ok = runAgent(
        store,
        act('add_transactions', {
          'items': [
            {'kind': 'expense', 'amount': 0},
            {'kind': 'expense', 'amount': 120, 'account': 'Карта'},
            {'amount': 'ерунда'},
          ],
        }),
      );
      expect(ok, isTrue);
      expect(store.db.transactions.single.amount, -120);
    });

    test('больше двухсот строк за раз не пишется', () {
      final store = storeOf();
      runAgent(
        store,
        act('add_transactions', {
          'items': [
            for (var i = 0; i < 250; i++)
              {'kind': 'expense', 'amount': 5, 'account': 'Карта'},
          ],
        }),
      );
      expect(store.db.transactions.length, 200);
    });
  });
}
