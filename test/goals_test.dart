import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/widgets/member_badge.dart';

import 'tm_fonts.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Transaction onGoal(String id, String goal, double amount,
        {String payer = 'u_me', String currency = 'MDL'}) =>
    Transaction(
      id: id,
      date: '2026-09-10',
      kind: TxKind.transfer,
      account: goalAccountOf(goal),
      currency: currency,
      amount: amount,
      amountBase: amount,
      author: payer,
      payer: payer,
    );

Database sample({List<Goal> goals = const [], List<Transaction> extra = const []}) =>
    Database(
      baseCurrency: 'MDL',
      pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: const [Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true)],
      goals: goals,
      transactions: extra,
    );

Store pairedStore(Database db) {
  final store = Store()..importBackupForTest(db);
  store.syncEnabled = true;
  store.viewer = me.uid;
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  group('вклады в цель', () {
    test('накоплено считается по счёту цели, а не по записи о цели', () {
      final db = sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
        extra: [
          onGoal('g1', 'Отпуск', 2500),
          onGoal('g2', 'Отпуск', 1500, payer: you.uid),
        ],
      );
      final p = progressOf(db, db.goals.first);
      expect(p.saved, 4000);
      expect(p.byMember[me.uid], 2500);
      expect(p.byMember[you.uid], 1500);
      expect(p.left, 6000);
      expect(p.share, closeTo(0.4, 0.0001));
      expect(p.done, isFalse);
    });

    test('снятое уменьшает и общее, и вклад того, кто снял', () {
      final db = sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
        extra: [
          onGoal('g1', 'Отпуск', 2500),
          onGoal('g2', 'Отпуск', -500),
        ],
      );
      final p = progressOf(db, db.goals.first);
      expect(p.saved, 2000);
      expect(p.byMember[me.uid], 2000);
    });

    test('цель закрыта, когда накоплено дотянуло до суммы', () {
      final db = sample(
        goals: const [Goal(name: 'Кольцо', target: 3000, currency: 'MDL')],
        extra: [onGoal('g1', 'Кольцо', 3000)],
      );
      final p = progressOf(db, db.goals.first);
      expect(p.done, isTrue);
      expect(p.left, 0);
      expect(p.perDay, isNull);
    });

    test('вклад в другой валюте приводится к валюте цели', () {
      final db = Database(
        baseCurrency: 'MDL',
        rates: const {'EUR': 19.5},
        goals: const [Goal(name: 'Греция', target: 1000, currency: 'EUR')],
        transactions: [onGoal('g1', 'Греция', 1950, currency: 'MDL')],
      );
      // 1950 леев по курсу 19,5 — это ровно сотня евро.
      expect(progressOf(db, db.goals.first).saved, 100);
    });

    test('срок считается календарными сутками, а дневная доля — от остатка', () {
      final db = sample(
        goals: const [
          Goal(name: 'Отпуск', target: 10000, currency: 'MDL', deadline: '2026-09-22')
        ],
        extra: [onGoal('g1', 'Отпуск', 2000)],
      );
      final p = progressOf(db, db.goals.first, today: DateTime(2026, 9, 12, 23, 40));
      expect(p.daysLeft, 10);
      expect(p.perDay, 800);
      expect(p.overdue, isFalse);
    });

    test('просроченная цель видна просроченной, а не закрытой', () {
      final db = sample(
        goals: const [
          Goal(name: 'Ремонт', target: 5000, currency: 'MDL', deadline: '2026-09-01')
        ],
      );
      final p = progressOf(db, db.goals.first, today: DateTime(2026, 9, 12));
      expect(p.daysLeft, -11);
      expect(p.overdue, isTrue);
      expect(p.perDay, isNull);
    });

    test('накопленное на счёте цели видно и без записи о цели', () {
      // Так лежат данные Орбиты: счёт с приставкой есть, записи о сумме нет.
      final db = sample(extra: [onGoal('g1', 'Подушка', 7300)]);
      final all = allGoals(db);
      expect(all.length, 1);
      expect(all.first.goal.name, 'Подушка');
      expect(all.first.hasTarget, isFalse);
      expect(all.first.saved, 7300);
    });

    test('впереди то, что копится, и раньше — то, чему ближе срок', () {
      final db = sample(
        goals: const [
          Goal(name: 'Собрано', target: 100, currency: 'MDL', deadline: '2026-09-13'),
          Goal(name: 'Дальний', target: 900, currency: 'MDL', deadline: '2026-12-01'),
          Goal(name: 'Близкий', target: 900, currency: 'MDL', deadline: '2026-09-20'),
        ],
        extra: [onGoal('g1', 'Собрано', 100)],
      );
      final names = allGoals(db, today: DateTime(2026, 9, 12))
          .map((p) => p.goal.name)
          .toList();
      expect(names, ['Близкий', 'Дальний', 'Собрано']);
    });
  });

  group('перевод в цель', () {
    test('вклад уводит деньги с кошелька и кладёт их на счёт цели', () {
      final store = pairedStore(sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
      ));
      store.contributeToGoal(store.db.goals.first, from: 'Общий кошелёк', amount: 1500);

      final db = store.db;
      expect(db.transactions.length, 2);
      // Кошелёк ушёл в минус на ту же сумму: деньги не появились из воздуха.
      final wallet = balances(db).firstWhere((a) => a.name == 'Общий кошелёк');
      expect(wallet.converted, -1500);
      expect(goalsTotal(db), 1500);
      expect(progressOf(db, db.goals.first).byMember[me.uid], 1500);
      // Обе половины перевода уезжают на сервер.
      expect(store.outbox.where((k) => k.startsWith('tx:')).length, 2);
    });

    test('снятие возвращает деньги на кошелёк', () {
      final store = pairedStore(sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
        extra: [onGoal('g1', 'Отпуск', 2000)],
      ));
      store.withdrawFromGoal(store.db.goals.first, to: 'Общий кошелёк', amount: 800);

      final db = store.db;
      expect(progressOf(db, db.goals.first).saved, 1200);
      expect(balances(db).firstWhere((a) => a.name == 'Общий кошелёк').converted, 800);
    });

    test('нулевой и отрицательный вклад не пишется вовсе', () {
      final store = pairedStore(sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
      ));
      store.contributeToGoal(store.db.goals.first, from: 'Общий кошелёк', amount: 0);
      store.contributeToGoal(store.db.goals.first, from: 'Общий кошелёк', amount: -5);
      expect(store.db.transactions, isEmpty);
    });

    test('цель уезжает на сервер своим ключом', () {
      final store = pairedStore(sample());
      store.saveGoal(const Goal(name: 'Отпуск', target: 10000, currency: 'MDL'));
      expect(store.outbox, contains('goal:Отпуск'));
      store.clearOutbox(store.outbox.toSet());
      store.deleteGoal('Отпуск');
      expect(store.outbox, contains('goal:Отпуск'));
      expect(store.db.goals, isEmpty);
    });

    test('цель с сервера приезжает дельтой, своя из очереди не затирается', () {
      final store = pairedStore(sample());
      store.saveGoal(const Goal(name: 'Своя', target: 100, currency: 'MDL'));
      store.applyRemote({
        'now': 42,
        'goals': [
          {'name': 'Своя', 'target': 999, 'currency': 'MDL', 'deadline': ''},
          {'name': 'Чужая', 'target': 5000, 'currency': 'MDL', 'deadline': '2027-01-01'},
        ],
      });
      final names = {for (final g in store.db.goals) g.name: g};
      expect(names['Своя']!.target, 100, reason: 'своя правка ещё не уехала');
      expect(names['Чужая']!.target, 5000);
      expect(names['Чужая']!.deadline, '2027-01-01');
    });
  });

  group('экран целей', () {
    Widget app(Store store, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: GoalsScreen(store: store),
        );

    testWidgets('вклад каждого подписан бейджем', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = pairedStore(sample(
        goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
        extra: [
          onGoal('g1', 'Отпуск', 2500),
          onGoal('g2', 'Отпуск', 1500, payer: you.uid),
        ],
      ));
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text('Отпуск'), findsOneWidget);
      expect(find.byType(MemberBadge), findsNWidgets(2));
      // Имя, а не «Вы»: подпись у обоих одного рода.
      expect(find.text('Саша'), findsOneWidget);
      expect(find.text('Линелла'), findsOneWidget);
      expect(find.text('Вложить'), findsOneWidget);
    });

    testWidgets('у одиночки бейджей нет', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = Store()
        ..importBackupForTest(Database(
          baseCurrency: 'MDL',
          accounts: const [Account(name: 'Карта', currency: 'MDL')],
          goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
          transactions: [onGoal('g1', 'Отпуск', 2500, payer: '')],
        ));
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.byType(MemberBadge), findsNothing);
    });

    testWidgets('пустой экран объясняет, зачем цели', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(pairedStore(sample())));
      await tester.pumpAndSettle();
      expect(find.text('Ни одной цели'), findsOneWidget);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('собирается на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = pairedStore(sample(
          goals: const [
            Goal(name: 'Отпуск в Греции', target: 45000, currency: 'MDL',
                deadline: '2027-06-01'),
            Goal(name: 'Подушка', target: 0, currency: 'MDL'),
          ],
          extra: [
            onGoal('g1', 'Отпуск в Греции', 12500),
            onGoal('g2', 'Отпуск в Греции', 9800, payer: you.uid),
            onGoal('g3', 'Подушка', 4300),
          ],
        ));

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(store, mode: mode),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
