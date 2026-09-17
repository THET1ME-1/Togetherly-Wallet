import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';

import '../tm_fonts.dart';

/// Общий баланс: свёрнут, развёрнут и отбор счетов.
/// `flutter test test/preview/balance_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() => Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [
        Account(name: 'Наличные', currency: 'MDL'),
        Account(name: 'Карта maib', currency: 'MDL', last4: '1234'),
      ],
      categories: const [Category(name: 'Продукты')],
      transactions: [
        const Transaction(
          id: 'i1', date: '2026-09-01', kind: TxKind.income,
          account: 'Карта maib', currency: 'MDL', amount: 18500,
          amountBase: 18500,
        ),
        for (var day = 2; day <= 12; day++)
          Transaction(
            id: 'e$day',
            date: '2026-09-${day.toString().padLeft(2, '0')}',
            kind: TxKind.expense,
            account: day.isEven ? 'Карта maib' : 'Наличные',
            currency: 'MDL',
            amount: -120.0 * day,
            amountBase: -120.0 * day,
            category: 'Продукты',
          ),
      ],
    ));

  Widget app(Store store) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) => HomeScreen(
              store: store,
              period: Period.month(DateTime(2026, 9, 12)),
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
        ),
      );

  testWidgets('свёрнут, развёрнут и отбор', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    final key = GlobalKey();

    Future<void> take(String name) async {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    await tester.pumpWidget(RepaintBoundary(key: key, child: app(store)));
    await tester.pumpAndSettle();
    await take('balance-closed');

    await tester.tap(find.text('Общий баланс'));
    await tester.pumpAndSettle();
    await take('balance-open');

    await tester.tap(find.byTooltip('Какие счета считать'));
    await tester.pumpAndSettle();
    await take('balance-filter');
  });
}
