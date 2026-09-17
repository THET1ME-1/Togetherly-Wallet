import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/screens/notices_review_screen.dart';
import 'package:togetherly_money/screens/notices_screen.dart';

import '../tm_fonts.dart';

/// Съёмка разбора уведомлений: `flutter test test/preview/notices_preview.dart`.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  Store storeOf() {
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        pair: Pair(
          groupId: 'g1',
          members: [
            Member(uid: 'u_me', name: 'Саша'),
            Member(uid: 'u_you', name: 'Линелла'),
          ],
          baseCurrency: 'MDL',
        ),
        accounts: [
          Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true, last4: '4568'),
          Account(
            name: 'Карта maib',
            currency: 'MDL',
            last4: '1234',
            bank: 'md.maib.mobile',
            owner: 'u_me',
          ),
          Account(
            name: 'Рубли',
            currency: 'RUB',
            last4: '8890',
            bank: 'ru.sberbankmobile',
            owner: 'u_me',
          ),
        ],
        categories: [Category(name: 'Продукты'), Category(name: 'Транспорт')],
      ));
    store.viewer = 'u_me';

    for (final row in const [
      (
        'md.maib.mobile',
        'maib',
        'Achitare 417,60 MDL, card *1234, LINELLA CENTRU. Disponibil: 4 512,30 MDL',
        14,
      ),
      (
        'ru.sberbankmobile',
        'СберБанк',
        'Покупка 1 289,00 ₽ Пятёрочка. Баланс: 12 400,55 ₽',
        12,
      ),
      (
        'com.payoneer.consumer',
        'Payoneer',
        'You received a payment of 250.00 USD from Upwork',
        9,
      ),
    ]) {
      store.addNotice(parseNotice(
        package: row.$1,
        title: row.$2,
        body: row.$3,
        at: DateTime(2026, 9, 12, row.$4, 30).millisecondsSinceEpoch,
      ));
    }
    // Приложение уже научилось: маршруты карт и категория магазина.
    store.acceptNotice(
      store.pendingNotices.last,
      account: 'Карта maib',
      category: 'Продукты',
    );
    store.setSenderMode('com.google.android.apps.walletnfcrel', NoticeMode.off);
    store.hideNoticeHint();
    return store;
  }

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('настройки ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
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
          home: NoticesScreen(store: storeOf()),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 32));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/notices-settings-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });

    testWidgets('разбор ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(393 * 2, 852 * 2);
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
          home: NoticesReviewScreen(store: storeOf()),
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 32));

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.6);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/notices-review-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
