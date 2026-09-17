import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/settings.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Карточка профиля глазами.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  testWidgets('профиль в паре', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 852 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта Salut', currency: 'MDL')],
        pair: Pair(
          groupId: 'g1',
          members: [
            Member(uid: 'u_me', name: 'THET1ME'),
            Member(uid: 'u_you', name: 'JB SHARAN'),
          ],
          baseCurrency: 'MDL',
        ),
      ));
    store.viewer = 'u_me';

    final session = Session()
      ..pretendSignedIn(
        uid: 'u_me',
        email: 'sasha@example.com',
        name: 'THET1ME',
      );

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.dark(),
        home: SettingsScreen(store: store, session: session),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final repaint =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await repaint.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/profile.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
