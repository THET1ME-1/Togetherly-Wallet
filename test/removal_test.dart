import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/debts.dart';

/// Те же три беды, что нашлись у целей, проверяем у бюджетов, долгов и
/// регулярных: убирается ли запись совсем и не возвращается ли она из
/// вычисляемых источников.
Store storeOf() {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Продукты')],
      budgets: const [
        Budget(category: 'Продукты', limit: 2000, currency: 'MDL',
            period: 'monthly'),
      ],
      debts: const [
        Debt(name: 'Ноутбук', principal: 14000, currency: 'MDL',
            minPayment: 1400, dueDay: 12),
      ],
      recurring: const [
        Recurring(id: 'r1', name: 'Аренда', amount: -6500, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-10-03',
            kind: 'expense', active: true, target: ''),
      ],
    ));
  store.viewer = 'u_me';
  return store;
}

void main() {
  test('Бюджет убирается и не возвращается', () {
    final store = storeOf();
    store.setBudgets(const []);

    expect(store.db.budgets, isEmpty);
  });

  test('Долг убирается вместе со своими платежами', () {
    final store = storeOf();
    final debt = store.db.debts.first;
    store.payDebt(debt, from: 'Карта', amount: 1400);
    store.deleteDebt(debt.name);

    expect(store.db.debts, isEmpty);
    expect(payoffPlan(store.db), isEmpty,
        reason: 'долг не должен собираться обратно из платежей');
  });

  test('Регулярное убирается', () {
    final store = storeOf();
    store.deleteRecurring('r1');

    expect(store.db.recurring, isEmpty);
  });
}
