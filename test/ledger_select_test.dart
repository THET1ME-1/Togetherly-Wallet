import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/ledger.dart';

import 'tm_fonts.dart';

/// Выбор пачкой в ленте.
///
/// Просьба человека 17.09.2026: «нет множественного выбора при удержании
/// транзакции и действиях с ними». Здесь проверяется то, что легко сломать
/// молча: удержание включает режим, короткое касание в режиме берёт запись, а
/// не открывает форму, и выход из режима возвращает ленте обычное поведение.

/// Строка ленты подписана КАТЕГОРИЕЙ, поэтому в тесте они разные: искать
/// операции по заметке нельзя — её там может не быть вовсе.
Transaction tx(String id, String category) => Transaction(
      id: id,
      date: '2026-09-10',
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -100,
      amountBase: -100,
      category: category,
      author: 'u_me',
      payer: 'u_me',
    );

Store storeOf() => Store()
  ..importBackupForTest(Database(
    baseCurrency: 'MDL',
    accounts: const [Account(name: 'Карта', currency: 'MDL')],
    categories: const [
      Category(name: 'Продукты'),
      Category(name: 'Кафе'),
      Category(name: 'Транспорт'),
    ],
    transactions: [tx('a', 'Продукты'), tx('b', 'Кафе'), tx('c', 'Транспорт')],
  ));

Widget app(Store store, {ValueChanged<Transaction>? onEdit}) => MaterialApp(
      theme: MoneyTheme.light(),
      home: Scaffold(
        body: LedgerScreen(
          store: store,
          period: Period(PeriodKind.all, DateTime(2026, 9, 10)),
          onPeriod: (_) {},
          filter: const Filter(),
          onFilter: (_) {},
          onEdit: onEdit ?? (_) {},
        ),
      ),
    );

void main() {
  setUpAll(loadTmFonts);

  testWidgets('удержание включает выбор, касание открывает запись',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Transaction? opened;
    await tester.pumpWidget(app(storeOf(), onEdit: (t) => opened = t));
    await tester.pumpAndSettle();

    // Обычная лента: касание ведёт на правку.
    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();
    expect(opened?.id, 'a');

    opened = null;
    await tester.longPress(find.text('Продукты'));
    await tester.pumpAndSettle();

    expect(find.text(trf('bulkChosen', ['1'])), findsOneWidget);
    expect(opened, isNull, reason: 'удержание не открывает форму');

    // В режиме выбора касание БЕРЁТ запись, а не открывает её: иначе человек,
    // набирающий десяток, будет вылетать в форму.
    await tester.tap(find.text('Кафе'));
    await tester.pumpAndSettle();
    expect(find.text(trf('bulkChosen', ['2'])), findsOneWidget);
    expect(opened, isNull);
  });

  testWidgets('повторное касание снимает выбор, последнее — выходит из режима',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(storeOf()));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продукты'));
    await tester.pumpAndSettle();

    // Выбранных не осталось — значит и режима больше нет.
    expect(find.textContaining(tr('bulkActions')), findsNothing);
    expect(find.text(trf('bulkChosen', ['0'])), findsNothing);
  });

  testWidgets('удалить пачкой: записи уходят, отмена возвращает',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Кафе'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(tr('bulkActions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('bulkDelete')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('bulkDelete')).last);
    await tester.pumpAndSettle();

    expect([for (final t in store.db.transactions) t.id], ['c']);

    // Одна отмена возвращает обе записи разом.
    store.undoLast();
    expect(store.db.transactions, hasLength(3));
  });

  testWidgets('сменить категорию пачкой', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeOf();
    await tester.pumpWidget(app(store));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Продукты'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(tr('bulkActions')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('bulkCategory')));
    await tester.pumpAndSettle();

    // Открылся общий выбор категории — тот же, что на экране записи.
    expect(find.text(tr('opCategory')), findsWidgets);
  });
}
