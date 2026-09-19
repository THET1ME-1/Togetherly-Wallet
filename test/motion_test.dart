import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/notices_review_screen.dart';
import 'package:togetherly_money/screens/pair_screen.dart';
import 'package:togetherly_money/widgets/motion.dart';
import 'package:togetherly_money/widgets/segmented.dart';

import 'tm_fonts.dart';

/// Движение Wallet (19.09.2026): формы и списки больше не меняются скачком.
/// Здесь стережём то, что ломается молча: удалённая строка доигрывает уход и
/// исчезает, карточка списания уходит, не отдавая своё состояние соседке,
/// подложка сегментов едет, а при «меньше движения» всё стоит сразу.

Transaction tx(String id, String category) => Transaction(
      id: id,
      date: '2026-09-10',
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -100,
      amountBase: -100,
      category: category,
      author: 'u_me',
      payer: 'u_me',
    );

Store ledgerStore() => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Карта', currency: 'MDL')],
    categories: const [Category(name: 'Продукты'), Category(name: 'Кафе'), Category(name: 'Транспорт')],
    transactions: [tx('a', 'Продукты'), tx('b', 'Кафе'), tx('c', 'Транспорт')],
  ));

final _period = Period(PeriodKind.all, DateTime(2026, 9, 10));

Widget ledger(Store store, {bool still = false}) => MaterialApp(
      theme: MoneyTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: const Size(393, 852), disableAnimations: still),
        // В приложении ленту перестраивает оболочка по сигналу хранилища.
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Scaffold(
            body: LedgerScreen(
              store: store,
              period: _period,
              onPeriod: (_) {},
              filter: const Filter(),
              onFilter: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ),
    );

ParsedNotice notice(String body, int minute) => parseNotice(
      package: 'md.maib.mobile',
      title: 'maib',
      body: body,
      at: DateTime.utc(2026, 9, 12, 14, minute).millisecondsSinceEpoch,
    );

