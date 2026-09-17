import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/categories_edit.dart';

import '../tm_fonts.dart';

/// Лист правки категории глазами: `flutter test test/preview/category_sheet_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() => Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: presetCategories(),
    ));

  for (final dark in [false, true]) {
    testWidgets(dark ? 'лист категории, тёмная' : 'лист категории, светлая',
        (tester) async {
      tester.view.physicalSize = const Size(420 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
          home: CategoriesEditScreen(store: storeOf()),
        ),
      ));
      await tester.pumpAndSettle();

      // Открываем «Продукты» — расходную, чтобы были видны доли. Список
      // алфавитный, и до неё надо доехать.
      await tester.scrollUntilVisible(
        find.text('Продукты'),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продукты').first);
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final repaint =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await repaint.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/category-sheet-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
