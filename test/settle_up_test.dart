import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/logic/split.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Аня');

Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      transactions: [
        // Аня заплатила 1000 за общее: половина на Саше.
        Transaction(
          id: 'a',
          date: '2026-09-12',
          kind: TxKind.expense,
          account: 'Карта',
          currency: 'MDL',
          amount: -1000,
          amountBase: -1000,
          author: 'u_you',
          payer: 'u_you',
          split: SplitMode.equal,
        ),
      ],
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  return store;
}

void main() {
  group('расчёт долга', () {
    test('сальдо обнуляется, остатки не трогаются', () {
      final store = storeOf();
      final before = settlement(store.db.transactions, store.db.pair);
      expect(before[me.uid], -500);
      expect(before[you.uid], 500);

      final wasBalance = balances(store.db)
          .firstWhere((a) => a.name == 'Карта')
          .mainAmount;

      store.settleUp(from: me.uid, to: you.uid, amount: 500);

      final after = settlement(store.db.transactions, store.db.pair);
      expect(after[me.uid]!.abs() < 0.005, isTrue, reason: 'долга больше нет');
      expect(after[you.uid]!.abs() < 0.005, isTrue);

      // Деньги переданы вне приложения: остаток карты не меняется.
      expect(
        balances(store.db).firstWhere((a) => a.name == 'Карта').mainAmount,
        wasBalance,
      );
    });

    test('запись расчёта уезжает на сервер и видна паре', () {
      final store = storeOf();
      store.settleUp(from: me.uid, to: you.uid, amount: 500);
      final op = store.db.transactions.firstWhere((t) => t.id.startsWith('stl-'));
      expect(isVirtualAccount(op.account), isTrue);
      expect(store.outbox, contains('tx:${op.id}'));
    });

    test('нулевой и отрицательный расчёт не пишется', () {
      final store = storeOf();
      final was = store.db.transactions.length;
      store.settleUp(from: me.uid, to: you.uid, amount: 0);
      store.settleUp(from: me.uid, to: you.uid, amount: -10);
      expect(store.db.transactions.length, was);
    });
  });
}
