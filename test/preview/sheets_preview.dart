import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/widgets/app_sheet.dart';

import '../tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

/// Съёмка листов подтверждения: роспуск пары, удаление аккаунта, выход.
/// `flutter test test/preview/sheets_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget sheet, {
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(393 * 2, 620 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
        home: Builder(
          builder: (context) {
            final scheme = Theme.of(context).colorScheme;
            return Scaffold(
              backgroundColor: scheme.surfaceContainerLowest,
              body: Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: scheme.surfaceContainerLow,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    // Ручка листа: её рисует сам showModalBottomSheet, здесь
                    // повторяем, чтобы кадр совпадал с приложением.
                    Container(
                      width: 32,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    sheet,
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/sheet-$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('роспуск пары', (tester) async {
    await shot(
      tester,
      'disband',
      Builder(
        builder: (context) => SheetScaffold(
          icon: Myna.heartCrack,
          tone: Theme.of(context).colorScheme.error,
          title: 'Распустить пару?',
          text: 'Общий учёт с Линелла прекратится. Записи останутся у вас '
              'обоих, но с этой минуты каждый ведёт свои. Собраться снова '
              'можно новым кодом.',
          action: 'Распустить',
          onAction: () {},
        ),
      ),
    );
  });

  testWidgets('удаление аккаунта', (tester) async {
    final typed = TextEditingController(text: 'Удалить');
    addTearDown(typed.dispose);
    await shot(
      tester,
      'delete',
      Builder(
        builder: (context) {
          final scheme = Theme.of(context).colorScheme;
          return SheetScaffold(
            icon: Myna.userX,
            tone: scheme.error,
            title: 'Удалить аккаунт?',
            text: 'Аккаунт общий с Togetherly: вместе с деньгами исчезнет и '
                'он — воспоминания, чат, виджеты. Пара распустится, общие '
                'записи останутся у партнёра. Вернуть будет нечего.',
            action: 'Удалить навсегда',
            onAction: () {},
            child: TextField(
              controller: typed,
              decoration: InputDecoration(
                labelText: 'Введите слово «Удалить»',
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
        },
      ),
    );
  });

  testWidgets('выход из аккаунта, тёмная', (tester) async {
    await shot(
      tester,
      'signout-dark',
      SheetScaffold(
        icon: Myna.logout,
        title: 'Выйти из аккаунта?',
        text: 'Записи останутся и на устройстве, и на сервере. Синхронизация '
            'остановится, пока вы не войдёте снова.',
        action: 'Выйти',
        onAction: () {},
      ),
      dark: true,
    );
  });
}
