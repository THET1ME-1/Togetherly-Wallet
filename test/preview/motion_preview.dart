import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:togetherly_money/widgets/segmented.dart';

import '../tm_fonts.dart';

/// Кадры движения Wallet для глаз: `build/preview/motion/<сцена>/NNN.png`,
/// шаг 40 мс. Из них собираются GIF.
Future<void> frames(WidgetTester tester, GlobalKey key, String scene, int count,
    {Future<void> Function(int f)? at}) async {
  final dir = Directory('build/preview/motion/$scene')..createSync(recursive: true);
  for (var f = 0; f < count; f++) {
    if (at != null) await at(f);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 1);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/${f.toString().padLeft(3, '0')}.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }
}

Transaction tx(String id, String category, double amount) => Transaction(
      id: id, date: '2026-09-10', kind: TxKind.expense, account: 'Карта',
      currency: 'MDL', amount: -amount, amountBase: -amount, category: category,
      author: 'u_me', payer: 'u_me');

Widget shell(Widget child, {ThemeMode mode = ThemeMode.dark}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: child,
    );

void main() {
  setUpAll(loadTmFonts);

  testWidgets('пара собрана', (tester) async {
    tester.view.physicalSize = const Size(393, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    const pair = Pair(groupId: 'g', members: [
      Member(uid: 'u_me', name: 'Саша'),
      Member(uid: 'u_f', name: 'Федя'),
    ]);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: shell(const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(20),
          child: PairedMoment(pair: pair, me: 'u_me', text: 'Пара собрана: ведите деньги вдвоём'),
        ),
      )),
    ));
    await frames(tester, key, 'pair', 30);
  });

  testWidgets('сегменты', (tester) async {
    tester.view.physicalSize = const Size(393, 90);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    var index = 0;
    late StateSetter set;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: shell(Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: StatefulBuilder(builder: (context, s) {
            set = s;
            return Segmented(titles: const ['Расход', 'Доход', 'Перевод'], index: index, onPick: (_) {});
          }),
        ),
      )),
    ));
    await tester.pump();
    await tester.pump();
    await frames(tester, key, 'segmented', 30, at: (f) async {
      if (f == 3) set(() => index = 2);
      if (f == 16) set(() => index = 1);
    });
  });

  testWidgets('лента: удаление', (tester) async {
    tester.view.physicalSize = const Size(393, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final store = Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта', currency: 'MDL')],
        categories: const [Category(name: 'Продукты'), Category(name: 'Кафе'), Category(name: 'Транспорт')],
        transactions: [tx('a', 'Продукты', 412), tx('b', 'Кафе', 95), tx('c', 'Транспорт', 30)],
      ));
    final period = Period(PeriodKind.all, DateTime(2026, 9, 10));
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: shell(ListenableBuilder(
        listenable: store,
        builder: (context, _) => Scaffold(
          body: LedgerScreen(
            store: store, period: period, onPeriod: (_) {}, filter: const Filter(),
            onFilter: (_) {}, onEdit: (_) {}),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await frames(tester, key, 'ledger', 20, at: (f) async {
      if (f == 2) store.deleteOperation('b');
    });
  });

  testWidgets('разбор: отказ', (tester) async {
    tester.view.physicalSize = const Size(393, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL', last4: '1234')],
      ));
    ParsedNotice n(String body, int m) => parseNotice(
        package: 'md.maib.mobile', title: 'maib', body: body,
        at: DateTime.utc(2026, 9, 12, 14, m).millisecondsSinceEpoch);
    store.addNotice(n('Achitare 300,00 MDL, card *1234, Linella', 30));
    store.addNotice(n('Achitare 120,00 MDL, card *1234, Kaufland', 40));
    await tester.pumpWidget(RepaintBoundary(key: key, child: shell(NoticesReviewScreen(store: store))));
    await tester.pumpAndSettle();
    await frames(tester, key, 'notice', 20, at: (f) async {
      if (f == 2) await tester.tap(find.text('Не надо').first);
    });
  });
}
