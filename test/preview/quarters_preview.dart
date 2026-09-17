import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/icons.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/widgets/quarters.dart';

import '../tm_fonts.dart';

/// Кварталы: расход и доход по отдельности.
/// `flutter test test/preview/quarters_preview.dart`
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  final db = Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Карта maib', currency: 'MDL')],
    categories: const [
      Category(name: 'Продукты'),
      // Подкатегории со своими значками — из них и собирается ассорти.
      Category(name: 'Кофе', parent: 'Продукты', icon: 'cafe'),
      Category(name: 'Рынок', parent: 'Продукты', icon: 'grocery'),
      Category(name: 'Аптека', parent: 'Продукты', icon: 'pill'),
      Category(name: 'Дом'),
      Category(name: 'Мебель', parent: 'Дом', icon: 'home'),
      Category(name: 'Интернет', parent: 'Дом', icon: 'wifi'),
      Category(name: 'Транспорт'),
      Category(name: 'Бензин', parent: 'Транспорт', icon: 'car'),
      Category(name: 'Автобус', parent: 'Транспорт', icon: 'bus'),
      Category(name: 'Развлечения'),
      Category(name: 'Кино', parent: 'Развлечения', icon: 'movie'),
      Category(name: 'Игры', parent: 'Развлечения', icon: 'game'),
      Category(name: 'Зарплата'),
      Category(name: 'Реклама'),
    ],
    transactions: const [
      Transaction(
        id: 'e1', date: '2026-09-04', kind: TxKind.expense, account: 'Карта maib',
        currency: 'MDL', amount: -2480, amountBase: -2480, category: 'Продукты',
      ),
      Transaction(
        id: 'e2', date: '2026-09-06', kind: TxKind.expense, account: 'Карта maib',
        currency: 'MDL', amount: -1200, amountBase: -1200, category: 'Дом',
      ),
      Transaction(
        id: 'e3', date: '2026-09-08', kind: TxKind.expense, account: 'Карта maib',
        currency: 'MDL', amount: -640, amountBase: -640, category: 'Транспорт',
      ),
      Transaction(
        id: 'e4', date: '2026-09-10', kind: TxKind.expense, account: 'Карта maib',
        currency: 'MDL', amount: -380, amountBase: -380, category: 'Развлечения',
      ),
      Transaction(
        id: 'i1', date: '2026-09-01', kind: TxKind.income, account: 'Карта maib',
        currency: 'MDL', amount: 15000, amountBase: 15000, category: 'Зарплата',
      ),
      Transaction(
        id: 'i2', date: '2026-09-09', kind: TxKind.income, account: 'Карта maib',
        currency: 'MDL', amount: 2600, amountBase: 2600, category: 'Реклама',
      ),
    ],
  );

  for (final income in [false, true]) {
    testWidgets(income ? 'доход' : 'расход', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final slices = byCategory(
        db,
        Period.month(DateTime(2026, 9, 12)),
        income: income,
      );
      final store = Store()..importBackupForTest(db);
      List<IconData> icons(String category) {
        final out = <IconData>[categoryIcon(category)];
        for (final sub in store.subcategoriesOf(category)) {
          final icon = categoryIcon(sub.name, stored: sub.icon);
          if (!out.contains(icon)) out.add(icon);
        }
        return out;
      }

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Quarters(
                slices: slices,
                currency: 'MDL',
                height: 230,
                iconsOf: (slice) => icons(slice.name),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/quarters-${income ? 'in' : 'out'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  testWidgets('карточка целиком', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 470 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()..importBackupForTest(db);
    final key = GlobalKey();

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: store,
            builder: (context, _) => HomeScreen(
              store: store,
              period: Period.month(DateTime(2026, 9, 12)),
              onPeriod: (_) {},
              onAccounts: () {},
              onBudgets: () {},
              onGoals: () {},
              onPlan: () {},
              onDebts: () {},
              onChat: () {},
              onSettings: () {},
              onDrill: (_, __, [period]) {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(Quarters), 200);
    // Прокрутка останавливается на кварталах, а показать надо и шапку с
    // пилюлей: отходим назад.
    await tester.drag(find.byType(Quarters), const Offset(0, 190));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/quarters-card.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
