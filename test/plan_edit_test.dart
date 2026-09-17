import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/plan_screen.dart';

import 'tm_fonts.dart';

Store storeOf() {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Продукты')],
      plan: [
        PlanItem(
          month: '${DateTime.now().year}-'
              '${DateTime.now().month.toString().padLeft(2, '0')}',
          kind: PlanItemKind.category,
          name: 'Продукты',
          amount: 3000,
        ),
      ],
    ));
  store.viewer = 'u_me';
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('строку плана можно убрать из неё самой', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: PlanScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Продукты'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();

    // Ноль и раньше убирал строку, но догадаться об этом было нельзя.
    await tester.tap(find.text('Убрать из плана'));
    await tester.pumpAndSettle();

    expect(store.db.plan, isEmpty);
  });

  testWidgets('план месяца очищается из шапки', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: PlanScreen(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Очистить план'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Очистить план').last);
    await tester.pumpAndSettle();

    expect(store.db.plan, isEmpty);
  });
}
