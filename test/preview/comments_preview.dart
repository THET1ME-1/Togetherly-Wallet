import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/widgets/comments_sheet.dart';

import '../tm_fonts.dart';

/// Съёмка разговора под операцией. Данные выдуманы.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша', color: 0xFFB8E0C8);
  const you = Member(uid: 'u_you', name: 'Линелла', color: 0xFFDCD2F0);

  const op = Transaction(
    id: 'tx1',
    date: '2026-09-12',
    kind: TxKind.expense,
    account: 'Общий кошелёк',
    currency: 'MDL',
    amount: -1480.60,
    amountBase: -1480.60,
    category: 'Продукты',
    author: 'u_you',
    payer: 'u_you',
    split: SplitMode.equal,
  );

  final db = Database(
    baseCurrency: 'MDL',
    pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
    accounts: const [Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true)],
    transactions: const [op],
    comments: const [
      Comment(id: 'c1', txId: 'tx1', uid: 'u_me', text: 'Это что за сумма?', created: 100),
      Comment(
          id: 'c2',
          txId: 'tx1',
          uid: 'u_you',
          text: 'Закупка на неделю: мясо, сыр, овощи и кофе',
          created: 200),
      Comment(id: 'c3', txId: 'tx1', uid: 'u_me', emoji: '👍', created: 300),
    ],
  );

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('разговор ${mode.name}', (tester) async {
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
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showComments(context, store, op),
                  child: const Text('открыть'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/comments-${mode.name}.png')
            .writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
