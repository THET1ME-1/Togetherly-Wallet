import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/design/myna_solid.dart';
import 'package:togetherly_money/widgets/date_wheel_sheet.dart';

import 'tm_fonts.dart';

/// Читается ли то, что нарисовано поверх заливки.
///
/// Сторож `selection_visible_test` отвечает на вопрос «изменилось ли что-то
/// после нажатия», и на этот вопрос выбранный пункт навигации отвечал «да»:
/// подложка появлялась. А значок внутри неё был того же цвета, что подложка, —
/// чёрный по тёмно-серому в тёмной теме и белый по светло-серому в светлой.
/// Человек это описал коротко: «чёрный на чёрном и белый на белом»
/// (14.09.2026). Проверять надо контраст ВНУТРИ элемента.

double _luma(int r, int g, int b) =>
    (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;

/// Доля пикселей области, которые заметно отличаются от её же фона.
///
/// Фон — самый частый цвет: у пилюли это заливка, у строки барабана — её
/// подложка. Всё, что отличается по яркости больше чем на четверть, и есть
/// буквы со значком.
Future<double> inkShare(WidgetTester tester, GlobalKey key, Rect rect) async {
  final image = await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    return b.toImage();
  });
  final data = await tester
      .runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
  final bytes = data!.buffer.asUint8List();
  final width = tester.view.physicalSize.width.round();

  final counts = <int, int>{};
  final lumas = <double>[];
  for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
    for (var x = rect.left.round(); x < rect.right.round(); x++) {
      final i = (y * width + x) * 4;
      if (i + 2 >= bytes.length) continue;
      final l = _luma(bytes[i], bytes[i + 1], bytes[i + 2]);
      lumas.add(l);
      counts.update((l * 20).round(), (v) => v + 1, ifAbsent: () => 1);
    }
  }
  if (lumas.isEmpty) return 0;
  final background =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key / 20;
  final ink = lumas.where((l) => (l - background).abs() > 0.25).length;
  return ink / lumas.length;
}

Widget bar(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Myna.home),
              selectedIcon: Icon(MynaSolid.home),
              label: 'Главная',
            ),
            NavigationDestination(icon: Icon(Myna.chartBar), label: 'Отчёты'),
          ],
        ),
      ),
    );

void main() {
  setUpAll(loadTmFonts);

  group('выбранный пункт навигации виден', () {
    for (final (name, theme) in [
      ('светлая', MoneyTheme.light()),
      ('тёмная', MoneyTheme.dark()),
    ]) {
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(key: key, child: bar(theme)));
        await tester.pumpAndSettle();

        // Берём саму пилюлю выбранного пункта, а не весь ряд.
        final rect = tester.getRect(find.byIcon(MynaSolid.home));
        final share = await inkShare(tester, key, rect.inflate(6));
        expect(share, greaterThan(0.04),
            reason: '$name: значок слился с подложкой '
                '(${(share * 100).toStringAsFixed(1)}% пикселей отличаются)');
      });
    }
  });

  group('строка барабана даты читается', () {
    for (final (name, theme) in [
      ('светлая', MoneyTheme.light()),
      ('тёмная', MoneyTheme.dark()),
    ]) {
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showDateWheel(
                      context,
                      title: 'Когда это было',
                      initial: DateTime(2026, 9, 15),
                    ),
                    child: const Text('открыть'),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();

        // Середина барабана — выбранная строка с подложкой.
        final wheel = tester.getRect(find.text('Когда это было'));
        final row = Rect.fromLTRB(
          wheel.left - 40,
          wheel.bottom + 120,
          wheel.right + 40,
          wheel.bottom + 168,
        );
        final share = await inkShare(tester, key, row);
        expect(share, greaterThan(0.02),
            reason: '$name: цифры слились с подложкой '
                '(${(share * 100).toStringAsFixed(1)}%)');
      });
    }
  });
}
