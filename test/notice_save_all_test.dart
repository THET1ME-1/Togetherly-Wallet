import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/screens/notices_review_screen.dart';
import 'package:togetherly_money/ui/theme/tm_theme.dart';

const me = Member(uid: 'u_me', name: 'Федя');

/// Телефон тестировщика: один счёт и пачка списаний из банка.
Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Наличные', currency: 'MDL')],
    ));
  store.viewer = me.uid;
  return store;
}

ParsedNotice charge(String merchant, double sum, int minute) => parseNotice(
      package: 'md.maib.maibank',
      title: 'maibank',
      body: 'Achitare ${sum.toStringAsFixed(2)} MDL, card *9010, $merchant',
      at: DateTime.utc(2026, 9, 22, 12, minute).millisecondsSinceEpoch,
    );

Widget screen(Store store) => MaterialApp(
      theme: TmTheme.dark(),
      home: NoticesReviewScreen(store: store),
    );

void main() {
  testWidgets('одно касание записывает всё понятное', (tester) async {
    final store = storeOf();
    store.addNotice(charge('Linella', 20, 10));
    store.addNotice(charge('Kaufland', 140, 20));
    store.addNotice(charge('Andys', 85, 30));
    expect(store.pendingNotices, hasLength(3));

    await tester.pumpWidget(screen(store));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(trf('reviewSaveAll', [3])));
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.db.transactions, hasLength(3));
    expect(store.pendingNotices, isEmpty);
  });

  testWidgets('неуверенный разбор остаётся ждать человека', (tester) async {
    final store = storeOf();
    store.addNotice(charge('Linella', 20, 10));
    store.addNotice(charge('Kaufland', 140, 20));
    // Объявление с доски: ни карты, ни слова направления — такое пачкой не
    // записывают (22.09.2026, «Apartament cu camere» на 65 000 €).
    store.setSenderMode('md.simpals.md999', NoticeMode.ask);
    store.addNotice(parseNotice(
      package: 'md.simpals.md999',
      title: 'Simpals',
      body: 'Apartament cu camere, 65 000 €',
      at: DateTime.utc(2026, 9, 22, 9, 48).millisecondsSinceEpoch,
    ));
    expect(store.pendingNotices, hasLength(3));

    await tester.pumpWidget(screen(store));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(trf('reviewSaveAll', [2])));
    await tester.pump(const Duration(milliseconds: 600));

    expect(store.db.transactions, hasLength(2));
    expect(store.pendingNotices, hasLength(1));
    expect(store.pendingNotices.single.amount, 65000);
  });

  testWidgets('одному списанию общая кнопка не нужна', (tester) async {
    final store = storeOf();
    store.addNotice(charge('Linella', 20, 10));

    await tester.pumpWidget(screen(store));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(trf('reviewSaveAll', [1])), findsNothing);
  });
}
