import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/plan_screen.dart';

import '../tm_fonts.dart';

/// План у нового человека: записей нет, планировать нечего.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  testWidgets('план на пустой базе', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта Salut', currency: 'MDL')],
        categories: presetCategories(),
      ));
    store.viewer = 'u_me';

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.dark(),
        home: PlanScreen(store: store),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final repaint =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/plan-empty.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
