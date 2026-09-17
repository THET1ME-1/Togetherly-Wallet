import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/categories.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/stats_screen.dart';

import 'tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

final period = Period.month(DateTime(2026, 9, 15));

Transaction tx(String id, String date, double amount,
        {String? category, TxKind kind = TxKind.expense, String currency = 'MDL'}) =>
    Transaction(
      id: id,
      date: date,
      kind: kind,
      account: 'Карта',
      currency: currency,
      amount: amount,
      amountBase: amount,
      category: category,
      author: 'u_me',
      payer: 'u_me',
    );

Database sample() => Database(
      baseCurrency: 'MDL',
      rates: const {'EUR': 19.5},
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Продукты'), Category(name: 'Кафе')],
      transactions: [
        tx('a', '2026-09-10', -100, category: 'Кафе'),
        tx('b', '2026-09-11', -900, category: 'Продукты'),
        tx('c', '2026-09-12', -50, category: 'Кафе'),
        tx('c2', '2026-09-12', -40, category: 'Кафе'),
        tx('d', '2026-09-09', 20000, category: 'Зарплата', kind: TxKind.income),
        // Сто евро крупнее тысячи лей: сравнение идёт в базовой валюте.
        tx('e', '2026-09-08', -100, category: 'Продукты', currency: 'EUR'),
      ],
    );

Store storeOf([Database? db]) {
  final store = Store()..importBackupForTest(db ?? sample());
  store.viewer = 'u_me';
  return store;
}

Widget app(Widget home) => MaterialApp(theme: MoneyTheme.light(), home: home);

void main() {
  setUpAll(loadTmFonts);

  group('порядок в ленте', () {
    test('по дате — в обе стороны', () {
      final db = sample();
      expect(visible(db, period, sort: LedgerSort.dateDesc).first.id, 'c');
      expect(visible(db, period, sort: LedgerSort.dateAsc).first.id, 'e');
    });

    test('по сумме — в базовой валюте, а не в родной', () {
      final db = sample();
      final big = visible(db, period, sort: LedgerSort.amountDesc);
      // 20 000 доход, потом 100 евро (1 950 лей), потом 900 лей.
      expect(big.take(3).map((t) => t.id), ['d', 'e', 'b']);
      expect(visible(db, period, sort: LedgerSort.amountAsc).first.id, 'c2');
    });

    test('по сумме день не группирует', () {
      expect(ledgerSortByDay(LedgerSort.dateDesc), isTrue);
      expect(ledgerSortByDay(LedgerSort.amountDesc), isFalse);
    });

    testWidgets('порядок меняется из полосы периода', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(Scaffold(
        body: LedgerScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: (_) {},
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.sort));
      await tester.pumpAndSettle();
      expect(find.text('Сначала крупные'), findsOneWidget);
      await tester.tap(find.text('Сначала крупные'));
      await tester.pumpAndSettle();

      // Заголовков дня больше нет: список идёт подряд по сумме. «Сентябрь»
      // остаётся — это подпись периода в полосе сверху.
      expect(find.text('Суббота'), findsNothing);
      expect(find.text('Пятница'), findsNothing);
      expect(find.text('Сентябрь'), findsOneWidget);
    });
  });

  group('порядок в категориях', () {
    test('по сумме, по названию и по числу операций', () {
      final db = sample();
      expect(byCategory(db, period, income: false).first.name, 'Продукты');
      expect(byCategory(db, period, income: false, sort: SliceSort.name).first.name, 'Кафе');
      expect(byCategory(db, period, income: false, sort: SliceSort.count).first.name, 'Кафе');
    });

    testWidgets('порядок меняется из полосы периода', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(Scaffold(
        body: CategoriesScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          onDrill: (_, __, [period]) {},
          onEditCategories: () {},
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.sort));
      await tester.pumpAndSettle();
      expect(find.text('По названию'), findsOneWidget);
      await tester.tap(find.text('По названию'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('числа ведут в ленту', () {
    testWidgets('строка расхода в статистике разворачивается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? got;
      bool? income;
      await tester.pumpWidget(app(Scaffold(
        body: StatsScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          onDrill: (c, i, [period]) {
            got = c ?? 'всё';
            income = i;
          },
        ),
      )));
      await tester.pumpAndSettle();

      // «Расходы» на экране трижды: переключатель стороны, строка потока и
      // сравнение. Строка потока помечена ключом, иначе её не отличить.
      const row = ValueKey('flow-spending');
      await tester.scrollUntilVisible(find.byKey(row), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(row));
      await tester.pumpAndSettle();
      expect(got, 'всё');
      expect(income, isFalse);
    });

    testWidgets('строка дохода на главной разворачивается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool? income;
      var goals = 0;
      await tester.pumpWidget(app(Scaffold(
        body: HomeScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          onAccounts: () {},
          onBudgets: () {},
          onGoals: () => goals++,
          onPlan: () {},
          onDebts: () {},
          onChat: () {},
          onSettings: () {},
          onDrill: (_, i, [period]) => income = i,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('flow-income')));
      await tester.pumpAndSettle();
      expect(income, isTrue);
      expect(goals, 0);
    });

    testWidgets('строка «Отложено на цели» ведёт к целям', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = sample();
      final store = storeOf(Database(
        baseCurrency: db.baseCurrency,
        accounts: db.accounts,
        categories: db.categories,
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
        transactions: [
          ...db.transactions,
          const Transaction(
            id: 'g', date: '2026-09-10', kind: TxKind.transfer,
            account: 'Цель: Отпуск', currency: 'MDL', amount: 2000, amountBase: 2000,
            author: 'u_me', payer: 'u_me',
          ),
        ],
      ));

      var goals = 0;
      await tester.pumpWidget(app(Scaffold(
        body: HomeScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onAccounts: () {},
          onBudgets: () {},
          onGoals: () => goals++,
          onPlan: () {},
          onDebts: () {},
          onChat: () {},
          onSettings: () {},
          onDrill: (_, __, [period]) {},
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Отложено на цели'));
      await tester.pumpAndSettle();
      expect(goals, 1);
    });
  });

  group('операция открывается', () {
    testWidgets('нажатие по строке ленты отдаёт саму операцию', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Transaction? opened;
      await tester.pumpWidget(app(Scaffold(
        body: LedgerScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: (op) => opened = op,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Кафе').first);
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
      expect(opened!.category, 'Кафе');
    });

    testWidgets('в плоском порядке строка тоже открывается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Transaction? opened;
      await tester.pumpWidget(app(Scaffold(
        body: LedgerScreen(
          store: storeOf(),
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: (op) => opened = op,
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Myna.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сначала мелкие'));
      await tester.pumpAndSettle();

      // В порядке «сначала мелкие» самая маленькая трата — кафе, и она
      // стоит первой строкой.
      await tester.tap(find.text('Кафе').first);
      await tester.pumpAndSettle();
      expect(opened, isNotNull);
    });
  });
}
