import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/widgets/undo_bar.dart';

import 'tm_fonts.dart';

/// Отмена последнего действия.
///
/// «При каждом входе приложения появляется этот баннер. Он меня бесит»
/// (17.09.2026). Причина была не в оформлении: состав пары и курсы валют
/// приезжают с сервера сами при каждом запуске, а хранилище заводило на них
/// шаг отмены — и человек видел широкую плашку «Пара обновлена · Отменить»
/// поверх своего сальдо. Отменять там было нечего: он ничего не делал.

Store storeOf() => Store()
  ..importBackupForTest(const Database(
    baseCurrency: 'MDL',
    accounts: [Account(name: 'Карта', currency: 'MDL')],
    categories: [Category(name: 'Еда')],
  ));

Transaction lunch() => const Transaction(
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
    );

void main() {
  setUpAll(loadTmFonts);

  group('что вообще предлагает отмену', () {
    test('приезд пары — не действие человека', () {
      final store = storeOf();
      store.setPair(const Pair(
        groupId: 'grp1',
        members: [Member(uid: 'u_me', name: 'Саша')],
      ));
      expect(store.undo, isNull, reason: 'отменять нечего: никто ничего не делал');
    });

    test('курсы приезжают сами', () {
      // Курсы обновляются на запуске и на возврате из фона, и «Отменить»
      // вернуло бы вчерашние цифры.
      final store = storeOf();
      store.setRates({'USD': 17.3}, source: 'open.er-api.com');
      expect(store.undo, isNull);
    });

    test('своя запись — действие, и её можно вернуть', () {
      final store = storeOf();
      store.saveOperation(lunch());
      expect(store.undo, isNotNull);

      store.undoLast();
      expect(store.db.transactions, isEmpty);
    });
  });

  group('капсула', () {
    Widget app(Store store) => MaterialApp(
          theme: MoneyTheme.light(),
          home: Scaffold(
            body: Stack(children: [
              const SizedBox.expand(),
              Positioned(left: 0, right: 0, bottom: 8, child: UndoBar(store: store)),
            ]),
          ),
        );

    testWidgets('пустая, пока человек ничего не сделал', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      expect(find.text(tr('undoCancel')), findsNothing);
    });

    testWidgets('занимает угол, а не всю ширину', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(app(store));
      store.saveOperation(lunch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text(tr('undoCancel')), findsOneWidget);
      final box = tester.getRect(find.byType(UndoBar));
      final pill = tester.getRect(find.text(tr('undoCancel')));
      // «Намного меньше в размерах»: капсула живёт в левой половине экрана и
      // не спорит с круглой кнопкой записи справа.
      expect(pill.left, lessThan(box.width / 2));
      expect(pill.right, lessThan(box.width / 2));
    });

    testWidgets('нажатие возвращает запись', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      store.saveOperation(lunch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(tr('undoCancel')));
      await tester.pump();
      expect(store.db.transactions, isEmpty);
    });

    testWidgets('через пять секунд уходит сама', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      store.saveOperation(lunch());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(tr('undoCancel')), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(tr('undoCancel')), findsNothing);
      expect(store.db.transactions, hasLength(1), reason: 'запись осталась');
    });
  });
}
