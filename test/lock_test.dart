import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/lock_screen.dart';
import 'package:togetherly_money/services/lock.dart';

import 'tm_fonts.dart';

/// Замок на вход.
///
/// Обещан витриной Wallet+ строкой «PIN и отпечаток», а в приложении его не
/// было вовсе (17.09.2026). Здесь проверяется то, что легко сделать неверно:
/// код не хранится числом, замок не запирается на каждое переключение
/// приложений и снимается даже без подписки.

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: home,
    );

void main() {
  setUpAll(loadTmFonts);

  group('служба замка', () {
    test('код проверяется, а не хранится числом', () {
      final lock = LockService()..setForTest(pin: '1234');
      expect(lock.enabled, isTrue);
      expect(lock.unlock('4321'), isFalse);
      expect(lock.unlock('1234'), isTrue);
      expect(lock.locked, isFalse);
    });

    test('без кода замка нет и вход свободен', () {
      final lock = LockService();
      expect(lock.enabled, isFalse);
      expect(lock.unlock(''), isTrue);
    });

    test('короткая отлучка замок не запирает', () {
      // Человек вышел в сообщения посмотреть сумму перевода и вернулся.
      // Замок, который спрашивает код на каждое переключение, выключают в
      // тот же день.
      final lock = LockService()..setForTest(pin: '1234');
      final at = DateTime(2026, 9, 17, 12);
      lock.leave(at: at);
      lock.comeBack(at: at.add(const Duration(seconds: 20)));
      expect(lock.locked, isFalse);
    });

    test('долгая отлучка запирает', () {
      final lock = LockService()..setForTest(pin: '1234');
      final at = DateTime(2026, 9, 17, 12);
      lock.leave(at: at);
      lock.comeBack(at: at.add(const Duration(minutes: 5)));
      expect(lock.locked, isTrue);
    });


    test('вторая отметка ухода не затирает первую', () {
      // Android шлёт `inactive` и перед сворачиванием, и перед возвратом.
      // Если вторая отметка перепишет первую, away выйдет нулевым, и замок
      // не запрётся никогда — ровно это и случилось на живом эмуляторе.
      final lock = LockService()..setForTest(pin: '1234');
      final at = DateTime(2026, 9, 17, 12);
      lock.leave(at: at);
      lock.leave(at: at.add(const Duration(minutes: 5)));
      lock.comeBack(at: at.add(const Duration(minutes: 5, seconds: 1)));
      expect(lock.locked, isTrue);
    });

    test('после возврата отсчёт начинается заново', () {
      final lock = LockService()..setForTest(pin: '1234');
      final at = DateTime(2026, 9, 17, 12);
      lock.leave(at: at);
      lock.comeBack(at: at.add(const Duration(seconds: 10)));
      expect(lock.locked, isFalse);
      // Второй заход короткий — и он тоже не запирает.
      lock.leave(at: at.add(const Duration(minutes: 10)));
      lock.comeBack(at: at.add(const Duration(minutes: 10, seconds: 5)));
      expect(lock.locked, isFalse);
    });

    test('замка нет — отлучка ничего не меняет', () {
      final lock = LockService();
      final at = DateTime(2026, 9, 17, 12);
      lock.leave(at: at);
      lock.comeBack(at: at.add(const Duration(hours: 5)));
      expect(lock.locked, isFalse);
    });
  });

  group('экран замка', () {
    testWidgets('верный код открывает', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lock = LockService()..setForTest(pin: '2468', locked: true);
      var opened = false;
      await tester.pumpWidget(app(LockScreen(
        lock: lock,
        onDone: () => opened = true,
      )));
      await tester.pumpAndSettle();

      for (final d in ['2', '4', '6', '8']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();

      expect(opened, isTrue);
      expect(lock.locked, isFalse);
    });

    testWidgets('неверный код говорит об этом и не пускает', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lock = LockService()..setForTest(pin: '2468', locked: true);
      var opened = false;
      await tester.pumpWidget(app(LockScreen(
        lock: lock,
        onDone: () => opened = true,
      )));
      await tester.pumpAndSettle();

      for (final d in ['1', '1', '1', '1']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(lock.locked, isTrue);
      expect(find.text(tr('lockWrong')), findsOneWidget);
    });

    testWidgets('заведение спрашивает код дважды', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lock = LockService();
      await tester.pumpWidget(app(LockScreen(lock: lock, setup: true)));
      await tester.pumpAndSettle();

      expect(find.text(tr('lockNewTitle')), findsOneWidget);
      for (final d in ['1', '2', '3', '4']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      // Первый ввод принят — теперь просит повторить.
      expect(find.text(tr('lockRepeatTitle')), findsOneWidget);
    });

    testWidgets('несовпавшие коды начинают сначала', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final lock = LockService();
      await tester.pumpWidget(app(LockScreen(lock: lock, setup: true)));
      await tester.pumpAndSettle();

      for (final d in ['1', '2', '3', '4', '1', '2', '3', '5']) {
        await tester.tap(find.text(d));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();

      expect(find.text(tr('lockMismatch')), findsOneWidget);
      expect(lock.enabled, isFalse);
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('замок собирается на 320 dp при шрифте 1.3, ${mode.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final lock = LockService()..setForTest(pin: '1111', locked: true);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(LockScreen(lock: lock), mode: mode),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
