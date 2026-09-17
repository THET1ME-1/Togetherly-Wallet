import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';

import 'tm_fonts.dart';

/// Главная отвечает на вопросы, которые человек задал вслух 16.09.2026, глядя
/// на свой экран: сколько это в леях, кто кому должен, входят ли цели в баланс
/// и почему рядом стоят два разных месяца.

const me = 'uid-me';
const you = 'uid-you';
final period = Period.month(DateTime(2026, 9, 16));

Database sample() => const Database(
      baseCurrency: 'MDL',
      pair: Pair(
        groupId: 'grp1',
        members: [
          Member(uid: me, name: 'Саша'),
          Member(uid: you, name: 'Лена'),
        ],
      ),
      accounts: [
        Account(name: 'Карта Salut', currency: 'USD'),
        Account(name: 'Цель: Отпуск', currency: 'MDL'),
      ],
      categories: [Category(name: 'Еда')],
      transactions: [
        Transaction(
          id: 't1',
          date: '2026-09-13',
          kind: TxKind.income,
          account: 'Карта Salut',
          currency: 'USD',
          amount: 1500,
          amountBase: 26123.32,
          category: 'Подарки',
          author: me,
          payer: me,
        ),
        Transaction(
          id: 't2',
          date: '2026-09-14',
          kind: TxKind.expense,
          account: 'Карта Salut',
          currency: 'MDL',
          amount: -1000,
          amountBase: -1000,
          category: 'Еда',
          author: me,
          payer: me,
          split: SplitMode.equal,
        ),
        Transaction(
          id: 't3',
          date: '2026-09-14',
          kind: TxKind.transfer,
          account: 'Цель: Отпуск',
          currency: 'MDL',
          amount: 200,
          amountBase: 200,
        ),
      ],
    );

Store storeOf() => Store()
  ..importBackupForTest(sample())
  ..viewer = me;

Future<void> openHome(WidgetTester tester, Store store) async {
  // Экран высокий нарочно: список главной ленивый, и блок, до которого не
  // дошла прокрутка, просто не построится.
  tester.view.physicalSize = const Size(393, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: HomeScreen(
      store: store,
      period: period,
      onPeriod: (_) {},
      onAccounts: () {},
      onBudgets: () {},
      onGoals: () {},
      onPlan: () {},
      onDebts: () {},
      onChat: () {},
      onSettings: () {},
      onNotices: () {},
      onDrill: (_, __, [Period? ___]) {},
    ),
  ));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Счёт в чужой валюте показывает пересчёт в базовую',
      (tester) async {
    await openHome(tester, storeOf());

    expect(find.textContaining('≈ MDL'), findsWidgets,
        reason: '«USD 1 500» под общей суммой в леях глазом не складывалось');
  });

  testWidgets('Цели говорят, что лежат вне общего баланса', (tester) async {
    await openHome(tester, storeOf());

    expect(find.text(tr('inGoals')), findsOneWidget);
    expect(find.text(tr('goalsOutsideBalance')), findsOneWidget);
  });

  testWidgets('Сальдо говорит направление, а не падеж имени', (tester) async {
    await openHome(tester, storeOf());

    final owed = find.textContaining(RegExp('^(Вам должны|Вы должны) '));
    expect(owed, findsOneWidget,
        reason: 'рядом стоит «Выровнять», и направление обязано быть в строке');
    expect(find.textContaining('Сальдо с '), findsOneWidget,
        reason: 'имя партнёра ушло в подпись, но не пропало');
  });

  testWidgets('Разговор о деньгах стоит НИЖЕ счетов', (tester) async {
    await openHome(tester, storeOf());

    final accounts = tester.getTopLeft(find.text(tr('accounts'))).dy;
    final date = tester.getTopLeft(find.text(tr('moneyDateTitle'))).dy;
    expect(date, greaterThan(accounts),
        reason: 'ненастроенное напоминание занимало лучшее место экрана');
  });

  testWidgets('Месяц стоит в строке заголовка, справа от него', (tester) async {
    await openHome(tester, storeOf());

    final title = tester.getTopLeft(find.text(tr('totalBalance')));
    // Месяц стоит и у потока ниже — берём первый, он из карточки баланса.
    final month = tester.getTopLeft(find.text(period.label).first);
    expect(month.dx, greaterThan(title.dx + 100),
        reason: 'месяц правее заголовка, решение человека 17.09.2026');
    expect((month.dy - title.dy).abs(), lessThan(24),
        reason: 'и в той же строке, а не у графика');
  });
}
