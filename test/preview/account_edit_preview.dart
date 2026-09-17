import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/account_edit_screen.dart';

import '../tm_fonts.dart';

/// Экран правки счёта глазами.
/// `flutter test test/preview/account_edit_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() => Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта Salut', currency: 'MDL')],
    ));

  for (final dark in [false, true]) {
    testWidgets(dark ? 'экран счёта, тёмная' : 'экран счёта, светлая',
        (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 1900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showAccountSheet(
                    context,
                    store: storeOf(),
                    name: 'Карта Salut',
                  ),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final repaint =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await repaint.toImage(pixelRatio: 1.4);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/account-edit-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
