import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import '../tm_fonts.dart';

/// Экран записи целиком: помещается ли без прокрутки.
/// `flutter test test/preview/new_op_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() => Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [
        Account(name: 'Карта', currency: 'MDL'),
        Account(name: 'Наличные', currency: 'MDL'),
      ],
      categories: presetCategories(),
    ));

  Store pairStore() {
    const me = Member(uid: 'u_me', name: 'Саша');
    const you = Member(uid: 'u_you', name: 'JB SHARAN');
    final store = Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        accounts: [
          const Account(
              name: 'Карта Sanamacos',
              currency: 'USD',
              last4: '4417',
              brand: CardBrand.visa),
          const Account(name: 'Наличные', currency: 'MDL'),
        ],
        categories: presetCategories(),
        pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      ));
    store.viewer = me.uid;
    return store;
  }

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('запись в паре, ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: OperationScreen(store: pairStore()),
        ),
      ));
      await tester.pumpAndSettle();

      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      debugPrint('пара ${mode.name}: остаток прокрутки '
          '${(scrollable.controller?.position.maxScrollExtent ?? 0).toStringAsFixed(1)}');

      await tester.runAsync(() async {
        final repaint =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await repaint.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/new-op-pair-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  // Рост экрана взят от обычного телефона, а не от планшета: прокрутки не
  // должно быть именно здесь.
  for (final size in [(393.0, 852.0, 'обычный'), (360.0, 740.0, 'короткий')]) {
    testWidgets('запись, ${size.$3}', (tester) async {
      tester.view.physicalSize = Size(size.$1 * 3, size.$2 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          home: OperationScreen(store: storeOf()),
        ),
      ));
      await tester.pumpAndSettle();

      // Сколько ещё можно прокрутить: ноль значит «влезло целиком».
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      final extra = scrollable.controller?.position.maxScrollExtent ?? 0;
      debugPrint('${size.$3}: остаток прокрутки ${extra.toStringAsFixed(1)}');

      await tester.runAsync(() async {
        final repaint =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await repaint.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/new-op-${size.$3}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  testWidgets('запись, перевод', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: OperationScreen(store: storeOf()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Перевод'));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final repaint =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/new-op-перевод.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
