import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/envelope.dart';

Transaction spend(String id, String date, double amount) => Transaction(
      id: id,
      date: date,
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -amount,
      amountBase: -amount,
      category: 'Ремонт',
      author: 'u_me',
      payer: 'u_me',
    );

Database dbWith(List<Transaction> tx) => Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Ремонт')],
      transactions: tx,
    );

void main() {
  group('бюджет без периода', () {
    test('считает ВСЕ траты, а не месяц', () {
      // Предел на ремонт — это 50 000 всего, а не 50 000 каждый месяц.
      const budget = Budget(
        category: 'Ремонт',
        limit: 50000,
        currency: 'MDL',
        period: 'once',
      );
      final db = dbWith([
        spend('a', '2026-07-14', 12000),
        spend('b', '2026-08-02', 8000),
        spend('c', '2026-09-11', 5000),
      ]);
      final env = envelopeOf(db, budget, today: DateTime(2026, 9, 13));
      expect(env.spent, 25000);
      expect(env.left, 25000);
    });

    test('от даты начала более ранние траты не считаются', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 10000,
        currency: 'MDL',
        period: 'once',
        startDate: '2026-09-01',
      );
      final db = dbWith([
        spend('old', '2026-08-30', 4000),
        spend('new', '2026-09-05', 1000),
      ]);
      final env = envelopeOf(db, budget, today: DateTime(2026, 9, 13));
      expect(env.spent, 1000);
    });

    test('переноса у него нет: переносить неоткуда', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 1000,
        currency: 'MDL',
        period: 'once',
        rollover: true,
      );
      final db = dbWith([spend('a', '2026-09-11', 300)]);
      final env = envelopeOf(db, budget, today: DateTime(2026, 9, 13));
      expect(env.carried, 0);
      expect(env.allowance, 1000);
    });
  });

  group('свой отрезок', () {
    test('десять дней считаются от даты начала', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 2000,
        currency: 'MDL',
        period: 'custom',
        days: 10,
        startDate: '2026-09-01',
      );
      // 13 сентября — второй отрезок: 11–20 сентября.
      final window = windowFor(budget, DateTime(2026, 9, 13));
      expect(window.from, '2026-09-11');
      expect(window.to, '2026-09-20');

      final db = dbWith([
        spend('a', '2026-09-09', 700), // прошлый отрезок
        spend('b', '2026-09-12', 500),
      ]);
      final env = envelopeOf(db, budget, today: DateTime(2026, 9, 13));
      expect(env.spent, 500);
    });

    test('до даты начала отрезок не уезжает в минус', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 2000,
        currency: 'MDL',
        period: 'custom',
        days: 10,
        startDate: '2026-09-11',
      );
      final window = windowFor(budget, DateTime(2026, 9, 3));
      expect(window.from, '2026-09-11',
          reason: 'бюджета до его начала не существовало');
    });

    test('остаток переносится с прошлого отрезка', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 2000,
        currency: 'MDL',
        period: 'custom',
        days: 10,
        startDate: '2026-09-01',
        rollover: true,
      );
      final db = dbWith([
        spend('a', '2026-09-05', 1500),
        spend('b', '2026-09-12', 100),
      ]);
      final env = envelopeOf(db, budget, today: DateTime(2026, 9, 13));
      expect(env.carried, 500);
      expect(env.allowance, 2500);
      expect(env.left, 2400);
    });

    test('без длины отрезка свой период ведёт себя как месяц', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 2000,
        currency: 'MDL',
        period: 'custom',
      );
      final window = windowFor(budget, DateTime(2026, 9, 13));
      expect(window.from, '2026-09-01');
      expect(window.to, '2026-09-30');
    });
  });

  group('хранение', () {
    test('период, длина и начало доживают до диска и обратно', () {
      const budget = Budget(
        category: 'Ремонт',
        limit: 2000,
        currency: 'MDL',
        period: 'custom',
        days: 10,
        startDate: '2026-09-01',
      );
      final again = Budget.fromJson(budget.toJson());
      expect(again.periodKind, BudgetPeriod.custom);
      expect(again.days, 10);
      expect(again.startDate, '2026-09-01');
    });

    test('незнакомый период читается месяцем', () {
      expect(budgetPeriodOf('квартал'), BudgetPeriod.monthly);
      expect(budgetPeriodOf('once'), BudgetPeriod.once);
      expect(budgetPeriodName(BudgetPeriod.custom), 'custom');
    });
  });
}
