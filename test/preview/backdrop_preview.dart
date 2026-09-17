import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/icons.dart';
import 'package:togetherly_money/screens/auth_screen.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/widgets/icon_backdrop.dart';

import '../tm_fonts.dart';

/// Два способа успокоить фон: вуаль и размытие.
/// `flutter test test/preview/backdrop_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required double opacity,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(393 * 2, 850 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
        home: Builder(
          builder: (context) => Stack(children: [
            // Цвет темы кладём сами: экран входа на съёмке прозрачен, и без
            // этой подложки тёмный кадр выходил на белом.
            Positioned.fill(
              child: ColoredBox(color: Theme.of(context).colorScheme.surface),
            ),
            Positioned.fill(
              child: IconBackdrop(icons: moneyIconSet(), opacity: opacity),
            ),
            AuthScreen(account: Session(), showBackdrop: false),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/backdrop-$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  // Ни вуали, ни размытия: первое убавляет яркость всему экрану, второе на
  // Impeller рисует чёрный слой с контурами вместо мягкой фактуры. Осталась
  // бледность — её и подбираем.
  for (final step in [(name: 'pale-035', v: 0.035), (name: 'pale-045', v: 0.045), (name: 'pale-060', v: 0.06)]) {
    testWidgets('бледность ${step.v}', (tester) async {
      await shot(tester, step.name, opacity: step.v);
    });
  }

  testWidgets('бледность в тёмной теме', (tester) async {
    await shot(tester, 'dark-060', opacity: 0.06, dark: true);
  });
}
