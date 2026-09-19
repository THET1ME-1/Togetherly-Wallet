import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/account_edit_screen.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

/// «Наличные» по умолчанию и удаление счёта (19.09.2026).
///
/// Человек: «Пусть по умолчанию будет создан у всех счёт Наличные, это
/// стандарт, но который можно удалить». Без счёта экран записи был урезан, а
/// удалить счёт было нечем вовсе.
const me = Member(uid: 'u_me', name: 'Саша');
const anya = Member(uid: 'u_anya', name: 'Аня');

String get cash => tr('accountDefaultName');

Transaction op(String id, String account, {String author = 'u_me'}) =>
    Transaction(
      id: id,
      date: '2026-09-19',
      kind: TxKind.expense,
      account: account,
      currency: 'MDL',
      amount: -40,
      amountBase: -40,
      author: author,
      payer: author,
    );

Store guest([Database db = const Database(baseCurrency: 'MDL')]) =>
    Store()..importBackupForTest(db);

Store paired([List<Account> accounts = const []]) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: accounts,
      pair: const Pair(groupId: 'g_anya', members: [me, anya]),
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  return store;
}

Widget app(Widget home) => MaterialApp(theme: MoneyTheme.light(), home: home);

void main() {
  setUpAll(loadTmFonts);

  group('«Наличные» по умолчанию', () {
    test('пустое устройство получает «Наличные»', () {
      final store = guest()..seedCash();
      final acc = store.db.accounts.single;
      expect(acc.name, cash);
      expect(acc.kind, AccountKind.cash);
      expect(acc.isShared, isTrue,
          reason: 'в паре их заводят оба телефона, личный счёт сервер отбил бы');
    });

    test('удалённые «Наличные» не возвращаются', () {
      final store = guest()..seedCash();
      store.deleteAccount(cash);
      expect(store.db.accounts, isEmpty);
      store.seedCash();
      expect(store.db.accounts, isEmpty);
    });

    test('где счёт уже есть, «Наличные» не добавляются и потом', () {
      final store = guest(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
      ))
        ..seedCash();
      expect(store.db.accounts.map((a) => a.name), ['Карта']);
      store.deleteAccount('Карта');
      store.seedCash();
      expect(store.db.accounts, isEmpty,
          reason: 'человек убрал все счета сам, приложение не спорит');
    });

    test('пара ждёт первого круга синхронизации', () {
      final store = paired()..seedCash();
      expect(store.db.accounts, isEmpty,
          reason: 'с сервера ещё ничего не приезжало, пустота мнимая');

      store.applyRemote({'now': 5});
      store.seedCash();
      expect(store.db.accounts.single.name, cash);
      expect(store.outbox, contains('acc:$cash'));
    });

    test('пара со счетами с сервера «Наличных» не получает', () {
      final store = paired();
      store.applyRemote({
        'now': 5,
        'accounts': [
          {'name': 'Общая карта', 'currency': 'MDL'},
        ],
      });
      store.seedCash();
      expect(store.db.accounts.map((a) => a.name), ['Общая карта']);
    });

    test('у новой пары своя проверка', () {
      final store = paired([const Account(name: 'Карта', currency: 'MDL')]);
      store.applyRemote({'now': 5});
      store.seedCash();
      expect(store.db.accounts.map((a) => a.name), ['Карта']);

      store.openSpace(const Pair(groupId: 'g_new', members: [me, anya]));
      store.applyRemote({'now': 6});
      store.seedCash();
      expect(store.db.accounts.single.name, cash);
    });

    test('нетронутые гостевые «Наличные» не едут в аккаунт', () {
      final store = guest()..seedCash();
      store.forgetSpareCash();
      expect(store.db.accounts, isEmpty,
          reason: 'иначе они легли бы поверх настоящих по имени');
    });

    test('«Наличные» с операциями или своим видом остаются', () {
      final used = guest()..seedCash();
      used.saveOperation(op('a', cash, author: ''));
      used.forgetSpareCash();
      expect(used.db.accounts.single.name, cash);

      final dressed = guest()..seedCash();
      dressed.editAccount(cash, color: 0xFF00AA00);
      dressed.forgetSpareCash();
      expect(dressed.db.accounts.single.name, cash);
    });
  });

  group('удаление счёта', () {
    test('операции и регулярные переезжают на другой счёт', () {
      final store = paired([
        Account(name: cash, currency: 'MDL'),
        const Account(name: 'Карта', currency: 'MDL'),
      ]);
      store.saveOperation(op('a', cash));
      store.saveRecurring(Recurring(
        id: 'r1',
        name: 'Кофе',
        amount: 40,
        currency: 'MDL',
        account: cash,
        interval: 'monthly',
        nextDate: '2026-10-01',
        kind: 'expense',
        active: true,
      ));

      store.deleteAccount(cash, moveTo: 'Карта');

      expect(store.db.accounts.map((a) => a.name), ['Карта']);
      expect(store.db.transactions.single.account, 'Карта');
      expect(store.db.recurring.single.account, 'Карта');
      expect(store.outbox, containsAll(['acc:$cash', 'tx:a', 'rec:r1']));
    });

    test('без другого счёта операции удаляются вместе с ним', () {
      final store = paired([Account(name: cash, currency: 'MDL')]);
      store.saveOperation(op('a', cash));
      store.deleteAccount(cash);
      expect(store.db.accounts, isEmpty);
      expect(store.db.transactions, isEmpty);
      expect(store.outbox, contains('tx:a'),
          reason: 'сервер узнаёт об удалении флагом, иначе запись вернётся');
    });

    testWidgets('экран счёта удаляет счёт после подтверждения', (tester) async {
      final store = guest(Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: cash, currency: 'MDL')],
      ));
      await tester.pumpWidget(app(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showAccountSheet(context, store: store, name: cash),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('accountRemove')));
      await tester.pumpAndSettle();
      expect(find.text(tr('accountRemoveEmpty')), findsOneWidget);
      await tester.tap(find.text(tr('accountRemoveAction')));
      await tester.pumpAndSettle();

      expect(store.db.accounts, isEmpty);
      expect(find.text('open'), findsOneWidget, reason: 'экран закрылся');
    });

    testWidgets('у нового счёта удалять нечего', (tester) async {
      final store = guest();
      await tester.pumpWidget(
          app(AccountEditScreen(store: store, name: 'Новая карта')));
      await tester.pumpAndSettle();
      expect(find.text(tr('accountRemove')), findsNothing);
    });
  });

  testWidgets('без счёта экран записи выглядит так же, как со счётом',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = guest();
    store.viewer = me.uid;
    await tester.pumpWidget(app(OperationScreen(store: store)));
    await tester.pumpAndSettle();

    // Строка счёта обещает «Наличные», дата на своём месте. Раньше здесь
    // стояла подсказка с кнопкой, а дата и ряд пары пропадали.
    expect(find.text(cash), findsOneWidget);
    expect(find.text(tr('opAccountNew')), findsOneWidget);
    expect(find.text(tr('opToday')), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, tr('opAccountMake')),
        findsNothing);
  });
}
