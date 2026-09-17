import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/forecast.dart';

/// Прогноз конца месяца.
///
/// Обещан витриной Wallet+ словами «сколько останется такими темпами и чего не
/// хватит». Отсюда два требования, и оба проверяются здесь:
///
/// * прогноз считается по ТЕМПУ прожитых дней месяца, а не по среднему за
///   год: человек спрашивает про этот месяц, в котором он уже потратил;
/// * обязательное впереди (регулярные платежи) вычитается отдельно — темп о
///   них не знает, аренда приходит одним куском.

String day(int d) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, d).toIso8601String().substring(0, 10);
}

Transaction tx(String id, int d, double amount,
        {TxKind kind = TxKind.expense, String account = 'Карта'}) =>
    Transaction(
      id: id,
      date: day(d),
      kind: kind,
      account: account,
      currency: 'MDL',
      amount: kind == TxKind.expense ? -amount.abs() : amount,
      amountBase: kind == TxKind.expense ? -amount.abs() : amount,
      author: 'u_me',
      payer: 'u_me',
    );

Database dbOf({
  List<Transaction> transactions = const [],
  List<Recurring> recurring = const [],
  List<Budget> budgets = const [],
}) =>
    Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      transactions: transactions,
      recurring: recurring,
      budgets: budgets,
    );

Recurring rent(int dayOfMonth, double amount) => Recurring(
      id: 'rent',
      name: 'Аренда',
      amount: amount,
      currency: 'MDL',
      account: 'Карта',
      interval: 'monthly',
      nextDate: day(dayOfMonth),
      kind: 'payment',
      active: true,
    );

void main() {
  // Считаем от середины месяца: десятый день прожит, двадцать впереди.
  final now = DateTime(DateTime.now().year, DateTime.now().month, 10, 12);

  group('прогноз конца месяца', () {
    test('темп прожитых дней продолжается до конца месяца', () {
      // Пришло 10 000, за десять дней истрачено 2 000 — значит по 200 в день.
      final f = forecastOf(
        dbOf(transactions: [
          tx('in', 1, 10000, kind: TxKind.income),
          tx('t1', 3, 1000),
          tx('t2', 8, 1000),
        ]),
        now: now,
      );

      expect(f.perDay, closeTo(200, 0.01));
      final daysLeft = DateTime(now.year, now.month + 1, 0).day - 10;
      expect(f.daysLeft, daysLeft);
      // Остаток 8 000 минус темп на оставшиеся дни.
      expect(f.left, closeTo(8000 - 200 * daysLeft, 0.01));
    });

    test('обязательное впереди вычитается отдельно от темпа', () {
      // Аренда придёт 28-го одним куском: темп о ней ничего не знает, и без
      // отдельного вычета прогноз обещал бы деньги, которых не будет.
      final f = forecastOf(
        dbOf(
          transactions: [
            tx('in', 1, 10000, kind: TxKind.income),
            tx('t1', 5, 2000),
          ],
          recurring: [rent(28, 4000)],
        ),
        now: now,
      );

      expect(f.dueAhead, closeTo(4000, 0.01));
      expect(f.due.single.name, 'Аренда');
      expect(f.left, closeTo(f.balance - f.spendAhead - 4000, 0.01));
    });

    test('денег не хватит — прогноз говорит это прямо', () {
      final f = forecastOf(
        dbOf(
          transactions: [
            tx('in', 1, 5000, kind: TxKind.income),
            tx('t1', 5, 4000),
          ],
          recurring: [rent(28, 4000)],
        ),
        now: now,
      );

      expect(f.short, isTrue);
      expect(f.left, lessThan(0));
    });

    test('бюджет кончится раньше срока — видно, какой и когда', () {
      // Лимит 3 000 на месяц, за десять дней истрачено 2 000: по 200 в день,
      // хватит ещё на пять дней.
      final f = forecastOf(
        dbOf(
          transactions: [
            tx('in', 1, 10000, kind: TxKind.income),
            Transaction(
              id: 'food',
              date: day(5),
              kind: TxKind.expense,
              account: 'Карта',
              currency: 'MDL',
              amount: -2000,
              amountBase: -2000,
              category: 'Продукты',
              author: 'u_me',
              payer: 'u_me',
            ),
          ],
          budgets: const [
            Budget(
              category: 'Продукты',
              limit: 3000,
              currency: 'MDL',
              period: 'monthly',
            ),
          ],
        ),
        now: now,
      );

      final dry = f.drying.single;
      expect(dry.category, 'Продукты');
      expect(dry.day, 15);
    });

    test('первый день месяца: темпа ещё нет, прогноз молчит', () {
      // Делить на ноль прожитых дней нельзя, а обещать по одной трате «вы
      // потратите тридцать таких» — врать.
      final f = forecastOf(
        dbOf(transactions: [tx('in', 1, 10000, kind: TxKind.income)]),
        now: DateTime(now.year, now.month, 1, 9),
      );

      expect(f.ready, isFalse);
      expect(f.perDay, 0);
    });

    test('последний день месяца: тратить дальше некуда', () {
      final last = DateTime(now.year, now.month + 1, 0).day;
      final f = forecastOf(
        dbOf(transactions: [
          tx('in', 1, 10000, kind: TxKind.income),
          tx('t1', 3, 3000),
        ]),
        now: DateTime(now.year, now.month, last, 20),
      );

      expect(f.daysLeft, 0);
      expect(f.spendAhead, 0);
      expect(f.left, closeTo(f.balance, 0.01));
    });
  });
}
