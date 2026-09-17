import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/language.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/auth_screen.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/widgets/app_sheet.dart';

import '../tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

/// Английский экран входа и лист удаления.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('вход по-английски', (tester) async {
    appLanguage = MoneyLanguage.en;
    tester.view.physicalSize = const Size(393 * 2, 850 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(() => appLanguage = MoneyLanguage.ru);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: AuthScreen(account: Session()),
      ),
    ));
    await tester.pumpAndSettle();
    await save(tester, key, 'auth-en');
  });

  testWidgets('лист удаления по-английски', (tester) async {
    appLanguage = MoneyLanguage.en;
    tester.view.physicalSize = const Size(393 * 2, 620 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(() => appLanguage = MoneyLanguage.ru);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: scheme.surfaceContainerLowest,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                  child: SheetScaffold(
                    icon: Myna.userX,
                    tone: scheme.error,
                    title: tr('deleteAccountTitle'),
                    text: '${tr('deleteAccountText')} '
                        '${tr('deleteAccountPairNote')}',
                    action: tr('deleteAccountAction'),
                    onAction: () {},
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await save(tester, key, 'sheet-delete-en');
  });
}
