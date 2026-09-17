import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/widgets/money_text.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/screens/operation_edit.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/screens/currency_screen.dart';

import 'tm_fonts.dart';

Database sample() => const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Карта maib', currency: 'MDL'),
        Account(name: 'Payoneer', currency: 'USD'),
        Account(name: 'Рубли', currency: 'RUB'),
      ],
      transactions: [
        Transaction(
          id: 't1',
          date: '2026-09-12',
          kind: TxKind.expense,
          account: 'Payoneer',
          currency: 'USD',
          amount: -10,
          amountBase: -179,
        ),
      ],
    );

Store storeOf() => Store()..importBackupForTest(sample());

void main() {
  setUpAll(loadTmFonts);

  group('валюта и курсы', () {
    test('валюты, которым нужен курс, берутся из счетов и операций', () {
      expect(storeOf().currenciesInUse, ['RUB', 'USD']);
    });

    test('смена базовой валюты меняет и валюту пары', () {
      final store = storeOf();
      store.setBaseCurrency('rub');

      expect(store.db.baseCurrency, 'RUB');
      expect(store.db.pair.baseCurrency, 'RUB');
      // Курс базовой к себе самой не хранится — он всегда единица.
      expect(store.db.rates.containsKey('RUB'), isFalse);
      expect(store.currenciesInUse, ['MDL', 'USD']);
    });

    test('курс задаётся и убирается', () {
      final store = storeOf();
      store.setRate('USD', 17.9);
      expect(store.db.rates['USD'], 17.9);
      expect(convert(store.db, 10, 'USD'), 179);

      store.setRate('USD', null);
      expect(store.db.rates.containsKey('USD'), isFalse);
      // Снятый курс не значит «один к одному»: считает встроенная таблица.
      // «КУРС ЕСТЬ И БУДЕТ ВСЕГДА» — требование заказчика от 13.09.2026.
      expect(convert(store.db, 10, 'USD'), greaterThan(100));
    });

    test('курсы с сервера не затирают чужие и не берут базовую', () {
      final store = storeOf();
      store.setRate('RUB', 0.2);
      store.setRates({'USD': 17.9, 'MDL': 5, 'EUR': 0}, source: 'НБМ, ЕЦБ');

      expect(store.db.rates['USD'], 17.9);
      expect(store.db.rates['RUB'], 0.2);
      expect(store.db.rates.containsKey('MDL'), isFalse);
      expect(store.db.rates.containsKey('EUR'), isFalse);
      // Источник запомнен: человек видит, что курс от Нацбанка, а не наш.
      expect(store.ratesSource, 'НБМ, ЕЦБ');
      expect(store.ratesAt, isNotNull);
    });

    test('смена валюты и курс уезжают на сервер', () {
      final store = storeOf();
      store.syncEnabled = true;
      store.setBaseCurrency('USD');
      store.setRate('MDL', 0.056);

      expect(store.outbox, contains('settings:base'));
    });
  });

  group('трата в чужой валюте', () {
    /// Счёт в леях, заплатили десять долларов: банк списал валюту, и запись
    /// в леях была бы потерей денег в учёте — 10 вместо 173.
    test('из уведомления сохраняется валюта банка, а не счёта', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          rates: {'USD': 17.3},
          accounts: [
            Account(name: 'Карта maib', currency: 'MDL', last4: '1234'),
          ],
        ));
      store.viewer = 'u_me';
      store.setSenderMode('md.maib.mobile', NoticeMode.auto);

      store.addNotice(parseNotice(
        package: 'md.maib.mobile',
        title: 'maib',
        body: 'Achitare 10,00 USD, card *1234, APPLE',
        at: DateTime.utc(2026, 9, 12, 12).millisecondsSinceEpoch,
      ));

      final tx = store.db.transactions.single;
      expect(tx.currency, 'USD');
      expect(tx.amount, -10);
      // В базовой валюте — пересчёт по курсу, и он же уходит в итоги.
      expect(tx.amountBase, -173);
      expect(tx.account, 'Карта maib');
    });

    test('счёт показывает обе валюты, а не складывает их', () {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          rates: {'USD': 17.3},
          accounts: [Account(name: 'Карта maib', currency: 'MDL')],
          transactions: [
            Transaction(
              id: 'a',
              date: '2026-09-01',
              kind: TxKind.income,
              account: 'Карта maib',
              currency: 'MDL',
              amount: 1000,
              amountBase: 1000,
            ),
            Transaction(
              id: 'b',
              date: '2026-09-12',
              kind: TxKind.expense,
              account: 'Карта maib',
              currency: 'USD',
              amount: -10,
              amountBase: -173,
            ),
          ],
        ));

      final acc = balances(store.db).single;
      expect(acc.multiCurrency, isTrue);
      final byCode = {for (final c in acc.byCurrency) c.currency: c.amount};
      expect(byCode['MDL'], 1000);
      expect(byCode['USD'], -10);
      // Пересчёт в базовую: тысяча леев минус десять долларов по 17,30.
      expect(acc.converted, 827);
    });
  });

  group('ручная запись в чужой валюте', () {
    testWidgets('валюту выбирают пилюлей, и она попадает в операцию',
        (tester) async {
      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          rates: {'USD': 17.3},
          accounts: [Account(name: 'Карта maib', currency: 'MDL')],
          categories: [Category(name: 'Подписки')],
        ));

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context)
                    .push(operationRoute(store)),
                child: const Text('Открыть'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      // Валюта стоит кнопкой рядом с суммой, а не рядом пилюль: ряд съедал
      // полсотни точек высоты, из-за которых категории уезжали за экран.
      // Справочником валют мира эта кнопка не становится — чужое за поиском.
      expect(find.text('MDL'), findsWidgets);
      expect(find.text('USD'), findsNothing);

      // Счёт в леях, платим в долларах: валюта берётся поиском.
      await tester.tap(find.byIcon(Myna.search).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'usd');
      await tester.pumpAndSettle();
      // Экран поиска тот же, что в настройках: флаг, код и название.
      await tester.tap(find.text('Доллар США'));
      await tester.pumpAndSettle();
      // Клавиатура набирает копейки: «10,00» это 1-0-0-0.
      await tester.tap(find.text('1'));
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('0').first);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Под суммой честно написано, во что это превратится в итогах, и по
      // какому курсу: перевёрнутый курс здесь самая дорогая ошибка.
      // Пробел между валютой и суммой неразрывный: иначе строка рвётся по
      // нему, и на экране от суммы остаётся одна валюта.
      expect(find.text(formatMoney(-10, 'USD')), findsOne);
      expect(find.textContaining('≈ ${formatMoney(173, 'MDL')}'), findsOne);
      expect(find.textContaining('17,3000'), findsOne);

      await tester.tap(find.text('Записать'));
      await tester.pumpAndSettle();

      final tx = store.db.transactions.single;
      expect(tx.currency, 'USD');
      expect(tx.amount, -10);
      expect(tx.amountBase, -173);
      expect(tx.account, 'Карта maib');
    });
  });

  group('лист валюты', () {
    Widget app(Store store) => MaterialApp(
          theme: MoneyTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showCurrencySheet(context, store: store),
                  child: const Text('Открыть'),
                ),
              ),
            ),
          ),
        );

    testWidgets('базовая валюта меняется через поиск', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      expect(find.text('Валюта и курсы'), findsOne);
      // Строка базовой валюты ведёт на экран поиска: девять пилюль в столбик
      // выбором валюты не были.
      await tester.tap(find.byKey(const ValueKey('base-row')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'рубл');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Российский рубль'));
      await tester.pumpAndSettle();

      expect(store.db.baseCurrency, 'RUB');
    });

    testWidgets('конвертер считает по курсу и меняет стороны', (tester) async {
      final store = storeOf();
      // Первая чужая валюта по алфавиту и есть вторая сторона конвертера.
      store.setRate('RUB', 0.19);
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      // 100 леев по 0,19 — это 526,32 рубля.
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pumpAndSettle();
      expect(find.text('526,32'), findsOne);

      await tester.tap(find.byIcon(Myna.arrowLeftRight));
      await tester.pumpAndSettle();
      // Наоборот: сто рублей это девятнадцать леев.
      expect(find.text('19,00'), findsOne);
    });

    testWidgets('курс вводится руками и сразу считается', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('rate-USD')), '17,90');
      await tester.pumpAndSettle();

      expect(store.db.rates['USD'], 17.9);
      // Обратный курс подписан под полем: так видно, не перевёрнут ли он.
      expect(find.textContaining('1 MDL = 0,0559 USD'), findsOne);
    });

    testWidgets('без входа курсы с сервера не тянутся молча', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Обновить курсы'));
      await tester.pumpAndSettle();

      final note = find.textContaining('доступны после входа в аккаунт');
      await tester.scrollUntilVisible(note, 200,
          scrollable: find.byType(Scrollable).first);
      expect(note, findsOne);
    });

    testWidgets('своя валюта добавляется поиском', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      final add = find.byKey(const ValueKey('add-currency'));
      await tester.scrollUntilVisible(add, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'gbp');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Фунт стерлингов'));
      await tester.pumpAndSettle();

      expect(store.db.rates.containsKey('GBP'), isTrue);
      expect(find.byKey(const ValueKey('rate-GBP')), findsOne);
    });

    testWidgets('собирается на 320dp при шрифте 1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      store.setRate('USD', 17.9);
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(store),
      ));
      await tester.tap(find.text('Открыть'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
