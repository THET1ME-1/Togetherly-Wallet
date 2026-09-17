import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:flutter/material.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

Store storeOf() => Store()
  ..importBackupForTest(const Database(
    baseCurrency: 'MDL',
    rates: {'USD': 17.3},
    accounts: [
      Account(name: 'Карта', currency: 'MDL'),
      Account(name: 'Наличные', currency: 'MDL'),
      Account(name: 'Долларовый', currency: 'USD'),
    ],
  ));

void main() {
  setUpAll(loadTmFonts);
  group('перевод между своими счетами', () {
    test('пишется ДВУМЯ записями: ушло и пришло', () {
      final store = storeOf();
      store.transfer(from: 'Карта', to: 'Наличные', amount: 500);

      expect(store.db.transactions, hasLength(2));
      final out = store.db.transactions.firstWhere((t) => t.amount < 0);
      final into = store.db.transactions.firstWhere((t) => t.amount > 0);

      expect(out.account, 'Карта');
      expect(out.amount, -500);
      expect(into.account, 'Наличные');
      expect(into.amount, 500);
      // Перевод — не трата и не доход: в отчётах его быть не должно.
      expect(out.kind, TxKind.transfer);
      expect(into.kind, TxKind.transfer);
    });

    test('деньги не исчезают и не появляются', () {
      final store = storeOf();
      final before = balances(store.db);
      store.transfer(from: 'Карта', to: 'Наличные', amount: 500);
      final after = balances(store.db);

      double total(List<AccountBalance> list) =>
          list.fold(0.0, (sum, a) => sum + a.converted);
      expect(total(after), closeTo(total(before), 0.001));
      expect(
        after.firstWhere((a) => a.name == 'Карта').mainAmount,
        before.firstWhere((a) => a.name == 'Карта').mainAmount - 500,
      );
      expect(
        after.firstWhere((a) => a.name == 'Наличные').mainAmount,
        before.firstWhere((a) => a.name == 'Наличные').mainAmount + 500,
      );
    });

    test('между валютами сумма пересчитывается по курсу', () {
      final store = storeOf();
      // Сто семьдесят три лея с карты — это десять долларов на долларовом.
      store.transfer(from: 'Карта', to: 'Долларовый', amount: 173);

      final into = store.db.transactions.firstWhere((t) => t.amount > 0);
      expect(into.currency, 'USD');
      expect(into.amount, closeTo(10, 0.001));
      final out = store.db.transactions.firstWhere((t) => t.amount < 0);
      expect(out.currency, 'MDL');
      expect(out.amount, -173);
      // В базовой валюте обе половины равны по модулю: иначе итог поедет.
      expect(into.amountBase, closeTo(-out.amountBase, 0.001));
    });

    test('сам в себя и пустая сумма не пишутся', () {
      final store = storeOf();
      store.transfer(from: 'Карта', to: 'Карта', amount: 500);
      store.transfer(from: 'Карта', to: 'Наличные', amount: 0);
      store.transfer(from: '', to: 'Наличные', amount: 500);
      expect(store.db.transactions, isEmpty);
    });

    test('обе половины уезжают на сервер', () {
      final store = storeOf()..syncEnabled = true;
      store.transfer(from: 'Карта', to: 'Наличные', amount: 500);
      final ids = store.db.transactions.map((t) => 'tx:${t.id}');
      for (final id in ids) {
        expect(store.outbox, contains(id));
      }
    });
  });

  group('экран перевода', () {
    testWidgets('без второго счёта записать нельзя', (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: OperationScreen(store: store),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('opTransfer')));
      await tester.pumpAndSettle();

      // У перевода два счёта: откуда и куда. Панель открывается сама и
      // подписана тем, что сейчас выбирают, — без второго счёта перевод
      // списывал деньги в никуда (13.09.2026).
      expect(find.text(tr('opMoveFrom')), findsOneWidget);
      // У перевода категории нет: деньги перекладываются, а не тратятся,
      // и вкладки «Категория» в панели тоже нет.
      expect(find.widgetWithText(ChoiceChip, tr('opTabCategory')), findsNothing);
      expect(find.text(tr('opSplitOwn')), findsNothing);

      // Клавиши — соседней вкладкой той же панели.
      await tester.tap(find.widgetWithText(ChoiceChip, tr('opTabKeys')));
      await tester.pumpAndSettle();

      // Набираем сумму — кнопка всё равно просит выбрать счёт.
      for (final d in ['5', '0', '0', '0']) {
        await tester.tap(find.widgetWithText(InkWell, d).first);
      }
      await tester.pumpAndSettle();
      expect(find.text(tr('opMovePick')), findsOneWidget);
      expect(store.db.transactions, isEmpty);
    });
  });
}
