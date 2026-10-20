import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/session.dart';

import 'tm_fonts.dart';

/// WALLET-7 и WALLET-8: с открытой клавиатурой заголовок налезал на поля.
///
/// Обращение 350 (Samsung, регистрация) и снимок владельца с планшета
/// (горизонтально, вход): шапка «Заводим аккаунт» с подписью лежала поверх
/// полей почты и пароля. Поля не помещались над клавиатурой и вылезали вниз,
/// на заголовок.

/// Открыть экран с клавиатурой высотой [keyboard] точек и перейти на шаг.
Future<void> open(
  WidgetTester tester, {
  required Size size,
  required double ratio,
  required double keyboard,
  required String step,
}) async {
  tester.view.physicalSize = size * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: WelcomeScreen(account: Session()),
  ));
  await tester.tap(find.text(step));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }

  // Клавиатура открылась: человек нажал на поле
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * ratio);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Ни заголовок, ни подпись под ним не лежат поверх полей ввода.
void expectNothingOnFields(WidgetTester tester, List<String> heads) {
  final fields = find.byType(TextField).evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList();
  expect(fields, isNotEmpty);
  for (final head in heads) {
    for (final element in find.text(head).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (rect.isEmpty) continue;
      for (final field in fields) {
        expect(rect.overlaps(field), isFalse, reason: '«$head» лежит поверх поля $field');
      }
    }
  }
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Регистрация на телефоне: с клавиатурой шапка не на полях (WALLET-8)',
      (tester) async {
    // Samsung из обращения 350: 1080×2340 при плотности 2,625
    await open(tester,
        size: const Size(411, 891), ratio: 2.625, keyboard: 430, step: tr('welcomeStart'));
    expectNothingOnFields(tester, [tr('authRegisterTitle'), tr('authRegisterNote')]);
  });

  testWidgets('Вход на планшете горизонтально: шапка не на полях (WALLET-7)',
      (tester) async {
    await open(tester,
        size: const Size(1280, 800), ratio: 1.5, keyboard: 380, step: tr('authSignIn'));
    expectNothingOnFields(tester, [tr('authSignInTitle'), tr('authSignInNote')]);
  });

  testWidgets('Регистрация на маленьком телефоне с клавиатурой', (tester) async {
    await open(tester,
        size: const Size(360, 640), ratio: 3.0, keyboard: 300, step: tr('welcomeStart'));
    expectNothingOnFields(tester, [tr('authRegisterTitle'), tr('authRegisterNote')]);
  });

  testWidgets('Без клавиатуры шапка на месте', (tester) async {
    await open(tester,
        size: const Size(411, 891), ratio: 2.625, keyboard: 0, step: tr('welcomeStart'));
    expect(find.text(tr('authRegisterTitle')), findsOneWidget);
    expect(find.text(tr('welcomeHaveAccount')), findsOneWidget);
  });
}
