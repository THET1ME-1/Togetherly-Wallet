import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/design/myna_solid.dart';

import '../tm_fonts.dart';

/// Нижняя навигация: контур в покое, заливка на выбранном разделе.
/// `flutter test test/preview/nav_fill_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const glyphs = [
    (Myna.home, MynaSolid.home, 'Главная'),
    (Myna.chartPie, MynaSolid.chartPie, 'Категории'),
    (Myna.chartBar, MynaSolid.chartBar, 'Статистика'),
    (Myna.fileText, MynaSolid.fileText, 'Лента'),
  ];

  for (final dark in [false, true]) {
    testWidgets(dark ? 'навигация, тёмная' : 'навигация, светлая',
        (tester) async {
      tester.view.physicalSize = const Size(880 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
          home: Builder(builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: scheme.surfaceContainer,
              body: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var selected = 0; selected < 4; selected++)
                    NavigationBar(
                      selectedIndex: selected,
                      backgroundColor: scheme.surfaceContainer,
                      onDestinationSelected: (_) {},
                      destinations: [
                        for (final (outline, solid, label) in glyphs)
                          NavigationDestination(
                            icon: Icon(outline),
                            selectedIcon: Icon(solid),
                            label: label,
                          ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/nav-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
