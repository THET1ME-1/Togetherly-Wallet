import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/links.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// Витрина подписки обязана вести на условия и политику.
///
/// Правило App Store 3.1.2(a): у подписки с продлением в самом приложении
/// стоят ссылки на условия использования и политику конфиденциальности. Без
/// них проверка возвращает версию, и подписка не продаётся вовсе.

class _Fake extends PlusService {
  @override
  Future<List<PlusSeat>> seats() async => const [];
}

void main() {
  setUpAll(loadTmFonts);

  test('Сборка App Store ведёт на соглашение Apple, остальные на наши условия', () {
    expect(plusTermsUrl('appstore'), kAppleEula);
    expect(plusTermsUrl('play'), kTerms);
    expect(plusTermsUrl('github'), kTerms);
    expect(plusTermsUrl('rustore'), kTerms);
  });

  test('О продлении говорят только сборки магазинов', () {
    expect(plusRenewalNote('appstore'), 'plusRenewApple');
    expect(plusRenewalNote('play'), 'plusRenewPlay');
    expect(plusRenewalNote('github'), isNull);
    expect(plusRenewalNote('rustore'), isNull);
    expect(tr('plusRenewApple'), isNot('plusRenewApple'));
    expect(tr('plusRenewPlay'), isNot('plusRenewPlay'));
  });

  for (final width in const [320.0, 360.0, 375.0, 393.0, 430.0]) {
    testWidgets('На экране шириной ${width.toInt()} ссылки стоят в одну строку',
        (tester) async {
      tester.view.physicalSize = Size(width, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: PlusScreen(plus: _Fake()),
      ));
      await tester.pumpAndSettle();

      final terms = tester.getRect(find.widgetWithText(TextButton, tr('plusTerms')));
      final privacy = tester.getRect(find.widgetWithText(TextButton, tr('plusPrivacy')));
      expect(terms.top, privacy.top, reason: 'вторая ссылка уехала на новую строку и раздула низ витрины');
    });
  }

  testWidgets('Под кнопкой оформления видны условия и политика', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MoneyTheme.light(),
      home: PlusScreen(plus: _Fake()),
    ));
    await tester.pumpAndSettle();

    final terms = find.widgetWithText(TextButton, tr('plusTerms'));
    final privacy = find.widgetWithText(TextButton, tr('plusPrivacy'));
    expect(terms, findsOneWidget);
    expect(privacy, findsOneWidget);

    // Ссылки стоят на экране сразу, а не за прокруткой списка
    final screen = tester.getRect(find.byType(Scaffold));
    expect(tester.getRect(terms).bottom, lessThanOrEqualTo(screen.bottom));
    expect(tester.getRect(privacy).bottom, lessThanOrEqualTo(screen.bottom));
    expect(tester.takeException(), isNull);
  });
}
