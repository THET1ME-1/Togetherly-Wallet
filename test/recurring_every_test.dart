import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/recurring.dart';

Recurring rec({
  required String every,
  int? days,
  String next = '2026-09-13',
  double amount = 300,
  bool active = true,
}) =>
    Recurring(
      id: 'r1',
      name: 'Подписка',
      amount: amount,
      currency: 'MDL',
      account: 'Карта',
      interval: every,
      nextDate: next,
      kind: 'expense',
      active: active,
      days: days,
    );

void main() {
  group('свой интервал', () {
    test('каждые десять дней', () {
      expect(nextAfter('2026-09-13', RecurringEvery.custom, days: 10),
          '2026-09-23');
      // Через границу месяца тоже считается днями, а не числами месяца.
      expect(nextAfter('2026-09-25', RecurringEvery.custom, days: 10),
          '2026-10-05');
    });

    test('неделя — это просто семь дней', () {
      expect(nextAfter('2026-09-13', RecurringEvery.weekly), '2026-09-20');
    });

    test('без длины свой интервал ведёт себя как месяц', () {
      expect(nextAfter('2026-09-13', RecurringEvery.custom), '2026-10-13');
    });

    test('в месяц уходит своя доля', () {
      final db = Database(
        baseCurrency: 'MDL',
        recurring: [
          rec(every: 'weekly', amount: 70),       // 70 × 30/7 ≈ 300
          rec(every: 'custom', days: 10, amount: 100), // 100 × 3 = 300
        ],
      );
      expect(monthlyOf(db, RecurringKind.expense), closeTo(600, 1));
    });
  });

  group('разовая запись', () {
    test('после прогона выключается, а не переезжает на месяц вперёд', () {
      final once = rec(every: 'once', next: '2026-09-13');
      final after = afterRun(once);
      expect(after.active, isFalse,
          reason: 'разовый платёж на то и разовый');
      expect(after.nextDate, '2026-09-13');
    });

    test('обычная запись после прогона едет дальше и остаётся живой', () {
      final monthly = rec(every: 'monthly', next: '2026-09-13');
      final after = afterRun(monthly);
      expect(after.active, isTrue);
      expect(after.nextDate, '2026-10-13');
    });

    test('в месячную нагрузку разовая не входит', () {
      final db = Database(
        baseCurrency: 'MDL',
        recurring: [rec(every: 'once', amount: 5000)],
      );
      expect(monthlyOf(db, RecurringKind.expense), 0);
    });
  });

  group('хранение', () {
    test('интервал и длина доживают до диска и обратно', () {
      final r = rec(every: 'custom', days: 10);
      final again = Recurring.fromJson(r.toJson());
      expect(again.every, RecurringEvery.custom);
      expect(again.days, 10);
    });

    test('незнакомый интервал читается месяцем', () {
      expect(recurringEveryOf('каждые полнолуния'), RecurringEvery.monthly);
      expect(recurringEveryOf('weekly'), RecurringEvery.weekly);
      expect(recurringEveryName(RecurringEvery.once), 'once');
    });
  });
}
