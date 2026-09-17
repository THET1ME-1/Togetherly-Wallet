import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/categories.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/screens/settings.dart';
import 'package:togetherly_money/screens/stats_screen.dart';

/// Снимки экранов настоящими данными. Заменяют визуальный тест веб-версии:
/// кадр рисуется движком Flutter, устройство для этого не нужно.
///
/// Отрезок в снимках прибит к августу 2026 года — тому месяцу, за который
/// собран `orbita-backup.json`. Иначе снимки пустеют при смене месяца и тест
/// начинает падать сам по себе.
/// Снимки рисуются НАСТОЯЩИМИ данными из `sample-data.json`, а он лежит вне
/// репозитория: там личные финансы. Без файла эти проверки пропускаются —
/// иначе форк и CI падали бы на первом же прогоне тем, чего у них быть не
/// может.
final bool hasSample = File('sample-data.json').existsSync();

void main() {
  late Database db;
  final period = Period.month(DateTime(2026, 8, 15));

  setUpAll(() async {
    // Без явной загрузки тест рисует прямоугольники вместо букв: движок в
    // тестовом окружении знает только служебный шрифт.
    const fonts = {
      'Unbounded': 'assets/fonts/Unbounded.ttf',
      'Onest': 'assets/fonts/Onest.ttf',
      'Myna': 'assets/fonts/Myna.ttf',
      'MynaSolid': 'assets/fonts/MynaSolid.ttf',
    };
    for (final entry in fonts.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)));
      await loader.load();
    }

    // Шрифт значков лежит в кэше самого Flutter, а не в приложении: без него
    // тест рисует на месте каждой иконки пустой квадрат, и снимок врёт.
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (icons.existsSync()) {
        final loader = FontLoader('MaterialIcons')
          ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await loader.load();
      }
    }

    if (!hasSample) return;
    final file = File('sample-data.json');
    final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    db = Database.fromJson((raw['data'] as Map).cast<String, dynamic>());
  });

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget Function(Store) make, {
    bool dark = false,
    bool scaffold = true,
  }) async {
    final store = Store()..importBackupForTest(db);
    // Размер задаётся окну теста, а не через MediaQuery внутри приложения:
    // вложенный MediaQuery не меняет поверхность отрисовки, и снимок выходил
    // альбомным листом 800×600 вместо телефона.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark
            ? MoneyTheme.dark()
            : MoneyTheme.light(),
        home: scaffold ? Scaffold(body: make(store)) : make(store),
      ),
    );
    // Один pump на всю длительность прокручивает часы, но контроллерам
    // анимации нужен кадр на каждый шаг: снимок ловил их в самом начале —
    // график выходил пустым, а строки ленты занимали место прозрачными.
    // pumpAndSettle крутит кадры, пока анимации не кончатся.
    await tester.pumpAndSettle(const Duration(milliseconds: 32));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name.png'));
  }

  Widget home(Store store) => HomeScreen(
        store: store,
        period: period,
        onPeriod: (_) {},
        onAccounts: () {},
        onBudgets: () {},
        onGoals: () {},
        onPlan: () {},
        onDebts: () {},
        onChat: () {},
        onSettings: () {},
        onDrill: (_, __, [period]) {},
      );

  testWidgets('главная, светлая', (t) async => shoot(t, 'home-light', home), skip: !hasSample);
  testWidgets('главная, тёмная', (t) async => shoot(t, 'home-dark', home, dark: true), skip: !hasSample);

  testWidgets('категории', (t) async => shoot(
        t,
        'categories',
        (store) => CategoriesScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onDrill: (_, __, [period]) {},
          onEditCategories: () {},
        ),
      ), skip: !hasSample);

  testWidgets('категории, тёмная', (t) async => shoot(
        t,
        'categories-dark',
        (store) => CategoriesScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          onDrill: (_, __, [period]) {},
          onEditCategories: () {},
        ),
        dark: true,
      ), skip: !hasSample);

  testWidgets('статистика', (t) async => shoot(
        t,
        'stats',
        (store) => StatsScreen(store: store, period: period, onPeriod: (_) {}),
      ), skip: !hasSample);

  testWidgets('лента операций', (t) async => shoot(
        t,
        'ledger',
        (store) => LedgerScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: (_) {},
        ),
      ), skip: !hasSample);

  testWidgets('лента, тёмная', (t) async => shoot(
        t,
        'ledger-dark',
        (store) => LedgerScreen(
          store: store,
          period: period,
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: (_) {},
        ),
        dark: true,
      ), skip: !hasSample);

  testWidgets('запись операции', (t) async => shoot(
        t,
        'new-op',
        (store) => OperationScreen(store: store),
        scaffold: false,
      ), skip: !hasSample);

  testWidgets('бюджеты', (t) async => shoot(
        t,
        'budgets',
        (store) => BudgetsScreen(store: store),
        scaffold: false,
      ), skip: !hasSample);

  // Цели наливаются: снимок ловит и воду, и ассорти знаков по ней.
  testWidgets('цели', (t) async => shoot(
        t,
        'goals',
        (store) => GoalsScreen(store: store),
        scaffold: false,
      ), skip: !hasSample);

  testWidgets('настройки', (t) async => shoot(
        t,
        'settings',
        (store) => SettingsScreen(store: store),
        scaffold: false,
      ), skip: !hasSample);
}
