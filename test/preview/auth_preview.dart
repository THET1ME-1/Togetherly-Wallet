import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/auth_screen.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Съёмка входа с фоном-ассорти.
/// `flutter test test/preview/auth_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  for (final dark in [false, true]) {
    testWidgets(dark ? 'вход, тёмная' : 'вход, светлая', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 850 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
          home: AuthScreen(account: Session()),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/auth-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
