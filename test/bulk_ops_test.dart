import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';

/// Пачка операций: удалить, сменить категорию, сменить счёт.
///
/// Человек просил множественный выбор в ленте, и вся его ценность — в том,
/// что пачка ведёт себя КАК ОДНО действие: одна отмена возвращает всё, а не
/// двадцать нажатий подряд. Отсюда требования, которые проверяются здесь.

Transaction tx(String id, {String? category, String account = 'Карта'}) =>
    Transaction(
      id: id,
      date: '2026-09-10',
      kind: TxKind.expense,
      account: account,
      currency: 'MDL',
      amount: -100,
      amountBase: -100,
      category: category,
      author: 'u_me',
      payer: 'u_me',
    );

Store storeOf() => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [
      Account(name: 'Карта', currency: 'MDL'),
      Account(name: 'Наличные', currency: 'MDL'),
    ],
    categories: const [Category(name: 'Продукты'), Category(name: 'Кафе')],
    transactions: [
      tx('a', category: 'Продукты'),
      tx('b', category: 'Продукты'),
      tx('c', category: 'Кафе'),
    ],
  ));

void main() {
  group('удалить пачкой', () {
    test('уходят выбранные, остальные на месте', () {
      final store = storeOf();
      store.deleteMany(const ['a', 'c']);
      expect([for (final t in store.db.transactions) t.id], ['b']);
    });

    test('одна отмена возвращает всю пачку', () {
      // Двадцать нажатий «Отменить» после одного удаления — это не отмена, а
      // наказание.
      final store = storeOf();
      store.deleteMany(const ['a', 'b', 'c']);
      expect(store.db.transactions, isEmpty);
      store.undoLast();
      expect(store.db.transactions, hasLength(3));
    });

    test('удаление уезжает на сервер по каждой записи', () {
      // Флагом, а не молчанием: иначе запись вернётся первой же дельтой.
      // Очередь отправки наполняется только у вошедшего — у одиночки без
      // аккаунта отправлять некуда.
      final store = storeOf()..syncEnabled = true;
      store.deleteMany(const ['a', 'b']);
      expect(store.outbox, containsAll(<String>['tx:a', 'tx:b']));
    });

    test('пустой список ничего не трогает и отмену не заводит', () {
      final store = storeOf();
      store.deleteMany(const []);
      expect(store.db.transactions, hasLength(3));
      expect(store.undo, isNull);
    });
  });

  group('сменить категорию пачкой', () {
    test('меняется у выбранных, у прочих остаётся', () {
      final store = storeOf();
      store.categorizeMany(const ['a', 'c'], category: 'Кафе');
      final byId = {for (final t in store.db.transactions) t.id: t};
      expect(byId['a']!.category, 'Кафе');
      expect(byId['c']!.category, 'Кафе');
      expect(byId['b']!.category, 'Продукты');
    });

    test('подкатегория снимается вместе со сменой категории', () {
      // «Продукты · Кофе» при переносе в «Кафе» оставило бы уточнение от
      // чужой категории, и человек увидел бы «Кафе · Кофе» из ниоткуда.
      final store = storeOf();
      store.saveOperation(
        tx('d', category: 'Продукты').copyWith(subcategory: 'Кофе'),
      );
      store.categorizeMany(const ['d'], category: 'Кафе');
      final op = store.db.transactions.firstWhere((t) => t.id == 'd');
      expect(op.category, 'Кафе');
      expect(op.subcategory, isNull);
    });

    test('одна отмена возвращает прежние категории', () {
      final store = storeOf();
      store.categorizeMany(const ['a', 'b'], category: 'Кафе');
      store.undoLast();
      expect(
        [for (final t in store.db.transactions) t.category],
        ['Продукты', 'Продукты', 'Кафе'],
      );
    });
  });

  group('перенести на другой счёт пачкой', () {
    test('счёт меняется, остальное нетронуто', () {
      final store = storeOf();
      store.moveMany(const ['a'], account: 'Наличные');
      final op = store.db.transactions.firstWhere((t) => t.id == 'a');
      expect(op.account, 'Наличные');
      expect(op.amount, -100);
      expect(op.category, 'Продукты');
    });

    test('несуществующий счёт не принимается', () {
      // Запись на счёте, которого нет, пропадает из всех остатков разом.
      final store = storeOf();
      store.moveMany(const ['a'], account: 'Депозит в Нарнии');
      final op = store.db.transactions.firstWhere((t) => t.id == 'a');
      expect(op.account, 'Карта');
    });
  });
}
