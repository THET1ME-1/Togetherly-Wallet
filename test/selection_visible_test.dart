import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/account_edit_screen.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/screens/settings.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/ui/theme/tm_scheme.dart';

import 'tm_fonts.dart';

/// Выбранное обязано ВЫГЛЯДЕТЬ выбранным.
///
/// «ОН НЕ ВЫДЕЛЯЕТСЯ ВКЛЮЧЕНИЕМ, НЕ ВЫДЕЛЯЕТСЯ. Я НАЖИМАЮ И НИЧЕГО НЕ
/// ПРОИСХОДИТ» (14.09.2026, про банк карты). Корень системный: на печатной
/// палитре `tm.field` это ровно `surfaceContainerHighest`, а `tm.text` — ровно
/// `onSurface`, поэтому пара «выбрано `field` / не выбрано
/// `surfaceContainerHighest`» не меняла на экране ничего. Там, где к этому
/// добавлялся белый `onAccent`, выходило белым по светло-серому.

double _lum(Color c) {
  double lin(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Store storeOf() => Store()
  ..importBackupForTest(const Database(
    baseCurrency: 'MDL',
    accounts: [
      Account(
        name: 'Карта Salut',
        currency: 'MDL',
        last4: '1234',
        bank: 'com.google.android.apps.walletnfcrel',
      ),
    ],
  ));

Color chipColor(WidgetTester tester) {
  final chip = find
      .ancestor(of: find.text('Google Wallet'), matching: find.byType(Material))
      .first;
  return tester.widget<Material>(chip).color!;
}


/// Доля пикселей, изменившихся ВНУТРИ элемента после нажатия.
///
/// Единственная проверка, которой можно верить на слово «точно подсвечивается»:
/// она смотрит на нарисованный кадр, а не на имена цветов в коде.
Future<double> tapAndDiff(
  WidgetTester tester,
  GlobalKey key,
  Finder target,
) async {
  Rect rect = tester.getRect(target);
  Future<ui.Image> frame() => tester.runAsync(() async {
        final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        return b.toImage();
      }).then((v) => v!);

  Future<List<int>> pixels(ui.Image image) async {
    final data = await tester
        .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    return data!.buffer.asUint8List();
  }

  final before = await pixels(await frame());
  await tester.tap(target, warnIfMissed: false);
  await tester.pumpAndSettle();
  // Элемент мог сдвинуться (панель, список) — берём его новое место.
  if (target.evaluate().isNotEmpty) rect = tester.getRect(target);
  final after = await pixels(await frame());

  final width = tester.view.physicalSize.width.round();
  var changed = 0, total = 0;
  for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
    for (var x = rect.left.round(); x < rect.right.round(); x++) {
      final i = (y * width + x) * 4;
      if (i < 0 || i + 3 >= before.length || i + 3 >= after.length) continue;
      total++;
      if (before[i] != after[i] ||
          before[i + 1] != after[i + 1] ||
          before[i + 2] != after[i + 2]) {
        changed++;
      }
    }
  }
  return total == 0 ? 0 : changed / total;
}

Widget wrap(GlobalKey key, Widget home) => RepaintBoundary(
      key: key,
      child: MaterialApp(theme: MoneyTheme.dark(), home: home),
    );

Database opSample() => const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Карта Salut', currency: 'MDL'),
        Account(name: 'Наличные', currency: 'MDL'),
      ],
      categories: [
        Category(name: 'Продукты'),
        Category(name: 'Транспорт'),
      ],
    );

