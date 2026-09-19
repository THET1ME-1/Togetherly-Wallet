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

/// Кадры «дешифратора» кода на экране приглашения, для глаз: из них
/// собирается GIF (`build/preview/code-anim/*.png`). Шаг кадра — 40 мс.
void main() {
  setUpAll(loadTmFonts);

  testWidgets('кадры анимации кода, тёмная тема', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 420 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    final dir = Directory('build/preview/code-anim')..createSync(recursive: true);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        darkTheme: MoneyTheme.dark(),
        themeMode: ThemeMode.dark,
        home: PairScreen(session: Session(), store: Store(), demoCode: 'KX7M4P'),
      ),
    ));
    for (var f = 0; f < 36; f++) {
      await tester.pump(const Duration(milliseconds: 40));
      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/${f.toString().padLeft(3, '0')}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
