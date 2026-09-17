import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/plan.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/plan_screen.dart';
import 'package:togetherly_money/screens/stats_screen.dart';

import 'tm_fonts.dart';

/// План человек заводит САМ.
///
/// «Зачем мне создан план, который ещё не удаляется... я просил сделать ПУСТОЙ
/// экран, где планы создаёт сам пользователь» (14.09.2026). До этого экран с
/// пустым планом показывал разбор дохода по правилу и траты месяца строками —
/// со стороны это выглядело готовым планом, которого никто не заводил и убрать
/// который было нечем: корзина чистила `db.plan`, а траты оставались.

Store storeOf({List<PlanItem> plan = const []}) => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Карта', currency: 'MDL')],
    categories: presetCategories(),
    plan: plan,
    transactions: [
      Transaction(
        id: 'in',
        kind: TxKind.income,
        account: 'Карта',
        category: 'Работа',
        amount: 25985.12,
        amountBase: 25985.12,
        currency: 'MDL',
        date: iso(DateTime.now()),
      ),
      Transaction(
        id: 'rent',
        kind: TxKind.expense,
        account: 'Карта',
        category: 'Жильё',
        amount: -1000,
        amountBase: -1000,
        currency: 'MDL',
        date: iso(DateTime.now()),
      ),
      Transaction(
        id: 'food',
        kind: TxKind.expense,
        account: 'Карта',
        category: 'Продукты',
        amount: -5,
        amountBase: -5,
        currency: 'MDL',
        date: iso(DateTime.now()),
      ),
    ],
  ));

Widget app(Widget home) => MaterialApp(theme: MoneyTheme.light(), home: home);

void main() {
  setUpAll(loadTmFonts);

  test('трата месяца не делает план непустым', () {
    final plan = planOf(storeOf().db, DateTime.now());
    expect(plan.isEmpty, isTrue, reason: 'строк человек не заводил');
    expect(plan.rows, isNotEmpty, reason: 'траты месяца в модели остаются');
  });

  test('своя строка делает план живым', () {
    final month = monthKey(DateTime.now());
    final store = storeOf(plan: [
      PlanItem(
        month: month,
        kind: PlanItemKind.category,
        name: 'Жильё',
        amount: 4000,
      ),
    ]);
    expect(planOf(store.db, DateTime.now()).isEmpty, isFalse);
  });

  testWidgets('пустой план показывает только приглашение', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(PlanScreen(store: storeOf())));
    await tester.pumpAndSettle();

    expect(find.text(tr('planEmpty')), findsOneWidget);

    // Ни разбора дохода, ни трат строками, ни чисел плана: всё это читалось
    // как план, который завели за человека.
    expect(find.text(tr('planWhereIncomeGoes')), findsNothing);
    expect(find.text(tr('planNotPlanned')), findsNothing);
    expect(find.text('Жильё'), findsNothing);
    expect(find.text('Продукты'), findsNothing);

    // Корзины тоже нет: убирать нечего.
    expect(find.byTooltip(tr('planClear')), findsNothing);
  });

  testWidgets('со своей строкой возвращаются строки и корзина',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf(plan: [
      PlanItem(
        month: monthKey(DateTime.now()),
        kind: PlanItemKind.category,
        name: 'Жильё',
        amount: 4000,
      ),
    ]);
    await tester.pumpWidget(app(PlanScreen(store: store)));
    await tester.pumpAndSettle();

    expect(find.text(tr('planEmpty')), findsNothing);
    expect(find.byTooltip(tr('planClear')), findsOneWidget);
    expect(find.text('Жильё'), findsWidgets);

    // Правило 50/30/20 на этом экране не живёт НИ ПРИ КАКОМ плане: оно
    // разбирает уже потраченное, а заголовок обещает план.
    expect(find.text(tr('planWhereIncomeGoes')), findsNothing);
  });

  testWidgets('правило 50/30/20 живёт в статистике', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(Scaffold(
      body: StatsScreen(
        store: storeOf(),
        period: Period.month(DateTime.now()),
        onPeriod: (_) {},
      ),
    )));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(tr('planWhereIncomeGoes')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(tr('planWhereIncomeGoes')), findsOneWidget);
    expect(find.text(tr('bucketNeeds')), findsOneWidget);
    expect(find.text(tr('bucketWants')), findsOneWidget);
    expect(find.text(tr('bucketSavings')), findsOneWidget);
  });

  testWidgets('корзина убирает план целиком', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf(plan: [
      PlanItem(
        month: monthKey(DateTime.now()),
        kind: PlanItemKind.category,
        name: 'Жильё',
        amount: 4000,
      ),
      PlanItem(
        month: monthKey(DateTime.now()),
        kind: PlanItemKind.category,
        name: 'Продукты',
        amount: 2000,
      ),
    ]);
    await tester.pumpWidget(app(PlanScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(tr('planClear')));
    await tester.pumpAndSettle();
    // Лист подтверждения: главная кнопка повторяет слово решения.
    await tester.tap(find.widgetWithText(FilledButton, tr('planClear')));
    await tester.pumpAndSettle();

    expect(store.db.plan, isEmpty, reason: 'строки плана должны уйти из базы');
    expect(planOf(store.db, DateTime.now()).isEmpty, isTrue);
    expect(find.text(tr('planEmpty')), findsOneWidget,
        reason: 'экран возвращается к пустому');
  });

  testWidgets('строка плана убирается по одной', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf(plan: [
      PlanItem(
        month: monthKey(DateTime.now()),
        kind: PlanItemKind.category,
        name: 'Жильё',
        amount: 4000,
      ),
      PlanItem(
        month: monthKey(DateTime.now()),
        kind: PlanItemKind.category,
        name: 'Продукты',
        amount: 2000,
      ),
    ]);
    await tester.pumpWidget(app(PlanScreen(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Жильё').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('planRowRemove')));
    await tester.pumpAndSettle();

    expect(store.db.plan.where((x) => x.name == 'Жильё'), isEmpty);
    expect(store.db.plan.where((x) => x.name == 'Продукты'), hasLength(1),
        reason: 'убирается ровно одна строка');
  });

  testWidgets('на главной плана нет, пока его не завели', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Доход за месяц есть — и раньше его хватало, чтобы карточка показала
    // «Не распределено» с полосами правила вместо пустого состояния.
    final store = storeOf();
    await tester.pumpWidget(app(HomeScreen(
      store: store,
      period: Period.month(DateTime.now()),
      onPeriod: (_) {},
      onAccounts: () {},
      onBudgets: () {},
      onGoals: () {},
      onPlan: () {},
      onDebts: () {},
      onChat: () {},
      onSettings: () {},
      onNotices: () {},
      onDrill: (_, __, [Period? ___]) {},
    )));
    await tester.pumpAndSettle();

    expect(find.text(tr('noPlan')), findsOneWidget);
    expect(find.text(tr('planLeft')), findsNothing);
    expect(find.text(tr('planAllocated')), findsNothing);
  });
}