void main() {
  setUpAll(loadTmFonts);

  test('в печатной палитре field и surfaceContainerHighest — ОДИН цвет', () {
    for (final theme in [MoneyTheme.light(), MoneyTheme.dark()]) {
      final tm = theme.extension<TmPalette>()!;
      expect(tm.field, theme.colorScheme.surfaceContainerHighest,
          reason: 'значит выбором этот цвет служить не может');
      expect(tm.text, theme.colorScheme.onSurface);
    }
  });

  test('выбранным цветом служит инверсия, и она контрастна', () {
    for (final theme in [MoneyTheme.light(), MoneyTheme.dark()]) {
      final s = theme.colorScheme;
      expect(contrast(s.secondaryContainer, s.surfaceContainerHighest),
          greaterThan(3.0),
          reason: 'выбранная пилюля обязана отличаться от соседней');
      expect(contrast(s.onSecondaryContainer, s.secondaryContainer),
          greaterThan(4.5),
          reason: 'подпись на выбранном обязана читаться');
    }
  });

  testWidgets('банк карты выделяется нажатием', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theme = MoneyTheme.dark();
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: AccountEditScreen(store: storeOf(), name: 'Карта Salut'),
    ));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Google Wallet'), 200,
        scrollable: find.byType(Scrollable).first);

    final chosen = chipColor(tester);
    await tester.tap(find.text('Google Wallet'));
    await tester.pumpAndSettle();
    final plain = chipColor(tester);

    expect(chosen, isNot(plain), reason: 'нажатие обязано менять вид');
    expect(contrast(chosen, plain), greaterThan(3.0),
        reason: 'разница обязана быть видимой, а не на один тон');
  });

  test('выбор не красится цветом невыбранного', () {
    // Грубо, зато ловит возврат ошибки в любом новом экране: `tm.field`
    // против `surfaceContainerHighest` в одном тернарнике — это выбор,
    // которого не видно, а `X ? tm.field : tm.field` — мёртвый тернарник.
    final bad = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.contains('tm_scheme') || file.path.contains('tm_colors')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.contains('?')) continue;
        final field = RegExp(r'\btm\.field\b').allMatches(line).length;
        if (field == 0) continue;
        final other = line.contains('surfaceContainerHighest');
        if (other || field > 1) bad.add('${file.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  /// Каждый выбор проверяется НАЖАТИЕМ: кадр до, кадр после, доля
  /// изменившихся пикселей внутри самого элемента. Меньше 8% — человек
  /// нажал и не увидел ничего.
  group('нажатие меняет вид', () {
    Future<void> check(
      WidgetTester tester,
      Widget home,
      String label, {
      Finder? target,
      Future<void> Function(WidgetTester)? before,
    }) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(wrap(key, home));
      await tester.pumpAndSettle();
      if (before != null) await before(tester);

      // Ищем БЕЗ `.first`: `dragUntilVisible` спрашивает финдер на каждом
      // шаге, и `.first` по пустому набору бросает «Bad state» ещё до того,
      // как список долистает до нужной строки.
      final search = target ?? find.text(label);
      if (find.byType(Scrollable).evaluate().isNotEmpty &&
          search.evaluate().isEmpty) {
        await tester.scrollUntilVisible(search, 150,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
      }
      final finder = search.first;

      final diff = await tapAndDiff(tester, key, finder);
      expect(diff, greaterThan(0.08),
          reason: '«$label»: нажал и ничего не изменилось '
              '(${(diff * 100).toStringAsFixed(1)}% пикселей)');
    }

    Store accountStore() => Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [
          Account(
            name: 'Карта Salut',
            currency: 'MDL',
            last4: '1234',
            bank: 'com.google.android.apps.walletnfcrel',
          ),
        ],
      ));

    testWidgets('банк карты', (t) async => check(
        t, AccountEditScreen(store: accountStore(), name: 'Карта Salut'),
        'Google Wallet'));

    testWidgets('вид счёта', (t) async => check(
        t, AccountEditScreen(store: accountStore(), name: 'Карта Salut'),
        'Кредитная карта'));

    testWidgets('платёжная система', (t) async => check(
        t, AccountEditScreen(store: accountStore(), name: 'Карта Salut'),
        'Visa'));

    testWidgets('сторона записи', (t) async => check(
          t,
          OperationScreen(store: Store()..importBackupForTest(opSample())),
          tr('opIncome'),
        ));

    testWidgets('категория в панели', (t) async => check(
          t,
          OperationScreen(store: Store()..importBackupForTest(opSample())),
          'Продукты',
          before: (tester) async {
            await tester.tap(find.text(tr('opPickCategory')));
            await tester.pumpAndSettle();
          },
        ));

    testWidgets('тема в настройках', (t) async => check(
          t,
          SettingsScreen(store: Store()..importBackupForTest(opSample())),
          tr('themeLight'),
        ));

    testWidgets('счёт в панели', (t) async => check(
          t,
          OperationScreen(store: Store()..importBackupForTest(opSample())),
          'Наличные',
          before: (tester) async {
            await tester
                .tap(find.widgetWithText(ChoiceChip, tr('opTabWallet')));
            await tester.pumpAndSettle();
          },
        ));

  });
}
