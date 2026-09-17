import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';
import 'package:togetherly_money/widgets/card_tile.dart';
import 'package:togetherly_money/widgets/money_text.dart';

import 'tm_fonts.dart';

void main() {
  setUpAll(loadTmFonts);

  testWidgets('кружок счёта берёт цвет ОФОРМЛЕНИЯ карты', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Небо — пятое оформление в наборе.
    const sky = 4;
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [
          Account(name: 'Карта Salut', currency: 'MDL', design: sky),
        ],
        transactions: [
          Transaction(
            id: 'a',
            date: '2026-09-13',
            kind: TxKind.income,
            account: 'Карта Salut',
            currency: 'MDL',
            amount: 1500,
            amountBase: 1500,
            author: 'u_me',
            payer: 'u_me',
          ),
        ],
      ));
    store.viewer = 'u_me';

    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: AccountsScreen(store: store, onEdit: (_) {}, onAccountOps: (_) {}),
    ));
    await tester.pumpAndSettle();

    final dots = tester.widgetList<LabelDot>(find.byType(LabelDot));
    expect(dots, isNotEmpty);
    expect(
      dots.map((d) => d.color),
      contains(cardDesigns[sky].fill),
      reason: 'выбрал голубую карту — кружок тоже голубой',
    );
  });
}
