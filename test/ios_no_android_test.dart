import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/screens/settings.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// На iPhone приложение не говорит про Android и не обещает разбор
/// уведомлений банка.
///
/// Читать чужие уведомления на iPhone не может ни одно приложение. Правило
/// App Store 2.3.10 не пускает в приложение имена других платформ, а 2.3.1 —
/// обещания того, чего в сборке нет. До 20.10.2026 витрина Wallet+ на iPhone
/// продавала «Записывать траты молча», а настройки писали «Читать уведомления
/// умеет только Android».

class _Fake extends PlusService {
  @override
  Future<List<PlusSeat>> seats() async => const [];
}

Future<void> openPlus(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: PlusScreen(plus: _Fake()),
  ));
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 9000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: SettingsScreen(store: Store()..importBackupForTest(const Database())),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Витрина на iPhone не продаёт разбор уведомлений', (tester) async {
    await openPlus(tester);
    expect(find.text(tr('plusFeatureAuto')), findsNothing);
    expect(find.text(tr('plusFeatureRules')), findsNothing);
    expect(find.textContaining(tr('plusFreeNotices')), findsNothing);
    expect(find.textContaining('Android'), findsNothing);
    // Остальное на месте: чат, файлы, отчёт
    expect(find.text(tr('plusFeatureChat')), findsOneWidget);
    expect(find.text(tr('plusFeatureReport')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Витрина на Android по-прежнему показывает разбор уведомлений',
      (tester) async {
    await openPlus(tester);
    expect(find.text(tr('plusFeatureAuto')), findsOneWidget);
    expect(find.text(tr('plusFeatureRules')), findsOneWidget);
    expect(find.textContaining(tr('plusFreeNotices')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Настройки на iPhone без строки уведомлений банка и без Android',
      (tester) async {
    await openSettings(tester);
    expect(find.text(tr('noticesRow')), findsNothing);
    expect(find.textContaining('Android'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Настройки на Android строку уведомлений держат', (tester) async {
    await openSettings(tester);
    expect(find.text(tr('noticesRow')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Замок на iPhone говорит Face ID и Touch ID, а не «отпечаток»',
      (tester) async {
    for (final key in ['plusFeatureLockNote', 'lockRowBoth', 'lockBiometrics', 'lockBiometricsNote']) {
      expect(trOs(key), contains('Face ID'), reason: key);
      expect(trOs(key), isNot(contains('отпечат')), reason: key);
    }
    await openPlus(tester);
    expect(find.text(trOs('plusFeatureLockNote')), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Замок на Android по-прежнему про отпечаток', (tester) async {
    expect(trOs('lockBiometrics'), tr('lockBiometrics'));
    expect(trOs('plusFeatureLockNote'), tr('plusFeatureLockNote'));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('Платная запись из уведомлений остаётся калиткой Wallet+', () {
    // Прятать строку витрины — не то же, что убрать калитку: на Android
    // молчаливая запись по-прежнему платная.
    expect(PlusGate.values, contains(PlusGate.autoNotices));
  });
}
