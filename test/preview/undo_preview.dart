import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/widgets/undo_bar.dart';

import '../tm_fonts.dart';

/// Как выглядит отмена последнего действия — прежняя плашка во всю ширину и
/// капсула, которая пришла ей на смену.
///
/// Снимок: `flutter test test/preview/undo_preview.dart`, кадры в
/// `build/preview`.
void main() {
  setUpAll(loadTmFonts);

  Store storeOf() => Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      categories: [Category(name: 'Еда')],
    ));

  Widget frame(Store store, {required bool dark}) => MaterialApp(
        theme: dark ? MoneyTheme.dark() : MoneyTheme.light(),
        home: Scaffold(
          body: Stack(children: [
            const SizedBox.expand(),
            Positioned(left: 0, right: 0, bottom: 8, child: UndoBar(store: store)),
          ]),
          floatingActionButton: FloatingActionButton(
            onPressed: () {},
            child: const Icon(Myna.plus),
          ),
        ),
      );

  testWidgets('капсула отмены', (tester) async {
    tester.view.physicalSize = const Size(393 * 2, 190 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    for (final dark in [false, true]) {
      final store = storeOf();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: frame(store, dark: dark)),
      );
      store.saveOperation(const Transaction(
        id: 't1',
        date: '2026-09-17',
        kind: TxKind.expense,
        account: 'Карта',
        currency: 'MDL',
        amount: -137,
        amountBase: -137,
        category: 'Еда',
        author: 'u_me',
        payer: 'u_me',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        final dir = Directory('build/preview')..createSync(recursive: true);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/undo-${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    }
  });
}
