import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/widgets/pick_row.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/category_pick.dart';

import 'tm_fonts.dart';

/// У счёта свои категории: у рекламного кабинета нет продуктов, у карты нет
/// рекламных поступлений.
Database sample() => const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Карта maib', currency: 'MDL'),
        Account(name: 'Яндекс Реклама', currency: 'RUB'),
        Account(name: 'Наличные', currency: 'MDL'),
      ],
      categories: [
        Category(name: 'Продукты'),
        Category(name: 'Транспорт'),
        Category(name: 'Реклама', accounts: ['Яндекс Реклама']),
        Category(name: 'Пополнение кабинета', accounts: ['Яндекс Реклама']),
        Category(name: 'Подарки'),
      ],
      transactions: [
        Transaction(
          id: 't1', date: '2026-09-01', kind: TxKind.expense,
          account: 'Карта maib', currency: 'MDL', amount: -100, amountBase: -100,
          category: 'Продукты',
        ),
        Transaction(
          id: 't2', date: '2026-09-02', kind: TxKind.expense,
          account: 'Карта maib', currency: 'MDL', amount: -50, amountBase: -50,
          category: 'Продукты',
        ),
        Transaction(
          id: 't3', date: '2026-09-03', kind: TxKind.expense,
          account: 'Наличные', currency: 'MDL', amount: -30, amountBase: -30,
          category: 'Транспорт',
        ),
        Transaction(
          id: 't4', date: '2026-09-04', kind: TxKind.income,
          account: 'Яндекс Реклама', currency: 'RUB', amount: 5000,
          amountBase: 1025, category: 'Реклама',
        ),
      ],
    );

void main() {
  setUpAll(loadTmFonts);

  group('категории счёта', () {
    test('чужие привязанные категории не показываются', () {
      final list = categoriesForAccount(
        sample(),
        account: 'Карта maib',
        income: false,
      );
      expect(list, isNot(contains('Реклама')));
      expect(list, isNot(contains('Пополнение кабинета')));
      expect(list, contains('Продукты'));
      expect(list, contains('Подарки'));
    });

    test('на своём счёте привязанные идут рядом с использованными', () {
      final list = categoriesForAccount(
        sample(),
        account: 'Яндекс Реклама',
        income: true,
      );
      expect(list.first, 'Реклама');
      expect(list, contains('Пополнение кабинета'));
    });

    test('чем платили ЭТИМ счётом — впереди', () {
      final list = categoriesForAccount(
        sample(),
        account: 'Наличные',
        income: false,
      );
      // Транспортом платили наличными, продуктами — картой: здесь первым
      // должен стоять транспорт, хотя продуктов в истории больше.
      expect(list.first, 'Транспорт');
      expect(list, contains('Продукты'));
    });

    test('без счёта показываются все общие', () {
      final list = categoriesForAccount(sample(), account: null, income: false);
      expect(list, contains('Продукты'));
      expect(list, contains('Реклама'));
    });

    test('дублей нет и длина ограничена', () {
      final list = categoriesForAccount(
        sample(),
        account: 'Карта maib',
        income: false,
        limit: 3,
      );
      expect(list.length, 3);
      expect(list.toSet().length, 3);
    });
  });

  group('запись операции', () {
    /// Горизонтальный список строит только видимые пилюли, поэтому набор
    /// категорий проверяется логикой, а здесь — поведение: выбор чужой
    /// категории не должен доживать до записи.
    testWidgets('категории и счета выбираются СЕТКОЙ, а не столбиком', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = Store()..importBackupForTest(sample());

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: OperationScreen(store: store),
      ));
      await tester.pumpAndSettle();

      // Категории лежат в нижней панели сеткой: в ряду с прокруткой вбок было
      // видно две с половиной штуки из двадцати шести, и человек искал свою
      // листанием («не нравится, что надо пролистывать данные», 14.09.2026).
      await tester.tap(find.text('Выберите категорию'));
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithMaxCrossAxisExtent;
      // Столбик запрещён правилом системы: плитки считаются от ширины, и на
      // 393 dp их в ряду заведомо больше одной.
      expect(delegate.maxCrossAxisExtent, lessThan(200));

      // Видно ВСЕ категории счёта разом плюс кнопку «Своя» — против двух с
      // половиной в прежнем ряду с прокруткой вбок. В стартовом наборе их
      // двадцать шесть, и панель показывает двенадцать на первом же экране
      // (замерено на 393×852), остальные — прокруткой сетки или поиском.
      final cells = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(InkWell),
      );
      final cats = sample().categories.where((c) => c.accounts.isEmpty).length;
      expect(tester.widgetList(cells).length, greaterThanOrEqualTo(cats));

      // Подкатегории остаются РЯДОМ с прокруткой: их у категории единицы, и
      // сетка ради трёх штук съела бы половину панели.
      await tester.tap(find.text('Продукты').first);
      await tester.pumpAndSettle();
      expect(find.byType(PickRow), findsAtLeast(1));
    });

    testWidgets('чужая категория не доживает до записи', (tester) async {
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = Store()..importBackupForTest(sample());

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: OperationScreen(store: store),
      ));
      await tester.pumpAndSettle();

      // Сперва встаём на рекламный кабинет и берём ЕГО категорию. Счета и
      // категории живут в нижней панели — строка сводки её и открывает.
      await tester.tap(find.widgetWithText(ChoiceChip, tr('opTabWallet')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Яндекс Реклама').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('opPickCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Реклама').first);
      await tester.pumpAndSettle();

      // А теперь уходим на карту, где рекламы нет и быть не может.
      await tester.tap(find.widgetWithText(ChoiceChip, tr('opTabWallet')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Карта maib').first);
      await tester.pumpAndSettle();

      // Сумму набираем на клавишах — вернёмся к ним той же панелью.
      await tester.tap(find.widgetWithText(ChoiceChip, tr('opTabKeys')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('0').first);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Записать'));
      await tester.pumpAndSettle();

      final fresh = store.db.transactions
          .where((t) => !t.id.startsWith('t'))
          .toList();
      expect(fresh, hasLength(1), reason: 'записалась ровно одна новая трата');
      final tx = fresh.single;
      expect(tx.account, 'Карта maib');
      // Рекламы на карте нет: категория СНЯТА, а не просто спрятана из ряда.
      // Иначе она молча уехала бы в запись вместе с тратой.
      expect(tx.category, isNull);
    });
  });
}
