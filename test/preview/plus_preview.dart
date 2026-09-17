import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import '../tm_fonts.dart';

/// Съёмка витрины Wallet+: обе темы, вид до покупки и после.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    PlusService plus, {
    ThemeMode mode = ThemeMode.light,
    double height = 1500,
  }) async {
    tester.view.physicalSize = Size(393, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        darkTheme: MoneyTheme.dark(),
        themeMode: mode,
        home: PlusScreen(plus: plus),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 32));

    await tester.runAsync(() async {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await b.toImage(pixelRatio: 1.6);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  PlusService paid() => PlusService()
    ..setForTest(PlusPass(
      until: DateTime(2027, 3, 1).millisecondsSinceEpoch,
      source: PlusSource.play,
      checkedAt: DateTime.now().millisecondsSinceEpoch,
    ));

  testWidgets('витрина светлая', (t) async => shoot(t, 'plus-light', PlusService()));
  testWidgets('витрина тёмная',
      (t) async => shoot(t, 'plus-dark', PlusService(), mode: ThemeMode.dark));
  testWidgets('подписка оформлена',
      (t) async => shoot(t, 'plus-active', paid(), mode: ThemeMode.dark, height: 1300));
}
