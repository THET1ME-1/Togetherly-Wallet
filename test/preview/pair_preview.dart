import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/pair_screen.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Съёмка экрана приглашения. Код и QR настоящие: экран рисует то же, что
/// увидит человек, просто сервер за ним не спрашивается.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('пара ${mode.name}', (tester) async {
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
          home: PairScreen(session: Session(), store: Store(), demoCode: 'KX7M4P'),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Показать QR'));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/pair-${mode.name}.png').writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
