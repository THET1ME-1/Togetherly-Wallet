import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/ledger.dart';

import '../tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

/// Съёмка ленты в паре: бейдж плательщика у каждой операции и ряд чипов
/// «Все · Мои · <имя>». Данные выдуманы — снимок можно показывать.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = 'uid-me';
  const you = 'uid-you';
  final period = Period.month(DateTime(2026, 9, 12));

  Transaction op(
    String id,
    String date,
    double sum,
    String category,
    String note,
    String payer,
    SplitMode split, {
    bool secret = false,
    String account = 'Общий кошелёк',
  }) =>
      Transaction(
        id: id,
        date: date,
        kind: sum < 0 ? TxKind.expense : TxKind.income,
        account: account,
        currency: 'MDL',
        amount: sum,
        amountBase: sum,
        category: category,
        note: note,
        author: payer,
        payer: payer,
        split: split,
        secret: secret,
      );

  final db = Database(
    baseCurrency: 'MDL',
    pair: const Pair(
      groupId: 'grp1',
      members: [
        Member(uid: me, name: 'Саша', color: 0xFFB8E0C8),
        Member(uid: you, name: 'Линелла', color: 0xFFDCD2F0),
      ],
    ),
    accounts: const [
      Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      Account(name: 'Моя карта', currency: 'MDL', owner: me),
    ],
    categories: const [
      Category(name: 'Продукты'),
      Category(name: 'Кафе'),
      Category(name: 'Дом'),
      Category(name: 'Подарки'),
      Category(name: 'Зарплата'),
    ],
    transactions: [
      op('t1', '2026-09-12', -217.40, 'Продукты', 'Линелла', me, SplitMode.equal),
      op('t2', '2026-09-12', -84.67, 'Кафе', 'кофе с собой', you, SplitMode.payerOnly),
      op('t3', '2026-09-11', -1450.00, 'Дом', 'интернет за сентябрь', you, SplitMode.income),
      op('t4', '2026-09-11', -320.00, 'Подарки', 'серьги', me, SplitMode.payerOnly,
          secret: true, account: 'Моя карта'),
      op('t5', '2026-09-10', 14500.00, 'Зарплата', '', me, SplitMode.none),
      op('t7', '2026-09-12', -890.00, 'Подарки', 'сюрприз', you, SplitMode.payerOnly,
          secret: true),
      op('t6', '2026-09-09', -62.15, 'Продукты', 'хлеб и молоко', you, SplitMode.equal),
    ],
  );

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('лента в паре ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final store = Store()..importBackupForTest(db);
      store.viewer = me;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: Scaffold(
            body: LedgerScreen(
              store: store,
              period: period,
              onPeriod: (_) {},
              filter: const Filter(viewer: me),
              onFilter: (_) {},
              onEdit: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 32));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/ledger-pair-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  // Лист порядка: он новый, и его стоит посмотреть глазами.
  testWidgets('порядок', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()..importBackupForTest(db);
    store.viewer = me;

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: LedgerScreen(
            store: store,
            period: period,
            onPeriod: (_) {},
            filter: const Filter(viewer: me),
            onFilter: (_) {},
            onEdit: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Myna.sort));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/sort-sheet.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
