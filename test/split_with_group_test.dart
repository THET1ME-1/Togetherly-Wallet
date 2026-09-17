import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/money.dart';

const sasha = Member(uid: 'u_sasha', name: 'Саша');
const anya = Member(uid: 'u_anya', name: 'Аня');
const kirill = Member(uid: 'u_kirill', name: 'Кирилл');

Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      // Карта ОБЩАЯ у пары с Аней: всё, что с неё ушло, Аня видит.
      accounts: [Account(name: 'Общая карта', currency: 'MDL')],
      pair: Pair(groupId: 'g_anya', members: [sasha, anya], baseCurrency: 'MDL'),
    ));
  store.viewer = sasha.uid;
  store.syncEnabled = true;
  return store;
}

void main() {
  group('трата за другую пару', () {
    test('остаётся на своём счёте и повторяется расчётом у второй пары', () {
      final store = storeOf();
      // Вторая пара — с Кириллом.
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [sasha, kirill],
        baseCurrency: 'MDL',
      ));
      store.openSpace(const Pair(
        groupId: 'g_anya',
        members: [sasha, anya],
        baseCurrency: 'MDL',
      ));

      const op = Transaction(
        id: 'obed',
        date: '2026-09-13',
        kind: TxKind.expense,
        account: 'Общая карта',
        currency: 'MDL',
        amount: -500,
        amountBase: -500,
        category: 'Кафе',
        author: 'u_sasha',
        payer: 'u_sasha',
      );
      store.saveOperation(op);
      store.shareWith('g_kirill', op);

      // У пары с Аней запись как была: деньги ушли с их общей карты.
      expect(store.db.transactions.single.account, 'Общая карта');

      // У пары с Кириллом — та же трата, но на счёте-расчёте: чужую карту
      // ей знать нельзя, а сумму и плательщика — нужно.
      final theirs = store.dbOf('g_kirill').transactions.single;
      expect(isOutsideAccount(theirs.account), isTrue);
      expect(theirs.amount, -500);
      expect(theirs.payer, 'u_sasha');

      // Счёт-расчёт не притворяется кошельком: в остатки он не попадает.
      expect(
        balances(store.dbOf('g_kirill')).where((a) => a.name == theirs.account),
        isEmpty,
      );
    });

    test('повторное деление не плодит копии', () {
      final store = storeOf();
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [sasha, kirill],
        baseCurrency: 'MDL',
      ));
      store.openSpace(const Pair(
        groupId: 'g_anya',
        members: [sasha, anya],
        baseCurrency: 'MDL',
      ));
      const op = Transaction(
        id: 'obed',
        date: '2026-09-13',
        kind: TxKind.expense,
        account: 'Общая карта',
        currency: 'MDL',
        amount: -500,
        amountBase: -500,
        author: 'u_sasha',
        payer: 'u_sasha',
      );
      store.saveOperation(op);
      store.shareWith('g_kirill', op);
      store.shareWith('g_kirill', op);
      expect(store.dbOf('g_kirill').transactions.length, 1);
    });
  });

  group('сводка по всем парам', () {
    test('счета подписаны парой и остатки не складываются вслепую', () {
      final store = storeOf();
      store.saveOperation(const Transaction(
        id: 'a',
        date: '2026-09-13',
        kind: TxKind.expense,
        account: 'Общая карта',
        currency: 'MDL',
        amount: -100,
        amountBase: -100,
        author: 'u_sasha',
        payer: 'u_sasha',
      ));

      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [sasha, kirill],
        baseCurrency: 'MDL',
      ));
      store.editAccount('Общая карта');
      store.saveOperation(const Transaction(
        id: 'b',
        date: '2026-09-12',
        kind: TxKind.expense,
        account: 'Общая карта',
        currency: 'MDL',
        amount: -40,
        amountBase: -40,
        author: 'u_sasha',
        payer: 'u_sasha',
      ));

      store.setViewAll(true);
      final view = store.view;
      // У обеих пар счёт зовётся одинаково — в сводке их различают по имени
      // партнёра, иначе два разных остатка слиплись бы в один.
      expect(view.accounts.map((a) => a.name),
          containsAll(['Общая карта · Кирилл', 'Общая карта · Аня']));
      expect(view.transactions.length, 2);

      store.setViewAll(false);
      expect(store.view.transactions.length, 1,
          reason: 'обычный режим показывает только открытую пару');
    });

    test('запись всегда ложится в открытую пару, даже в сводке', () {
      final store = storeOf();
      store.openSpace(const Pair(
        groupId: 'g_kirill',
        members: [sasha, kirill],
        baseCurrency: 'MDL',
      ));
      store.setViewAll(true);
      store.saveOperation(const Transaction(
        id: 'c',
        date: '2026-09-13',
        kind: TxKind.expense,
        account: 'Общая карта',
        currency: 'MDL',
        amount: -10,
        amountBase: -10,
        author: 'u_sasha',
        payer: 'u_sasha',
      ));
      expect(store.db.transactions.single.id, 'c');
      expect(store.dbOf('g_anya').transactions, isEmpty);
    });
  });

  test('перенос уносит запись целиком', () {
    final store = storeOf();
    store.openSpace(const Pair(
      groupId: 'g_kirill',
      members: [sasha, kirill],
      baseCurrency: 'MDL',
    ));
    store.openSpace(const Pair(
      groupId: 'g_anya',
      members: [sasha, anya],
      baseCurrency: 'MDL',
    ));
    const op = Transaction(
      id: 'obed',
      date: '2026-09-13',
      kind: TxKind.expense,
      account: 'Общая карта',
      currency: 'MDL',
      amount: -500,
      amountBase: -500,
      author: 'u_sasha',
      payer: 'u_sasha',
    );
    store.saveOperation(op);

    store.moveOperation(op, 'g_kirill');
    expect(store.db.transactions, isEmpty,
        reason: 'прежняя пара запись больше не видит');
    expect(store.dbOf('g_kirill').transactions.single.id, 'obed');
    expect(store.outbox, contains('tx:obed'),
        reason: 'удаление обязано уехать на сервер флагом');
  });
}
