import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/widgets/quarters.dart';

import 'tm_fonts.dart';

Database sample() => const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      categories: [
        Category(name: 'Продукты'),
        Category(name: 'Дом'),
        Category(name: 'Зарплата'),
      ],
      transactions: [
        Transaction(
          id: 'e1', date: '2026-09-05', kind: TxKind.expense, account: 'Карта',
          currency: 'MDL', amount: -2480, amountBase: -2480, category: 'Продукты',
        ),
        Transaction(
          id: 'e2', date: '2026-09-06', kind: TxKind.expense, account: 'Карта',
          currency: 'MDL', amount: -1200, amountBase: -1200, category: 'Дом',
        ),
        Transaction(
          id: 'i1', date: '2026-09-01', kind: TxKind.income, account: 'Карта',
          currency: 'MDL', amount: 15000, amountBase: 15000, category: 'Зарплата',
        ),
        // Прошлый месяц: он не должен попадать в отрезок «Месяц».
        Transaction(
          id: 'e3', date: '2026-08-20', kind: TxKind.expense, account: 'Карта',
          currency: 'MDL', amount: -900, amountBase: -900, category: 'Дом',
        ),
      ],
    );

/// Что уехало в ленту при нажатии на квартал.
({String? category, bool income, Period? period})? drilled;

Widget app(Store store) => MaterialApp(
      theme: MoneyTheme.light(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => HomeScreen(
            store: store,
            period: Period.month(DateTime(2026, 9, 12)),
            onPeriod: (_) {},
            onAccounts: () {},
            onBudgets: () {},
            onGoals: () {},
            onPlan: () {},
            onDebts: () {},
            onChat: () {},
            onSettings: () {},
            onDrill: (category, income, [period]) {
              drilled = (category: category, income: income, period: period);
            },
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadTmFonts);

  /// Разряды в приложении разделены не обычным пробелом: сверяемся тем же
  /// форматом, которым рисуем, иначе тест ищет несуществующую строку.
  String sum(double v) => formatAmount(v, decimals: 0);

  /// Ищем только внутри карточки кварталов: слово «Доход» есть и в денежном
  /// потоке выше.
  Finder inCard(Finder what) => find.descendant(
        of: find.ancestor(
          of: find.byType(Quarters),
          matching: find.byType(Material),
        ).first,
        matching: what,
      );

  /// Главная длинная: без высокого окна карточка кварталов просто не строится,
  /// и тест ищет то, чего ещё нет на свете.
  Future<void> open(WidgetTester tester, Store store) async {
    tester.view.physicalSize = const Size(393, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(Quarters), 200);
    await tester.pumpAndSettle();
  }

  group('кварталы категорий', () {
    testWidgets('по умолчанию расходы, сумма и названия внутри', (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      expect(inCard(find.text('Расход')), findsOne);
      expect(find.byType(Quarters), findsOne);
      // Сумма внутри квартала — без копеек и крупно.
      expect(inCard(find.text(sum(2480))), findsOne);
      expect(inCard(find.text(sum(1200))), findsOne);
      expect(inCard(find.text('Продукты')), findsWidgets);
      // Доходная категория в расходной стороне не показывается.
      expect(inCard(find.text(sum(15000))), findsNothing);
    });

    testWidgets('касание переключает на доходы', (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      await tester.tap(find.text('Категории'));
      await tester.pumpAndSettle();

      expect(inCard(find.text('Доход')), findsOne);
      expect(inCard(find.text(sum(15000))), findsOne);
      expect(inCard(find.text(sum(2480))), findsNothing);
    });

    testWidgets('отрезок у блока свой и переживает уход с экрана',
        (tester) async {
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      // Отрезок задаётся кнопкой в углу блока и живёт в хранилище: экран его
      // не держит, поэтому уход и возврат ничего не теряют.
      store.setPeriod('categories', Period(PeriodKind.all, DateTime(2026, 9, 12)));
      await tester.pumpAndSettle();

      // За всё время «Дом» вырастает на трату прошлого месяца.
      expect(inCard(find.text(sum(2100))), findsOne);
      expect(store.periodOf('categories').kind, PeriodKind.all);
    });

    test('каждый блок помнит свой отрезок отдельно', () {
      final store = Store()..importBackupForTest(sample());

      store.setPeriod('categories', Period(PeriodKind.week, DateTime(2026, 9, 12)));
      store.setPeriod('flow', Period(PeriodKind.year, DateTime(2026, 9, 12)));

      expect(store.periodOf('categories').kind, PeriodKind.week);
      expect(store.periodOf('flow').kind, PeriodKind.year);
      // Незнакомый блок берёт умолчание, а не чужой отрезок.
      expect(store.periodOf('budgets').kind, PeriodKind.month);
    });
  });

  group('переход в ленту', () {
    testWidgets('квартал уносит категорию, сторону и отрезок', (tester) async {
      drilled = null;
      final store = Store()..importBackupForTest(sample());
      // Неделя, в которую попали продукты: пустой отрезок кварталов не даёт.
      store.setPeriod('categories', Period(PeriodKind.week, DateTime(2026, 9, 5)));
      await open(tester, store);

      await tester.tap(inCard(find.text('Продукты')));
      await tester.pumpAndSettle();

      expect(drilled?.category, 'Продукты');
      expect(drilled?.income, isFalse);
      // Отрезок тот же, что выбран в блоке: лента не должна показывать свой
      // прежний месяц.
      expect(drilled?.period?.kind, PeriodKind.week);
      expect(drilled?.period?.contains('2026-09-05'), isTrue);
    });

    testWidgets('на доходной стороне уносится доход', (tester) async {
      drilled = null;
      final store = Store()..importBackupForTest(sample());
      await open(tester, store);

      await tester.tap(find.text('Категории'));
      await tester.pumpAndSettle();
      await tester.tap(inCard(find.text('Зарплата')));
      await tester.pumpAndSettle();

      expect(drilled?.category, 'Зарплата');
      expect(drilled?.income, isTrue);
    });
  });
}
