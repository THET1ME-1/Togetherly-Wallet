import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/screens/ask_screen.dart';
import 'package:togetherly_money/services/session.dart';

import '../tm_fonts.dart';

/// Съёмка разговора о деньгах. Данные выдуманы.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/preview')..createSync(recursive: true);

  const me = Member(uid: 'u_me', name: 'Саша', color: 0xFFB8E0C8);
  const you = Member(uid: 'u_you', name: 'Линелла', color: 0xFFDCD2F0);

  Store storeOf() {
    final store = Store()
      ..importBackupForTest(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        categories: [Category(name: 'Продукты')],
        pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      ));
    store.viewer = me.uid;
    return store;
  }

  /// Сервер отвечает по очереди: сперва разбор, потом запись траты.
  Session sessionOf() {
    final replies = <Map<String, dynamic>>[
      {
        'answer': 'На еду у вас уходит 4 210 MDL в месяц — это треть всех '
            'трат. Половина суммы приходится на два похода в Linella.',
        'actions': const [],
        'left': 2,
      },
      {
        'answer': 'Записал 150 MDL на продукты с карты.',
        'actions': const [
          {
            'do': 'add_transaction',
            'args': {
              'kind': 'expense',
              'amount': 150,
              'account': 'Карта',
              'category': 'Продукты',
              'note': 'Чипсы',
            },
          },
        ],
        'left': 1,
      },
    ];
    var i = 0;
    final client = MockClient((req) async {
      final body = replies[i.clamp(0, replies.length - 1)];
      i++;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    return Session(client: client);
  }

  Future<void> shot(WidgetTester tester, GlobalKey key, String name) =>
      tester.runAsync(() async {
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
      });

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('чат ${mode.name}', (tester) async {
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
          home: AskScreen(store: storeOf(), session: sessionOf()),
        ),
      ));
      await tester.pumpAndSettle();
      await shot(tester, key, 'ask-empty-${mode.name}');

      await tester.tap(find.text('Сколько мы тратим на еду?'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await tester.enterText(find.byType(TextField), 'Я потратил 150 на чипсы');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
      await shot(tester, key, 'ask-chat-${mode.name}');
    });
  }
}
