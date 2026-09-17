import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Экран входа с дверями провайдеров.
/// `flutter test test/preview/auth_providers_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('вход ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 960 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: WelcomeScreen(account: Session()),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/auth-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
