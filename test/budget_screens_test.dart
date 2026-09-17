import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/debts.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/debts_screen.dart';
import 'package:togetherly_money/screens/plan_screen.dart';
import 'package:togetherly_money/screens/recurring_screen.dart';
import 'package:togetherly_money/widgets/rules_sheet.dart';

import 'tm_fonts.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

/// Месяц берётся нынешний: экраны плана и конвертов считают «сейчас», и
/// прибитая дата ломала бы их каждый месяц.
String _day(int shift) {
  final now = DateTime.now();
  final at = DateTime(now.year, now.month, 1).add(Duration(days: shift));
  return at.toIso8601String().substring(0, 10);
}

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

Database sample() => Database(
      baseCurrency: 'MDL',
      pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: const [
        Account(name: 'Карта', currency: 'MDL'),
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      ],
      categories: const [
        Category(name: 'Продукты', bucket: Bucket.needs),
        Category(name: 'Кафе', bucket: Bucket.wants),
      ],
      budgets: const [
        Budget(category: 'Кафе', limit: 900, currency: 'MDL', period: 'weekly',
            rollover: true),
        Budget(category: 'Продукты', limit: 8000, currency: 'MDL', period: 'monthly'),
      ],
      goals: const [
        Goal(name: 'Подушка', target: 0, currency: 'MDL', kind: GoalKind.reserve, months: 6),
      ],
      debts: const [
        Debt(name: 'Кредитка', kind: DebtKind.card, principal: 24000, rate: 24.9,
            minPayment: 1200, currency: 'MDL', dueDay: 15),
        Debt(name: 'Микрозайм', kind: DebtKind.microloan, principal: 5000, rate: 120,
            minPayment: 1500, currency: 'MDL'),
      ],
      recurring: [
        Recurring(id: 'r1', name: 'Квартплата', amount: 2400, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: _day(40),
            kind: 'expense', active: true, category: 'Продукты'),
        Recurring(id: 'r2', name: 'В подушку', amount: 1500, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: _day(45),
            kind: 'goal', active: true, target: 'Подушка'),
      ],
      plan: [
        PlanItem(month: _day(0).substring(0, 7), kind: PlanItemKind.category,
            name: 'Продукты', amount: 8000),
        PlanItem(month: _day(0).substring(0, 7), kind: PlanItemKind.goal,
            name: 'Подушка', amount: 1500),
      ],
      transactions: [
        tx('i1', _day(1), 20000, kind: TxKind.income, category: 'Зарплата'),
        tx('e1', _day(2), -6000, category: 'Продукты'),
        tx('e2', _day(3), -400, category: 'Кафе'),
        tx('e3', _day(4), -300, category: 'Такси'),
        Transaction(
          id: 'd1', date: _day(5), kind: TxKind.transfer,
          account: debtAccountOf('Кредитка'), currency: 'MDL',
          amount: 4000, amountBase: 4000, author: 'u_me', payer: 'u_me',
        ),
        Transaction(
          id: 'g1', date: _day(5), kind: TxKind.transfer,
          account: goalAccountOf('Подушка'), currency: 'MDL',
          amount: 9000, amountBase: 9000, author: 'u_me', payer: 'u_me',
        ),
      ],
    );

Store storeOf([Database? db]) {
  final store = Store()..importBackupForTest(db ?? sample());
  store.syncEnabled = true;
  store.viewer = me.uid;
  return store;
}

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: home,
    );

