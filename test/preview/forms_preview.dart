import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/budget_edit_screen.dart';
import 'package:togetherly_money/screens/category_pick_screen.dart';
import 'package:togetherly_money/screens/currency_screen.dart';
import 'package:togetherly_money/screens/debt_edit_screen.dart';
import 'package:togetherly_money/screens/recurring_edit_screen.dart';

import '../tm_fonts.dart';

/// Формы экранами: бюджет, выбор категории, регулярное, валюта.
/// `flutter test test/preview/forms_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() {
    final store = Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта Salut', currency: 'MDL')],
        categories: presetCategories(),
      ));
    store.viewer = 'u_me';
    return store;
  }

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget Function(Store store) build, {
    bool dark = true,
  }) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
        home: build(storeOf()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final repaint =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/form-$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('бюджет', (tester) async {
    await shot(tester, 'budget', (store) => BudgetEditScreen(store: store));
  });

  testWidgets('бюджет со своим отрезком', (tester) async {
    await shot(
      tester,
      'budget-custom',
      (store) => BudgetEditScreen(
        store: store,
        current: const Budget(
          category: 'Ремонт',
          limit: 2500,
          currency: 'MDL',
          period: 'custom',
          days: 10,
          startDate: '2026-09-01',
        ),
      ),
    );
  });

  testWidgets('выбор категории', (tester) async {
    await shot(tester, 'category-pick',
        (store) => CategoryPickScreen(store: store, expenseOnly: true));
  });

  testWidgets('регулярная запись', (tester) async {
    await shot(tester, 'recurring', (store) => RecurringEditScreen(store: store));
  });

  testWidgets('новый долг', (tester) async {
    await shot(tester, 'debt', (store) => DebtEditScreen(store: store));
  });

  testWidgets('валюта и курсы', (tester) async {
    await shot(tester, 'currency', (store) {
      store.setRate('USD', 17.3);
      store.setRate('EUR', 19.5);
      return CurrencyScreen(store: store);
    });
  });
}
