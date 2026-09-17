import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Database sample() => const Database(
      baseCurrency: 'MDL',
      pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: [
        Account(name: 'Карта', currency: 'MDL'),
        Account(name: 'Личный', currency: 'MDL', owner: 'u_me'),
      ],
      categories: [Category(name: 'Продукты')],
      transactions: [
        Transaction(
          id: 't1',
          date: '2026-09-05',
          kind: TxKind.expense,
          account: 'Карта',
          currency: 'MDL',
          amount: -120,
          amountBase: -120,
          category: 'Продукты',
          author: 'u_me',
          payer: 'u_me',
        ),
      ],
      goals: [Goal(name: 'Подушка', target: 30000, currency: 'MDL')],
      debts: [
        Debt(name: 'Ипотека', principal: 500000, rate: 8.5, currency: 'MDL'),
      ],
      budgets: [
        Budget(
          category: 'Продукты',
          limit: 4000,
          currency: 'MDL',
          period: 'monthly',
        ),
      ],
      recurring: [
        Recurring(
          id: 'r1',
          name: 'Интернет',
          amount: -300,
          currency: 'MDL',
          account: 'Карта',
          interval: 'monthly',
          nextDate: '2026-10-01',
          kind: 'payment',
          active: true,
        ),
      ],
    );

void main() {
  group('пара распалась', () {
    test('хранилище становится личным, а записи остаются', () {
      // Синхронизацию включает вход: без неё очередь не наполняется вовсе.
      final store = Store()
        ..importBackupForTest(sample())
        ..syncEnabled = true;
      store.leavePair('u_me');

      // Одиночка держит данные под своим uid — так лежат данные человека без
      // пары, и синхронизация продолжает работать.
      expect(store.db.pair.groupId, 'u_me');
      expect(store.db.pair.members.map((m) => m.uid), ['u_me']);
      // Год записей не исчезает: пара распалась, учёт продолжается.
      expect(store.db.transactions.length, 1);
      expect(store.db.accounts.length, 2);
      expect(store.db.goals.length, 1);
    });

    test('всё уезжает на сервер под новым хранилищем', () {
      // Синхронизацию включает вход: без неё очередь не наполняется вовсе.
      final store = Store()
        ..importBackupForTest(sample())
        ..syncEnabled = true;
      store.leavePair('u_me');

      // Записи прежней группы на сервере остаются у партнёра, а свои обязаны
      // переехать под свой uid — иначе человек, перезайдя, увидит пустоту.
      final out = store.outbox;
      expect(out, contains('tx:t1'));
      expect(out, contains('acc:Карта'));
      expect(out, contains('cat:Продукты'));
      expect(out, contains('goal:Подушка'));
      expect(out, contains('debt:Ипотека'));
      expect(out, contains('rec:r1'));
      expect(out, contains(Store.budgetKey('Продукты', null)));
      expect(out, contains('settings:base'));
      // Метка дельты сброшена: новое хранилище надо читать с начала.
      expect(store.syncMark, 0);
    });

    test('второй роспуск ничего не портит', () {
      // Синхронизацию включает вход: без неё очередь не наполняется вовсе.
      final store = Store()
        ..importBackupForTest(sample())
        ..syncEnabled = true;
      store.leavePair('u_me');
      store.leavePair('u_me');

      expect(store.db.pair.groupId, 'u_me');
      expect(store.db.pair.members.length, 1);
    });

    test('имя своё сохраняется', () {
      // Синхронизацию включает вход: без неё очередь не наполняется вовсе.
      final store = Store()
        ..importBackupForTest(sample())
        ..syncEnabled = true;
      store.leavePair('u_me');

      expect(store.db.pair.members.single.name, 'Саша');
    });
  });

  group('перенос всего на сервер', () {
    test('markAllForSync не забывает цели, долги, лимиты и регулярное', () {
      // Синхронизацию включает вход: без неё очередь не наполняется вовсе.
      final store = Store()
        ..importBackupForTest(sample())
        ..syncEnabled = true;
      store.markAllForSync();

      final out = store.outbox;
      // До 12.09.2026 переносились только операции, счета и категории: месяц
      // работы без аккаунта уезжал в пару без целей и долгов.
      expect(out, contains('goal:Подушка'));
      expect(out, contains('debt:Ипотека'));
      expect(out, contains('rec:r1'));
      expect(out, contains(Store.budgetKey('Продукты', null)));
    });
  });
}
