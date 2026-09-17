import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

Transaction tx(String id, {String? category, String? sub, double amount = -100}) =>
    Transaction(
      id: id,
      date: '2026-09-12',
      kind: amount > 0 ? TxKind.income : TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: amount,
      amountBase: amount,
      category: category,
      subcategory: sub,
      author: 'u_me',
      payer: 'u_me',
    );

Database sample() => Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [
        Category(name: 'Продукты'),
        // Заведённая подкатегория, по которой ещё НИ РАЗУ не платили.
        Category(name: 'Рынок', parent: 'Продукты'),
        Category(name: 'Кофе', parent: 'Продукты'),
      ],
      transactions: [tx('a', category: 'Продукты')],
    );

Store storeOf() {
  final store = Store()..importBackupForTest(sample());
  store.viewer = 'u_me';
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('в записи операции видны ЗАВЕДЁННЫЕ подкатегории', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: OperationScreen(store: storeOf()),
    ));
    await tester.pumpAndSettle();

    // Категории живут в нижней панели: строка сводки её и открывает.
    await tester.tap(find.text('Выберите категорию'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Продукты').first);
    await tester.pumpAndSettle();

    // По «Рынку» не платили ни разу, и до правки его тут не было вовсе.
    // Подкатегории выбранной категории стоят прямо над её сеткой — за ними не
    // надо ни листать, ни открывать отдельный экран.
    expect(find.text('Рынок'), findsOneWidget);
    expect(find.text('Кофе'), findsOneWidget);
  });

  test('отбор по подкатегории оставляет её записи', () {
    final db = Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: sample().categories,
      transactions: [
        tx('a', category: 'Продукты', sub: 'Кофе'),
        tx('b', category: 'Продукты', sub: 'Рынок'),
        tx('c', category: 'Продукты'),
      ],
    );
    const filter = Filter(categories: {'Кофе'});
    final left = db.transactions.where(filter.allows).map((t) => t.id).toList();
    expect(left, ['a'],
        reason: 'подкатегория в отборе должна работать как категория');
  });

  test('подкатегория из разбора списаний уезжает в запись отдельным полем', () {
    // «Кофе» должен лечь подкатегорией «Продуктов», а не стать категорией.
    final store = storeOf();
    store.acceptNotice(
      const ParsedNotice(
        package: 'md.maib.mobile',
        title: 'maib',
        body: 'Achitare 57,00 MDL la Tucano',
        at: 1789300000000,
        amount: 57,
        currency: 'MDL',
        kind: TxKind.expense,
        merchant: 'Tucano',
        confidence: 0.9,
      ),
      account: 'Карта',
      category: 'Продукты',
      subcategory: 'Кофе',
    );
    final tx = store.db.transactions.firstWhere((t) => t.id.startsWith('ntf-'));
    expect(tx.category, 'Продукты');
    expect(tx.subcategory, 'Кофе');
  });
}
