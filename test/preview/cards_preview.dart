import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';

import '../tm_fonts.dart';

/// Съёмка карт: счёт перестал быть строкой. Данные выдуманы.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша');
  const you = Member(uid: 'u_you', name: 'Линелла');

  Transaction tx(String id, String account, double amount, {String currency = 'MDL'}) =>
      Transaction(
        id: id,
        date: '2026-09-10',
        kind: amount > 0 ? TxKind.income : TxKind.expense,
        account: account,
        currency: currency,
        amount: amount,
        amountBase: currency == 'MDL' ? amount : amount * 19.5,
        author: 'u_me',
        payer: 'u_me',
      );

  final db = Database(
    baseCurrency: 'MDL',
    rates: const {'EUR': 19.5},
    pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
    accounts: const [
      Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true, last4: '4568',
          brand: CardBrand.mastercard, design: 0),
      Account(name: 'Карта maib', currency: 'MDL', last4: '8413',
          brand: CardBrand.visa, design: 4),
      Account(name: 'Моя копилка', currency: 'EUR', last4: '2210',
          brand: CardBrand.mir, kind: AccountKind.savings, owner: 'u_me', design: 1),
      Account(name: 'Наличные', currency: 'MDL', kind: AccountKind.cash, design: 3),
      Account(name: 'Кредитка', currency: 'MDL', last4: '0071',
          brand: CardBrand.mastercard, kind: AccountKind.credit, design: 6),
    ],
    transactions: [
      tx('a', 'Общий кошелёк', 18652.11),
      tx('b', 'Карта maib', 25841.10),
      tx('c', 'Моя копилка', 1120, currency: 'EUR'),
      tx('d', 'Моя копилка', 4300),
      tx('e', 'Наличные', 1240.55),
      tx('f', 'Кредитка', -3480.90),
    ],
  );

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('карты ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 1100 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final store = Store()..importBackupForTest(db);
      store.viewer = me.uid;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: AccountsScreen(store: store, onEdit: (_) {}, onAccountOps: (_) {}),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 32));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/cards-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
