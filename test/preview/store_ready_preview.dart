import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/presets.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/screens/settings.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/plus.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Кадры правок 20.10.2026 для глаз: вход с клавиатурой, витрина Wallet+ на
/// iPhone и Android, настройки на iPhone, касание суммы.
///
///     flutter test test/preview/store_ready_preview.dart
///
/// Кадры — в `build/preview/store-ready/`. Клавиатура в кадре не рисуется:
/// под ней пустое место того же цвета, что экран.

class _Fake extends PlusService {
  @override
  Future<List<PlusSeat>> seats() async => const [];
}

final _dir = Directory('build/preview/store-ready')..createSync(recursive: true);

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${_dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<GlobalKey> _host(WidgetTester tester, Widget home, Size size, {double keyboard = 0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: MoneyTheme.light(),
      home: home,
    ),
  ));
  await tester.pump();
  return key;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Store _store() => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Наличные', currency: 'MDL')],
    categories: presetCategories(),
  ));

void main() {
  setUpAll(loadTmFonts);

  for (final (name, size, keyboard, step) in [
    ('вход-телефон-регистрация', const Size(411, 891), 430.0, 'welcomeStart'),
    ('вход-телефон-регистрация-без-клавиатуры', const Size(411, 891), 0.0, 'welcomeStart'),
    ('вход-маленький-регистрация', const Size(360, 640), 300.0, 'welcomeStart'),
    ('вход-планшет-вход', const Size(1280, 800), 380.0, 'authSignIn'),
  ]) {
    testWidgets(name, (tester) async {
      final key = await _host(tester, WelcomeScreen(account: Session()), size);
      await tester.tap(find.text(tr(step)));
      await _settle(tester);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      await _settle(tester);
      await _shot(tester, key, name);
    });
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('витрина ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      final key = await _host(tester, PlusScreen(plus: _Fake()), const Size(393, 852));
      await tester.pumpAndSettle();
      await _shot(tester, key, 'витрина-${platform.name}-верх');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      await _shot(tester, key, 'витрина-${platform.name}-низ');
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('настройки iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final key = await _host(
        tester, SettingsScreen(store: Store()..importBackupForTest(const Database())), const Size(393, 2600));
    await tester.pumpAndSettle();
    await _shot(tester, key, 'настройки-ios');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('сумма открывает клавиши', (tester) async {
    final key = await _host(tester, OperationScreen(store: _store()), const Size(393, 852));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('opPickCategory')));
    await tester.pumpAndSettle();
    await _shot(tester, key, 'операция-1-категории');
    await tester.tap(find.byKey(const ValueKey('op-amount')));
    await tester.pumpAndSettle();
    await _shot(tester, key, 'операция-2-после-касания-суммы');
  });
}
