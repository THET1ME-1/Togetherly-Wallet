import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/widgets/member_badge.dart';

import 'tm_fonts.dart';

/// Лента в паре: кто платил — видно бейджем, а разрез по людям человек
/// включает сам. Умолчание — общая история: пара ведёт деньги вместе, и
/// «только мои» по умолчанию превратило бы общий трекер в два личных.
void main() {
  setUpAll(loadTmFonts);

  const me = 'uid-me';
  const you = 'uid-you';
  final period = Period.month(DateTime(2026, 9, 12));

  Database sample() => Database(
        baseCurrency: 'MDL',
        pair: const Pair(
          groupId: 'grp1',
          members: [
            Member(uid: me, name: 'Саша'),
            Member(uid: you, name: 'Линелла'),
          ],
        ),
        accounts: const [
          Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
        ],
        categories: const [
          Category(name: 'Еда'),
        ],
        transactions: const [
          Transaction(
            id: 't1',
            date: '2026-09-12',
            kind: TxKind.expense,
            account: 'Общий кошелёк',
            currency: 'MDL',
            amount: -137.40,
            amountBase: -137.40,
            category: 'Еда',
            author: me,
            payer: me,
            split: SplitMode.equal,
          ),
          Transaction(
            id: 't2',
            date: '2026-09-11',
            kind: TxKind.expense,
            account: 'Общий кошелёк',
            currency: 'MDL',
            amount: -64.67,
            amountBase: -64.67,
            category: 'Еда',
            author: you,
            payer: you,
            split: SplitMode.income,
          ),
        ],
      );

  Widget app(Store store, Filter filter, ValueChanged<Filter> onFilter,
          {ThemeMode mode = ThemeMode.light}) =>
      MaterialApp(
        theme: MoneyTheme.light(),
        darkTheme: MoneyTheme.dark(),
        themeMode: mode,
        home: Scaffold(
          body: LedgerScreen(
            store: store,
            period: period,
            onPeriod: (_) {},
            filter: filter,
            onFilter: onFilter,
            onEdit: (_) {},
          ),
        ),
      );

  group('разрез по людям', () {
    test('пустой список людей показывает всех', () {
      final db = sample();
      expect(visible(db, period).length, 2);
    });

    test('выбранный человек оставляет только свои операции', () {
      final db = sample();
      final mine = visible(db, period, filter: const Filter(people: {me}));
      expect(mine.map((t) => t.id), ['t1']);
      final theirs = visible(db, period, filter: const Filter(people: {you}));
      expect(theirs.map((t) => t.id), ['t2']);
    });

    test('разрез считается в числе условий отбора', () {
      expect(const Filter(people: {me}).count, 1);
      expect(const Filter(people: {me}).isEmpty, isFalse);
    });
  });

  group('лента в паре', () {
    testWidgets('у операции стоит бейдж плательщика', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = Store()..importBackupForTest(sample());
      store.viewer = me;

      await tester.pumpWidget(app(store, const Filter(), (_) {}));
      await tester.pumpAndSettle();

      // Обе операции подписаны именами: местоимений в бейдже нет.
      expect(find.text('Саша'), findsWidgets);
      expect(find.text('Линелла'), findsWidgets);
      expect(find.byType(MemberBadge), findsWidgets);
      // Слово дележа стоит рядом с бейджем, а не в общей подписи.
      expect(find.text('Поровну'), findsOneWidget);
      expect(find.text('По доходу'), findsOneWidget);
    });

    testWidgets('чип человека переключает разрез', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = Store()..importBackupForTest(sample());
      store.viewer = me;

      Filter got = const Filter();
      await tester.pumpWidget(app(store, got, (f) => got = f));
      await tester.pumpAndSettle();

      expect(find.text('Все'), findsOneWidget);
      expect(find.text('Саша'), findsWidgets);

      await tester.tap(find.text('Саша').first);
      expect(got.people, {me});

      // Повторное нажатие возвращает общую историю: иначе выйти из своего
      // разреза можно было бы только через «Все», а туда ещё надо догадаться.
      await tester.pumpWidget(app(store, got, (f) => got = f));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Саша').first);
      expect(got.people, isEmpty);
    });

    testWidgets('одиночке чипы не показываются', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final solo = sample();
      final store = Store()
        ..importBackupForTest(Database(
          baseCurrency: solo.baseCurrency,
          accounts: solo.accounts,
          categories: solo.categories,
          transactions: solo.transactions,
        ));

      await tester.pumpWidget(app(store, const Filter(), (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Все'), findsNothing);
      expect(find.byType(MemberBadge), findsNothing);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('собирается на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = Store()..importBackupForTest(sample());
        store.viewer = me;

        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(store, const Filter(), (_) {}, mode: mode),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
