import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import '../tm_fonts.dart';

/// Счёт в леях, трата в долларах: как это видно человеку.
/// `flutter test test/preview/usd_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() {
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        rates: {'USD': 17.30, 'RUB': 0.205},
        accounts: [
          Account(
            name: 'Карта maib',
            currency: 'MDL',
            last4: '1234',
            bank: 'md.maib.mobile',
            brand: CardBrand.visa,
            design: 3,
          ),
        ],
        categories: [
          Category(name: 'Подписки'),
          Category(name: 'Продукты'),
        ],
        transactions: [
          Transaction(
            id: 'i1',
            date: '2026-09-01',
            kind: TxKind.income,
            account: 'Карта maib',
            currency: 'MDL',
            amount: 18500,
            amountBase: 18500,
            category: 'Продукты',
          ),
          Transaction(
            id: 'e1',
            date: '2026-09-11',
            kind: TxKind.expense,
            account: 'Карта maib',
            currency: 'MDL',
            amount: -417.60,
            amountBase: -417.60,
            category: 'Продукты',
            note: 'LINELLA CENTRU',
          ),
        ],
      ));
    store.viewer = 'u_me';
    store.setSenderMode('md.maib.mobile', NoticeMode.auto);

    // Тот самый случай: банк списал десять долларов с молдавской карты.
    store.addNotice(parseNotice(
      package: 'md.maib.mobile',
      title: 'maib',
      body: 'Achitare 10,00 USD, card *1234, APPLE. Disponibil: 4 512,30 MDL',
      at: DateTime(2026, 9, 12, 14, 30).millisecondsSinceEpoch,
    ));
    return store;
  }

  Future<void> shoot(WidgetTester tester, String name, Widget screen) async {
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        // Без Scaffold часть текста рисуется «стилем ошибки» — красным с
        // жёлтым подчёркиванием. В приложении Scaffold даёт оболочка.
        home: Scaffold(body: screen),
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

  testWidgets('лента с тратой в долларах', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await shoot(
      tester,
      'usd-ledger',
      LedgerScreen(
        store: store,
        period: Period.month(DateTime(2026, 9, 12)),
        onPeriod: (_) {},
        filter: const Filter(),
        onFilter: (_) {},
        onEdit: (_) {},
      ),
    );
  });

  testWidgets('счёт с двумя валютами', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await shoot(
      tester,
      'usd-accounts',
      AccountsScreen(store: store, onEdit: (_) {}, onAccountOps: (_) {}),
    );
  });

  testWidgets('запись траты в долларах', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        rates: {'USD': 17.30},
        accounts: [
          Account(name: 'Карта maib', currency: 'MDL', last4: '1234'),
          Account(name: 'Payoneer', currency: 'USD'),
        ],
        categories: [Category(name: 'Подписки')],
      ));

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: OperationScreen(store: store),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('USD'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('0').first);
      await tester.pump();
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 32));

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.6);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/preview/usd-entry.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
