import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/screens/home.dart';

import '../tm_fonts.dart';

/// Съёмка экрана целей: полоса накопленного, срок и вклады каждого.
/// Данные выдуманы — снимок можно показывать.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша', color: 0xFFB8E0C8);
  const you = Member(uid: 'u_you', name: 'Линелла', color: 0xFFDCD2F0);

  Transaction into(String id, String goal, double amount, String payer) => Transaction(
        id: id,
        date: '2026-09-10',
        kind: TxKind.transfer,
        account: goalAccountOf(goal),
        currency: 'MDL',
        amount: amount,
        amountBase: amount,
        author: payer,
        payer: payer,
      );

  final db = Database(
    baseCurrency: 'MDL',
    pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
    accounts: const [
      Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      Account(name: 'Моя карта', currency: 'MDL', owner: 'u_me'),
    ],
    goals: const [
      Goal(name: 'Отпуск в Греции', target: 45000, currency: 'MDL', deadline: '2026-12-20'),
      Goal(name: 'Диван', target: 12000, currency: 'MDL'),
      Goal(name: 'Подушка на три месяца', target: 0, currency: 'MDL'),
    ],
    transactions: [
      into('c1', 'Отпуск в Греции', 12500, 'u_me'),
      into('c2', 'Отпуск в Греции', 9800, 'u_you'),
      into('c3', 'Диван', 12000, 'u_me'),
      into('c4', 'Подушка на три месяца', 7300, 'u_you'),
    ],
  );

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('цели ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final store = Store()..importBackupForTest(db);
      store.viewer = me.uid;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: GoalsScreen(store: store),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 32));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/goals-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  // Карточка целей на главной: видно ли её и что на ней стоит.
  testWidgets('главная с целями', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 1500 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()..importBackupForTest(db);
    store.viewer = me.uid;

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: Scaffold(
          body: HomeScreen(
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
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 32));

    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/home-goals.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
