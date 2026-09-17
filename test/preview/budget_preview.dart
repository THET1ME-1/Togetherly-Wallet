import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/debts_screen.dart';
import 'package:togetherly_money/screens/plan_screen.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/recurring_screen.dart';

import '../tm_fonts.dart';

/// Съёмка экранов семейного бюджета: план, долги, конверты, регулярное.
/// Данные выдуманы — снимки можно показывать.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша', color: 0xFFB8E0C8);
  const you = Member(uid: 'u_you', name: 'Линелла', color: 0xFFDCD2F0);

  String day(int shift) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1)
        .add(Duration(days: shift))
        .toIso8601String()
        .substring(0, 10);
  }

  String weekAgo(int days) => DateTime.now()
      .subtract(Duration(days: days))
      .toIso8601String()
      .substring(0, 10);

  Transaction tx(String id, String date, double amount,
          {String account = 'Карта', String? category, TxKind kind = TxKind.expense}) =>
      Transaction(
        id: id,
        date: date,
        kind: kind,
        account: account,
        currency: 'MDL',
        amount: amount,
        amountBase: amount,
        category: category,
        author: 'u_me',
        payer: 'u_me',
      );

  final month = day(0).substring(0, 7);

  final db = Database(
    baseCurrency: 'MDL',
    pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
    accounts: const [
      Account(name: 'Карта', currency: 'MDL'),
      Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
    ],
    categories: const [
      Category(name: 'Продукты', bucket: Bucket.needs),
      Category(name: 'Квартплата', bucket: Bucket.needs),
      Category(name: 'Кафе', bucket: Bucket.wants),
      Category(name: 'Такси'),
    ],
    budgets: const [
      Budget(category: 'Кафе', limit: 900, currency: 'MDL', period: 'weekly',
          rollover: true),
      Budget(category: 'Продукты', limit: 8000, currency: 'MDL', period: 'monthly'),
    ],
    goals: const [
      Goal(name: 'Подушка', target: 60000, currency: 'MDL', kind: GoalKind.reserve,
          months: 6),
      Goal(name: 'Отпуск в Греции', target: 45000, currency: 'MDL',
          deadline: '2026-12-20'),
    ],
    debts: const [
      Debt(name: 'Микрозайм', kind: DebtKind.microloan, principal: 5000, rate: 120,
          minPayment: 1500, currency: 'MDL'),
      Debt(name: 'Кредитка', kind: DebtKind.card, principal: 24000, rate: 24.9,
          minPayment: 1200, currency: 'MDL', dueDay: 15),
      Debt(name: 'Ипотека', kind: DebtKind.mortgage, principal: 600000, rate: 8.5,
          minPayment: 5000, currency: 'MDL', dueDay: 5),
    ],
    recurring: [
      Recurring(id: 'r1', name: 'Квартплата', amount: 2400, currency: 'MDL',
          account: 'Карта', interval: 'monthly', nextDate: day(35), kind: 'expense',
          active: true, category: 'Квартплата'),
      Recurring(id: 'r2', name: 'В подушку', amount: 1500, currency: 'MDL',
          account: 'Карта', interval: 'monthly', nextDate: day(36), kind: 'goal',
          active: true, target: 'Подушка'),
      Recurring(id: 'r3', name: 'Зарплата', amount: 20000, currency: 'MDL',
          account: 'Карта', interval: 'monthly', nextDate: day(31), kind: 'income',
          active: true),
      Recurring(id: 'r4', name: 'Кредитка', amount: 1200, currency: 'MDL',
          account: 'Карта', interval: 'monthly', nextDate: day(45), kind: 'debt',
          active: true, target: 'Кредитка'),
    ],
    plan: [
      PlanItem(month: month, kind: PlanItemKind.category, name: 'Продукты',
          amount: 7500),
      PlanItem(month: month, kind: PlanItemKind.category, name: 'Квартплата',
          amount: 2400),
      PlanItem(month: month, kind: PlanItemKind.category, name: 'Кафе', amount: 3600),
      PlanItem(month: month, kind: PlanItemKind.goal, name: 'Подушка', amount: 1500),
      PlanItem(month: month, kind: PlanItemKind.debt, name: 'Микрозайм', amount: 1500),
      PlanItem(month: month, kind: PlanItemKind.debt, name: 'Кредитка', amount: 1200),
    ],
    transactions: [
      tx('i1', day(1), 20000, kind: TxKind.income, category: 'Зарплата'),
      tx('e1', day(2), -6480.55, category: 'Продукты'),
      tx('e2', day(3), -2400, category: 'Квартплата'),
      tx('e3', day(4), -1840, category: 'Кафе'),
      tx('e4', day(5), -320, category: 'Такси'),
      tx('w1', weekAgo(8), -200, category: 'Кафе'),
      tx('w2', weekAgo(3), -400, category: 'Кафе'),
      Transaction(
        id: 'd1', date: day(6), kind: TxKind.transfer,
        account: debtAccountOf('Кредитка'), currency: 'MDL',
        amount: 4000, amountBase: 4000, author: 'u_me', payer: 'u_me',
      ),
      Transaction(
        id: 'g1', date: day(6), kind: TxKind.transfer,
        account: goalAccountOf('Подушка'), currency: 'MDL',
        amount: 24000, amountBase: 24000, author: 'u_me', payer: 'u_me',
      ),
      // Прошлые месяцы: нужны, чтобы подушка считалась в месяцах расходов.
      for (final back in [1, 2, 3])
        tx('n$back', DateTime(DateTime.now().year, DateTime.now().month - back, 10)
            .toIso8601String().substring(0, 10), -9800, category: 'Продукты'),
    ],
  );

  Future<void> shoot(WidgetTester tester, String name, Widget home,
      {ThemeMode mode = ThemeMode.light, double height = 852}) async {
    tester.view.physicalSize = Size(393 * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        darkTheme: MoneyTheme.dark(),
        themeMode: mode,
        home: home,
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 32));

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.6);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Store storeOf() {
    final store = Store()..importBackupForTest(db);
    store.viewer = me.uid;
    return store;
  }

  testWidgets('план', (t) async =>
      shoot(t, 'plan', PlanScreen(store: storeOf()), height: 1300));
  testWidgets('план тёмный', (t) async =>
      shoot(t, 'plan-dark', PlanScreen(store: storeOf()),
          mode: ThemeMode.dark, height: 1300));
  testWidgets('долги', (t) async =>
      shoot(t, 'debts', DebtsScreen(store: storeOf()), height: 1500));
  testWidgets('конверты', (t) async =>
      shoot(t, 'envelopes', BudgetsScreen(store: storeOf()), height: 900));
  testWidgets('регулярное', (t) async =>
      shoot(t, 'recurring', RecurringScreen(store: storeOf()), height: 900));

  testWidgets('главная', (t) async => shoot(
        t,
        'home-budget',
        Scaffold(
          body: HomeScreen(
            store: storeOf(),
            period: Period.month(),
            onPeriod: (_) {},
            onAccounts: () {},
            onBudgets: () {},
            onGoals: () {},
            onPlan: () {},
            onDebts: () {},
            onChat: () {},
            onSettings: () {},
            onDrill: (_, __, [period]) {},
          ),
        ),
        height: 2200,
      ));
}
