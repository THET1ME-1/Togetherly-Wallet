import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Съёмка приветствия: карты, регистрация и вход — один экран, три состояния.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });

  for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('приветствие ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
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
      // Фон-сетка приходит ассетом: без runAsync картинка в кадр не попадает.
      await tester.runAsync(() async {
        final at = tester.element(find.byType(WelcomeScreen));
        await precacheImage(const AssetImage('assets/bg/welcome_grid.png'), at);
        await precacheImage(const AssetImage('assets/brand/togetherly.png'), at);
      });
      await tester.pump(const Duration(milliseconds: 900));
      await shoot(tester, key, 'welcome-${mode.name}');

      // «Начать» — карты уезжают, на их месте поля.
      await tester.tap(find.text('Начать'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await shoot(tester, key, 'welcome-register-${mode.name}');

      await tester.tap(find.text('Войти'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await shoot(tester, key, 'welcome-signin-${mode.name}');
    });
  }
}
