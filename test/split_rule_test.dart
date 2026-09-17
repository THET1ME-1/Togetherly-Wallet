import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/split.dart';
import 'package:togetherly_money/widgets/split_rule_sheet.dart';

import 'tm_fonts.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Store pairedStore({SplitMode mode = SplitMode.equal, int mine = 5000, int theirs = 5000}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      pair: Pair(
        groupId: 'g1',
        members: [
          Member(uid: me.uid, name: me.name, incomeShareBp: mine),
          Member(uid: you.uid, name: you.name, incomeShareBp: theirs),
        ],
        baseCurrency: 'MDL',
        defaultSplit: mode,
      ),
      accounts: const [Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true)],
    ));
  store.syncEnabled = true;
  store.viewer = me.uid;
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  group('правило дележа', () {
    test('правило и доли уезжают на сервер одной правкой настроек', () {
      final store = pairedStore();
      store.setSplitRule(SplitMode.income,
          shares: {me.uid: 6000, you.uid: 4000});
      expect(store.db.pair.defaultSplit, SplitMode.income);
      expect(store.db.pair.byUid(me.uid)!.incomeShareBp, 6000);
      expect(store.outbox, contains('settings:base'));
    });

    test('дележ по доходу считается по заданным долям', () {
      final store = pairedStore(mode: SplitMode.income, mine: 6500, theirs: 3500);
      const op = Transaction(
        id: 't1', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -1000, amountBase: -1000,
        author: 'u_me', payer: 'u_me', split: SplitMode.income,
      );
      // splitOf отдаёт величину доли, знак несёт сама операция.
      final parts = splitOf(op, store.db.pair);
      expect(parts[me.uid], 650);
      expect(parts[you.uid], 350);
    });

    test('пока доли не заданы, дележ по доходу честно отдаёт всё плательщику', () {
      // Трое по 50% дают 150% — расчёт в такое не верит и не выдумывает долей.
      final store = Store()
        ..importBackupForTest(const Database(
          pair: Pair(groupId: 'g1', members: [
            Member(uid: 'a', name: 'А'),
            Member(uid: 'b', name: 'Б'),
            Member(uid: 'c', name: 'В'),
          ]),
        ));
      const op = Transaction(
        id: 't1', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -900, amountBase: -900,
        author: 'a', payer: 'a', split: SplitMode.income,
      );
      expect(splitOf(op, store.db.pair), {'a': 900.0});
    });

    test('настройки пары приезжают с сервера', () {
      final store = pairedStore();
      store.applyRemote({
        'now': 11,
        'settings': {
          'base_currency': 'EUR',
          'rates': {'MDL': 0.051},
          'default_split': 'income',
          'income_shares': {me.uid: 7000, you.uid: 3000},
        },
      });
      expect(store.db.baseCurrency, 'EUR');
      expect(store.db.rates['MDL'], 0.051);
      expect(store.db.pair.defaultSplit, SplitMode.income);
      expect(store.db.pair.byUid(you.uid)!.incomeShareBp, 3000);
    });

    test('своя неотправленная правка настроек сильнее серверной', () {
      final store = pairedStore();
      store.setSplitRule(SplitMode.payerOnly);
      store.applyRemote({
        'now': 12,
        'settings': {'base_currency': 'EUR', 'default_split': 'equal'},
      });
      expect(store.db.baseCurrency, 'MDL');
      expect(store.db.pair.defaultSplit, SplitMode.payerOnly);
    });

    test('доли приезжают и тогда, когда состав пары не менялся', () {
      final store = pairedStore();
      store.applyRemote({
        'now': 13,
        'settings': {'default_split': 'income', 'income_shares': {me.uid: 8000, you.uid: 2000}},
      });
      expect(store.db.pair.byUid(me.uid)!.incomeShareBp, 8000);
    });
  });

  group('лист правила', () {
    Widget app(Store store, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showSplitRule(context, store),
                child: const Text('открыть'),
              ),
            ),
          ),
        );

    testWidgets('выбор правила сохраняется', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = pairedStore();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('По доходу'));
      await tester.pumpAndSettle();
      // Доли появились сразу: без них «по доходу» ничего не значит.
      expect(find.text('50%'), findsNWidgets(2));

      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(store.db.pair.defaultSplit, SplitMode.income);
    });

    testWidgets('доля второго считается сама и сумма всегда сто', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = pairedStore(mode: SplitMode.income);
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      // Слайдер один: у последнего участника доля не правится.
      expect(find.byType(Slider), findsOneWidget);
      await tester.drag(find.byType(Slider), const Offset(300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();

      final bp = [for (final m in store.db.pair.members) m.incomeShareBp];
      expect(bp.fold<int>(0, (a, b) => a + b), 10000);
      expect(bp.first, greaterThan(5000));
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('собирается на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = pairedStore(mode: SplitMode.income, mine: 6500, theirs: 3500);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(store, mode: mode),
        ));
        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
