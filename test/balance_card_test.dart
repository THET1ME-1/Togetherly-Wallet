import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/widgets/charts.dart';

import 'tm_fonts.dart';

Database sample() => const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Наличные', currency: 'MDL'),
        Account(name: 'Банковский счёт', currency: 'MDL'),
      ],
      categories: [Category(name: 'Еда')],
      transactions: [
        Transaction(
          id: 'i1', date: '2026-09-01', kind: TxKind.income,
          account: 'Наличные', currency: 'MDL', amount: 1000, amountBase: 1000,
        ),
        Transaction(
          id: 'e1', date: '2026-09-12', kind: TxKind.expense,
          account: 'Наличные', currency: 'MDL', amount: -75, amountBase: -75,
          category: 'Еда',
        ),
        Transaction(
          id: 'e2', date: '2026-09-12', kind: TxKind.expense,
          account: 'Банковский счёт', currency: 'MDL', amount: -300,
          amountBase: -300, category: 'Еда',
        ),
      ],
    );

/// В приложении главную перестраивает ListenableBuilder оболочки — здесь то
/// же самое, иначе настройка карточки меняется, а экран этого не видит.
Widget app(Store store) => MaterialApp(
      theme: MoneyTheme.light(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: store,
          builder: (context, _) => HomeScreen(
          store: store,
          period: Period.month(DateTime(2026, 9, 12)),
          onPeriod: (_) {},
          onAccounts: () {},
          onBudgets: () {},
          onGoals: () {},
          onPlan: () {},
          onDebts: () {},
          onChat: () {},
          onSettings: () {},
            onDrill: (_, __, [period]) {},
          ),
        ),
      ),
    );

void main() {
  setUpAll(loadTmFonts);

  group('общий баланс', () {
    testWidgets('свёрнут: сумма и мини-график, без отрезков и осей',
        (tester) async {
      final store = Store()..importBackupForTest(sample());

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text('Общий баланс'), findsOne);
      expect(find.byType(Sparkline), findsOne);
      // Большой график и стрелки прячутся, пока карточку не развернули.
      expect(find.byType(DayChart), findsNothing);
      expect(find.byTooltip('Раньше'), findsNothing);
    });

    testWidgets('касание разворачивает и оставляет так', (tester) async {
      final store = Store()..importBackupForTest(sample());

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Общий баланс'));
      await tester.pumpAndSettle();

      expect(store.balanceOpen, isTrue);
      expect(find.byType(DayChart), findsOne);
      expect(find.byType(Sparkline), findsNothing);
      // Отрезок задаётся кнопкой в углу, а не сегментами внутри карточки.
      expect(find.byTooltip('Раньше'), findsOne);
      expect(find.byTooltip('Позже'), findsOne);

      await tester.tap(find.text('Общий баланс'));
      await tester.pumpAndSettle();
      expect(store.balanceOpen, isFalse);
    });

    testWidgets('отбор счетов меняет сумму и подписан числом счетов',
        (tester) async {
      final store = Store()..importBackupForTest(sample());

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      // Всё вместе: 1000 − 75 − 300.
      expect(find.textContaining('625,00'), findsWidgets);

      await tester.tap(find.byTooltip('Какие счета считать'));
      await tester.pumpAndSettle();

      // «Наличные» есть и в списке счетов на главной: берём строку из листа.
      await tester.tap(find.descendant(
        of: find.byType(CheckboxListTile),
        matching: find.text('Наличные'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Готово'));
      await tester.pumpAndSettle();

      expect(store.balanceAccounts, {'Наличные'});
      // Остались только наличные: 1000 − 75.
      expect(find.textContaining('925,00'), findsWidgets);
      expect(find.textContaining('счетов: 1'), findsOne);
    });

    test('ряд баланса считается по выбранным счетам', () {
      final db = sample();
      final period = Period.month(DateTime(2026, 9, 12));

      final all = balanceSeries(db, period);
      final cash = balanceSeries(db, period, accounts: {'Наличные'});

      expect(all.last.value, 625);
      expect(cash.last.value, 925);
    });
  });
}