void main() {
  setUpAll(loadTmFonts);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('лента', () {
    testWidgets('удалённая трата доигрывает уход на месте и исчезает', (tester) async {
      phone(tester);
      final store = ledgerStore();
      await tester.pumpWidget(ledger(store));
      await tester.pumpAndSettle();

      store.deleteOperation('b');
      await tester.pump();
      expect(find.byType(Collapse), findsOneWidget, reason: 'строка пропала за кадр');
      expect(find.text('Кафе'), findsOneWidget, reason: 'призрак стоит на прежнем месте');

      await tester.pump(const Duration(milliseconds: 180));
      expect(find.byType(Collapse), findsOneWidget, reason: 'уход ещё идёт');

      await tester.pumpAndSettle();
      expect(find.byType(Collapse), findsNothing);
      expect(find.text('Кафе'), findsNothing);
      expect(find.text('Продукты'), findsOneWidget);
      expect(find.text('Транспорт'), findsOneWidget);
    });

    testWidgets('новая трата раздвигает список, а не выскакивает', (tester) async {
      phone(tester);
      final store = ledgerStore();
      await tester.pumpWidget(ledger(store));
      await tester.pumpAndSettle();

      store.saveOperation(tx('d', 'Кафе').copyWith(id: 'd'));
      await tester.pump();
      final grow = find.byWidgetPredicate((w) => w is Entry && w.id == 'd' && w.grow);
      expect(grow, findsOneWidget);
      expect(
        find.descendant(of: grow, matching: find.byType(SizeTransition)),
        findsWidgets,
      );
      await tester.pumpAndSettle();
      expect(find.text('Кафе'), findsNWidgets(2));
    });

    testWidgets('последняя трата дня уводит весь день с заголовком', (tester) async {
      phone(tester);
      final store = ledgerStore();
      store.saveOperation(tx('z', 'Кафе').copyWith(id: 'z', date: '2026-09-08'));
      await tester.pumpWidget(ledger(store));
      await tester.pumpAndSettle();
      expect(find.text('8'), findsOneWidget, reason: 'день 8 сентября на месте');

      store.deleteOperation('z');
      await tester.pump();
      expect(find.byKey(const ValueKey('gone-day-2026-09-08')), findsOneWidget,
          reason: 'день уходит одним куском');
      await tester.pumpAndSettle();
      expect(find.text('8'), findsNothing);
      expect(find.byType(Collapse), findsNothing);
    });

    testWidgets('при «меньше движения» удалённое уходит сразу', (tester) async {
      phone(tester);
      final store = ledgerStore();
      await tester.pumpWidget(ledger(store, still: true));
      await tester.pump();
      await tester.pump();

      store.deleteOperation('b');
      await tester.pump();
      await tester.pump();
      expect(find.text('Кафе'), findsNothing);
    });
  });

  group('разбор списаний', () {
    Store noticeStore() {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          accounts: [Account(name: 'Карта', currency: 'MDL', last4: '1234')],
        ));
      store.addNotice(notice('Achitare 300,00 MDL, card *1234, Linella', 30));
      store.addNotice(notice('Achitare 120,00 MDL, card *1234, Kaufland', 40));
      return store;
    }

    testWidgets('отклонённая карточка уезжает, соседка остаётся собой', (tester) async {
      phone(tester);
      final store = noticeStore();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: NoticesReviewScreen(store: store),
      ));
      await tester.pumpAndSettle();
      expect(store.pendingNotices.length, 2);

      await tester.tap(find.text('Не надо').first);
      await tester.pump();
      expect(store.pendingNotices.length, 1, reason: 'решение принято сразу');
      final leaving = find.byWidgetPredicate((w) => w is Leaving && w.leaving);
      expect(leaving, findsOneWidget, reason: 'карточка пропала за кадр');
      expect((tester.widget<Leaving>(leaving)).slide, -1, reason: 'отказ уезжает влево');

      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is Leaving), findsOneWidget);
      // На экране ровно та карточка, что осталась в очереди, — со своим
      // магазином, а не с данными ушедшей.
      final left = store.pendingNotices.single.merchant!;
      final gone = left.contains('Linella') ? 'Kaufland' : 'Linella';
      expect(find.textContaining(left), findsWidgets);
      expect(find.textContaining(gone), findsNothing);
    });

    testWidgets('смахнутая влево карточка отклонена и уходит один раз', (tester) async {
      phone(tester);
      final store = noticeStore();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: NoticesReviewScreen(store: store),
      ));
      await tester.pumpAndSettle();

      await tester.fling(find.byType(Dismissible).first, const Offset(-500, 0), 2000);
      await tester.pumpAndSettle();
      expect(store.pendingNotices.length, 1);
      expect(find.byWidgetPredicate((w) => w is Leaving && w.leaving), findsNothing,
          reason: 'смахнутую жест уже увёл, провожать второй раз нечего');
    });
  });

  group('сегменты', () {
    testWidgets('подложка едет к новому выбору, надпись одна', (tester) async {
      var index = 0;
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, set) => Segmented(
              titles: const ['Расход', 'Доход', 'Перевод'],
              index: index,
              onPick: (i) => set(() => index = i),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      final pill = find.byKey(const ValueKey('segmented-pill'));
      double left() => tester.getTopLeft(pill).dx;
      final from = left();

      await tester.tap(find.text('Перевод'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = left();
      await tester.pumpAndSettle();
      final to = left();

      expect(to, greaterThan(from));
      expect(mid, greaterThan(from), reason: 'подложка не поехала');
      expect(mid, lessThan(to), reason: 'подложка прыгнула за кадр');
      expect(find.text('Перевод'), findsOneWidget, reason: 'надпись двоится');
    });
  });

  group('пара собрана', () {
    testWidgets('аватарки сходятся, галочка и слова появляются', (tester) async {
      const pair = Pair(groupId: 'g', members: [
        Member(uid: 'u_me', name: 'Саша'),
        Member(uid: 'u_f', name: 'Федя'),
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: const Scaffold(
          body: PairedMoment(pair: pair, me: 'u_me', text: 'Пара собрана'),
        ),
      ));
      await tester.pump();
      final start = tester.getCenter(find.text('Ф'));
      await tester.pump(const Duration(milliseconds: 1000));
      final end = tester.getCenter(find.text('Ф'));
      expect(end.dx, lessThan(start.dx), reason: 'аватарка партнёра не подъехала');
      expect(find.text('Пара собрана'), findsOneWidget);
    });
  });

  group('переход «сквозь»', () {
    testWidgets('на время перехода живут оба экрана, потом один', (tester) async {
      var id = 1;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
          builder: (context, set) => Scaffold(
            body: FadeThrough(id: id, child: Text('экран $id')),
            floatingActionButton: FloatingActionButton(onPressed: () => set(() => id = 2)),
          ),
        ),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('экран 1'), findsOneWidget);
      expect(find.text('экран 2'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('экран 1'), findsNothing);
      expect(find.text('экран 2'), findsOneWidget);
    });
  });

  testWidgets('встряска возвращает поле на место', (tester) async {
    var n = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, set) => Scaffold(
          body: Center(child: Shake(trigger: n, child: const Text('поле'))),
          floatingActionButton: FloatingActionButton(onPressed: () => set(() => n++)),
        ),
      ),
    ));
    final rest = tester.getCenter(find.text('поле'));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getCenter(find.text('поле')).dx, isNot(rest.dx), reason: 'не качнулось');
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('поле')), rest);
  });
}