void main() {
  setUpAll(loadTmFonts);

  group('план на месяц', () {
    testWidgets('показывает нераспределённое', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(PlanScreen(store: storeOf())));
      await tester.pumpAndSettle();

      expect(find.text('План на месяц'), findsOneWidget);
      // Доли правила 50/30/20 уехали в статистику: они разбирают уже
      // потраченное, а здесь заголовок обещает план (14.09.2026).
      expect(find.text('Нужды'), findsNothing);

      // Незапланированная трата видна отдельной строкой — она лежит ниже
      // сгиба, ListView её не строит, поэтому долистываем.
      await tester.scrollUntilVisible(find.text('Такси'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Такси'), findsOneWidget);
      expect(find.text('Не было в плане'), findsWidgets);
    });

    testWidgets('раскладка по правилу заполняет план', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Пустой план, но есть доход и прошлые траты.
      final db = sample();
      final store = storeOf(Database(
        baseCurrency: db.baseCurrency,
        accounts: db.accounts,
        categories: db.categories,
        goals: db.goals,
        transactions: db.transactions,
      ));

      await tester.pumpWidget(app(PlanScreen(store: store)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Разложить по правилу').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Разложить').last);
      await tester.pumpAndSettle();

      expect(store.db.plan, isNotEmpty);
      // План уезжает на сервер: это общее имущество пары.
      expect(store.outbox.any((k) => k.startsWith('plan:')), isTrue);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('план собирается на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(PlanScreen(store: storeOf()), mode: mode),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('долги', () {
    testWidgets('порядок погашения переключается и называет первый долг',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(DebtsScreen(store: storeOf())));
      await tester.pumpAndSettle();

      expect(find.text('Лавина'), findsOneWidget);
      expect(find.text('Снежный ком'), findsOneWidget);
      expect(find.textContaining('Сперва самая дорогая ставка'), findsOneWidget);

      await tester.tap(find.text('Снежный ком'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Сперва самый маленький остаток'), findsOneWidget);
    });

    testWidgets('платёж уводит деньги с кошелька', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(app(DebtsScreen(store: store)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Заплатить').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Заплатить').last);
      await tester.pumpAndSettle();

      // Микрозайм дороже всех: лавина ставит его первым, платёж идёт по нему.
      final st = stateOf(store.db, store.db.debts.firstWhere((d) => d.name == 'Микрозайм'));
      expect(st.paid, 1500);
    });

    testWidgets('долг без покрытия процентов говорит прямо', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        debts: [
          Debt(name: 'Кредитка', principal: 100000, rate: 24, minPayment: 1500,
              currency: 'MDL'),
        ],
      ));
      await tester.pumpWidget(app(DebtsScreen(store: store)));
      await tester.pumpAndSettle();
      expect(find.textContaining('не перекрывает проценты'), findsOneWidget);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('долги собираются на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(DebtsScreen(store: storeOf()), mode: mode),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('регулярное', () {
    testWidgets('обязательное в месяц сводится к одному числу', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(RecurringScreen(store: storeOf())));
      await tester.pumpAndSettle();

      expect(find.text('Обязательное в месяц'), findsOneWidget);
      expect(find.text('Квартплата'), findsOneWidget);
      expect(find.text('В подушку'), findsOneWidget);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('регулярное собирается на 320dp при шрифте 1.3, ${mode.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(RecurringScreen(store: storeOf()), mode: mode),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('конверты', () {
    testWidgets('перенос остатка подписан словами', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Прошлая неделя: на кафе ушло 200 из 900, значит перенос +700.
      final db = sample();
      final store = storeOf(Database(
        baseCurrency: db.baseCurrency,
        accounts: db.accounts,
        categories: db.categories,
        budgets: db.budgets,
        transactions: [
          tx('a', DateTime.now().subtract(const Duration(days: 7))
              .toIso8601String().substring(0, 10), -200, category: 'Кафе'),
        ],
      ));

      await tester.pumpWidget(app(BudgetsScreen(store: store)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Перенесено с прошлой недели'), findsOneWidget);
      expect(find.textContaining('на неделю'), findsOneWidget);
    });
  });

  group('правила', () {
    testWidgets('доли правила сохраняются и сумма всегда сто', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRules(context, store),
            child: const Text('открыть'),
          ),
        ),
      )));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Нужды 50%'), findsOneWidget);
      await tester.drag(find.byType(Slider).first, const Offset(-100, 0));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Сохранить'), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      final r = store.db.rules;
      expect(r.needsBp + r.wantsBp + r.savingsBp, 10000);
      expect(r.needsBp < 5000, isTrue);
      expect(store.outbox, contains('settings:base'));
    });

    testWidgets('округление без цели не включается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Целей нет вовсе: складывать округление некуда.
      final store = storeOf(const Database(baseCurrency: 'MDL'));
      await tester.pumpWidget(app(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRules(context, store),
            child: const Text('открыть'),
          ),
        ),
      )));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('До 50'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Сначала заведите цель'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Сохранить'), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(store.db.rules.roundUpStep, 0);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('правила собираются на 320dp при шрифте 1.3, ${mode.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = storeOf();
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showRules(context, store),
                  child: const Text('открыть'),
                ),
              ),
            ),
            mode: mode,
          ),
        ));
        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
