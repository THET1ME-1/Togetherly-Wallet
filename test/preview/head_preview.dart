import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';

import '../tm_fonts.dart';

/// Съёмка ШАПКИ главной с парой: без пары чип не рисуется вовсе, и правки
/// шапки проверять не на чем.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша', color: 0xFFB8E0C8);
  const you = Member(uid: 'u_you', name: 'JB SHARAN', color: 0xFFDCD2F0);

  Store storeOf() {
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      ));
    store.viewer = me.uid;
    return store;
  }

  for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
    testWidgets('шапка с парой ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 300 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: Scaffold(
            body: HomeScreen(
              store: storeOf(),
              session: null,
              period: Period.month(DateTime.now()),
              onPeriod: (_) {},
              onAccounts: () {},
              onBudgets: () {},
              onGoals: () {},
              onPlan: () {},
              onDebts: () {},
              onChat: () {},
              onSettings: () {},
              onNotices: () {},
              onDrill: (_, __, [___]) {},
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
        File('${dir.path}/head-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
