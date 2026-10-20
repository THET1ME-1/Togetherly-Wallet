import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

/// WALLET-1: касание суммы возвращает к клавишам.
///
/// Обращение 236 (19.10.2026): после выбора карты кажется, что к сумме не
/// вернуться. Вкладку «Клавиши» над цифрами не замечают, а руки тянутся к
/// самой сумме.
Store storeOf() => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Наличные', currency: 'MDL')],
    categories: presetCategories(),
  ));

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Касание суммы открывает клавиши', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: OperationScreen(store: storeOf()),
    ));
    await tester.pumpAndSettle();

    // Ушли выбирать категорию: цифр на экране нет
    await tester.tap(find.text(tr('opPickCategory')));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('op-amount')));
    await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget, reason: 'касание суммы вернуло клавиши');
    expect(tester.takeException(), isNull);
  });
}
