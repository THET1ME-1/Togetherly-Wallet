import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/categories_edit.dart';

import 'tm_fonts.dart';

Database sample() => const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      categories: [
        Category(name: 'Продукты', color: 0xFF6FC2A8),
        Category(name: 'Кофе', parent: 'Продукты', icon: 'cafe'),
        Category(name: 'Дом'),
      ],
      transactions: [
        Transaction(
          id: 'e1',
          date: '2026-09-05',
          kind: TxKind.expense,
          account: 'Карта',
          currency: 'MDL',
          amount: -120,
          amountBase: -120,
          category: 'Продукты',
          subcategory: 'Кофе',
        ),
      ],
    );

Widget app(Store store) => MaterialApp(
      theme: MoneyTheme.light(),
      home: CategoriesEditScreen(store: store),
    );

void main() {
  setUpAll(loadTmFonts);

  /// Лист правки длинный: цвет и значок занимают экран целиком, и кнопки
  /// «Сохранить» с «Убрать» лежат ниже кромки. Поэтому окно высокое, а до
  /// кнопки тест ещё и доезжает прокруткой — иначе нажатие промахивается
  /// молча, а правка выглядит потерянной.
  Future<void> open(WidgetTester tester, Store store) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('подкатегории на экране категорий', () {
    testWidgets('подкатегория стоит под своей категорией', (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      expect(find.text('Продукты'), findsOne);
      // Подкатегория стоит ОДИН раз — чипом под своей категорией, а не второй
      // строкой в общем списке.
      expect(find.text('Кофе'), findsOne);
      // Кнопка «Подкатегория» стоит плюсом В строке категории, а не полосой
      // под ней: двадцать шесть таких кнопок превращали список в простыню.
      expect(find.byTooltip('Подкатегория'), findsNWidgets(2));
    });

    testWidgets('правка меняет имя, цвет и значок и забирает операции',
        (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      await tester.tap(find.text('Кофе'));
      await tester.pumpAndSettle();

      // Лист тот же, что у категории, и подписан подкатегорией: иначе его не
      // отличить от правки самой категории.
      expect(find.text('Подкатегория'), findsWidgets);
      // Вида расхода у подкатегории нет — он наследуется от родителя.
      expect(find.text('Это нужда, желание или сбережение'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'Кофе с собой');
      await tester.pumpAndSettle();
      await press(tester, 'Сохранить');

      final sub = store.subcategoriesOf('Продукты');
      expect(sub.map((c) => c.name), ['Кофе с собой']);
      // Переименование забирает операции с собой.
      expect(store.db.transactions.single.subcategory, 'Кофе с собой');
      // Значок при переименовании не теряется.
      expect(sub.single.icon, 'cafe');
    });

    testWidgets('новая подкатегория заводится кнопкой у категории',
        (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      // Плюс в строке «Дома»: по алфавиту эта категория первая.
      await tester.tap(find.byTooltip('Подкатегория').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Ремонт');
      await tester.pumpAndSettle();
      await press(tester, 'Сохранить');

      expect(store.subcategoriesOf('Дом').map((c) => c.name), ['Ремонт']);
    });

    testWidgets('удаление убирает подкатегорию, но не деньги', (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      await tester.tap(find.text('Кофе'));
      await tester.pumpAndSettle();
      await press(tester, 'Убрать');

      expect(store.subcategoriesOf('Продукты'), isEmpty);
      // Операция осталась в своей категории и с той же суммой — потеряно
      // только уточнение.
      final tx = store.db.transactions.single;
      expect(tx.category, 'Продукты');
      expect(tx.subcategory, isNull);
      expect(tx.amount, -120);
    });

    test('подкатегория своей категории не путается с чужой', () {
      final store = Store()..importBackupForTest(sample());
      store.saveSubcategory('Дом', const Category(name: 'Кофе'));

      expect(store.subcategoriesOf('Продукты').map((c) => c.name), ['Кофе']);
      expect(store.subcategoriesOf('Дом').map((c) => c.name), ['Кофе']);

      store.deleteSubcategory('Дом', 'Кофе');
      expect(store.subcategoriesOf('Продукты').map((c) => c.name), ['Кофе']);
      expect(store.subcategoriesOf('Дом'), isEmpty);
    });
  });
}
