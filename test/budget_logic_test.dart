import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/buckets.dart';
import 'package:togetherly_money/logic/debts.dart';
import 'package:togetherly_money/logic/envelope.dart';
import 'package:togetherly_money/logic/goals.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/plan.dart';
import 'package:togetherly_money/logic/recurring.dart';
import 'package:togetherly_money/logic/reserve.dart';
import 'package:togetherly_money/logic/round_up.dart';

Transaction tx(
  String id,
  String date,
  double amount, {
  String account = 'Карта',
  String? category,
  TxKind kind = TxKind.expense,
  String currency = 'MDL',
  String payer = 'u_me',
}) =>
    Transaction(
      id: id,
      date: date,
      kind: kind,
      account: account,
      currency: currency,
      amount: amount,
      amountBase: amount,
      category: category,
      author: payer,
      payer: payer,
    );

void main() {
  group('вид расхода', () {
    test('подсказка по имени попадает в очевидное', () {
      expect(bucketGuess('Продукты'), Bucket.needs);
      expect(bucketGuess('Квартплата'), Bucket.needs);
      expect(bucketGuess('Кафе'), Bucket.wants);
      expect(bucketGuess('Подарки'), Bucket.wants);
      expect(bucketGuess('Накопления'), Bucket.savings);
      expect(bucketGuess('Ыъь'), Bucket.none);
    });

    test('своя разметка сильнее подсказки', () {
      const db = Database(categories: [
        Category(name: 'Кафе', bucket: Bucket.needs),
      ]);
      // Человек сказал, что обеды на работе — нужда. Спорить нельзя.
      expect(effectiveBucket(db, 'Кафе'), Bucket.needs);
    });

    test('подкатегория берёт вид родителя', () {
      const db = Database(categories: [
        Category(name: 'Еда', bucket: Bucket.needs),
        Category(name: 'Доставка', parent: 'Еда'),
      ]);
      expect(effectiveBucket(db, 'Доставка'), Bucket.needs);
    });
  });

  group('правило распределения', () {
    final period = Period.month(DateTime(2026, 9, 15));

    Database sample() => Database(
          baseCurrency: 'MDL',
          categories: const [
            Category(name: 'Продукты', bucket: Bucket.needs),
            Category(name: 'Кафе', bucket: Bucket.wants),
            Category(name: 'Зарплата'),
            Category(name: 'Тыгыдык'),
          ],
          goals: const [Goal(name: 'Отпуск', target: 10000, currency: 'MDL')],
          transactions: [
            tx('i1', '2026-09-05', 20000, kind: TxKind.income, category: 'Зарплата'),
            tx('e1', '2026-09-06', -8000, category: 'Продукты'),
            tx('e2', '2026-09-07', -3000, category: 'Кафе'),
            tx('e3', '2026-09-08', -500, category: 'Тыгыдык'),
            // Вклад в цель — это сбережение, а не трата: с кошелька деньги
            // уходят ПЕРЕВОДОМ, и в расход они не попадают.
            tx('g1', '2026-09-09', -2000, kind: TxKind.transfer),
            Transaction(
              id: 'g2', date: '2026-09-09', kind: TxKind.transfer,
              account: goalAccountOf('Отпуск'), currency: 'MDL',
              amount: 2000, amountBase: 2000, author: 'u_me', payer: 'u_me',
            ),
          ],
        );

    test('доли считаются от дохода, а не от расхода', () {
      final split = bucketsOf(sample(), period);
      expect(split.income, 20000);
      expect(split.needs, 8000);
      expect(split.wants, 3000);
      expect(split.savings, 2000);
      expect(split.unknown, 500);
      expect(split.shareOf(split.needs), closeTo(0.4, 0.001));
    });

    test('цель по правилу — это доля от дохода', () {
      const rules = Rules();
      final t = targetsOf(rules, 20000);
      expect(t.needs, 10000);
      expect(t.wants, 6000);
      expect(t.savings, 4000);
    });

    test('неразмеченные категории видны списком', () {
      expect(unmarkedCategories(sample(), period), ['Тыгыдык']);
    });

    test('свободный остаток не уходит в минус', () {
      final split = bucketsOf(sample(), period);
      expect(split.free, 6500);
    });
  });

  group('конверты', () {
    test('неделя считается с понедельника', () {
      final w = windowOf(BudgetPeriod.weekly, DateTime(2026, 9, 12)); // суббота
      expect(w.from, '2026-09-07');
      expect(w.to, '2026-09-13');
    });

    test('месяц целиком, включая последний день', () {
      final w = windowOf(BudgetPeriod.monthly, DateTime(2026, 2, 15));
      expect(w.from, '2026-02-01');
      expect(w.to, '2026-02-28');
    });

    test('без переноса остаток считается только за нынешний отрезок', () {
      final db = Database(
        baseCurrency: 'MDL',
        budgets: const [
          Budget(category: 'Кафе', limit: 1000, currency: 'MDL', period: 'weekly'),
        ],
        transactions: [
          tx('a', '2026-09-08', -300, category: 'Кафе'),
          tx('b', '2026-09-01', -900, category: 'Кафе'),
        ],
      );
      final env = envelopeOf(db, db.budgets.first, today: DateTime(2026, 9, 12));
      expect(env.spent, 300);
      expect(env.carried, 0);
      expect(env.left, 700);
    });

    test('сэкономленное переносится, перерасход тоже', () {
      final db = Database(
        baseCurrency: 'MDL',
        budgets: const [
          Budget(category: 'Кафе', limit: 1000, currency: 'MDL', period: 'weekly',
              rollover: true),
        ],
        transactions: [
          tx('a', '2026-09-08', -300, category: 'Кафе'), // эта неделя
          tx('b', '2026-09-01', -400, category: 'Кафе'), // прошлая: сэкономлено 600
        ],
      );
      final env = envelopeOf(db, db.budgets.first, today: DateTime(2026, 9, 12));
      expect(env.carried, 600);
      expect(env.allowance, 1600);
      expect(env.left, 1300);
      expect(env.over, isFalse);
    });

    test('из отрезка без трат ничего не переносится', () {
      // Конверт завели сегодня: в прошлой неделе трат по нему не было вовсе,
      // и «перенос» оттуда был бы деньгами из воздуха.
      final db = Database(
        baseCurrency: 'MDL',
        budgets: const [
          Budget(category: 'Кафе', limit: 1000, currency: 'MDL', period: 'weekly',
              rollover: true),
        ],
        transactions: [
          tx('a', '2026-09-08', -300, category: 'Кафе'),
        ],
      );
      final env = envelopeOf(db, db.budgets.first, today: DateTime(2026, 9, 12));
      expect(env.carried, 0);
      expect(env.allowance, 1000);
    });

    test('перерасход прошлого отрезка урезает нынешний', () {
      final db = Database(
        baseCurrency: 'MDL',
        budgets: const [
          Budget(category: 'Кафе', limit: 1000, currency: 'MDL', period: 'weekly',
              rollover: true),
        ],
        transactions: [
          tx('b', '2026-09-01', -1400, category: 'Кафе'),
        ],
      );
      final env = envelopeOf(db, db.budgets.first, today: DateTime(2026, 9, 12));
      expect(env.carried, -400);
      expect(env.allowance, 600);
    });
  });

  group('подушка', () {
    Database sample() => Database(
          baseCurrency: 'MDL',
          categories: const [
            Category(name: 'Продукты', bucket: Bucket.needs),
            Category(name: 'Кафе', bucket: Bucket.wants),
          ],
          goals: const [
            Goal(name: 'Подушка', target: 0, currency: 'MDL',
                kind: GoalKind.reserve, months: 6),
          ],
          transactions: [
            // Июнь, июль, август: нужды по 10 000, желания по 5 000.
            for (final m in [6, 7, 8]) ...[
              tx('n$m', '2026-0$m-10', -10000, category: 'Продукты'),
              tx('w$m', '2026-0$m-11', -5000, category: 'Кафе'),
            ],
            Transaction(
              id: 'r1', date: '2026-09-01', kind: TxKind.transfer,
              account: goalAccountOf('Подушка'), currency: 'MDL',
              amount: 24000, amountBase: 24000, author: 'u_me', payer: 'u_me',
            ),
          ],
        );

    test('средний расход считается по нуждам, а не по всему', () {
      expect(monthlyNeeds(sample(), today: DateTime(2026, 9, 12)), 10000);
    });

    test('цель подушки — месяцы, а не сумма', () {
      final r = reserveOf(sample(), sample().goals.first, today: DateTime(2026, 9, 12));
      expect(r.perMonth, 10000);
      expect(r.target, 60000);
      expect(r.saved, 24000);
      expect(r.monthsCovered, closeTo(2.4, 0.001));
      expect(r.left, 36000);
      expect(r.done, isFalse);
    });

    test('без истории подушка честно говорит, что считать не из чего', () {
      const db = Database(goals: [
        Goal(name: 'Подушка', target: 0, currency: 'MDL', kind: GoalKind.reserve, months: 6),
      ]);
      final r = reserveOf(db, db.goals.first, today: DateTime(2026, 9, 12));
      expect(r.unknown, isTrue);
      expect(r.target, 0);
    });
  });

  group('долги', () {
    Database sample() => Database(
          baseCurrency: 'MDL',
          debts: const [
            Debt(name: 'Микрозайм', kind: DebtKind.microloan, principal: 5000,
                rate: 120, minPayment: 1500, currency: 'MDL'),
            Debt(name: 'Кредитка', kind: DebtKind.card, principal: 24000,
                rate: 24.9, minPayment: 1200, currency: 'MDL'),
            Debt(name: 'Ипотека', kind: DebtKind.mortgage, principal: 600000,
                rate: 8.5, minPayment: 5000, currency: 'MDL'),
          ],
          transactions: [
            Transaction(
              id: 'p1', date: '2026-09-05', kind: TxKind.transfer,
              account: 'Долг: Кредитка', currency: 'MDL',
              amount: 4000, amountBase: 4000, author: 'u_me', payer: 'u_me',
            ),
          ],
        );

    test('осталось считается из платежей, а не из числа в записи', () {
      final st = stateOf(sample(), sample().debts[1]);
      expect(st.paid, 4000);
      expect(st.left, 20000);
      expect(st.share, closeTo(4000 / 24000, 0.0001));
    });

    test('лавина ставит вперёд дорогую ставку, снежный ком — маленький остаток', () {
      final db = sample();
      expect(payoffPlan(db, order: PayoffOrder.avalanche).map((s) => s.debt.name),
          ['Микрозайм', 'Кредитка', 'Ипотека']);
      expect(payoffPlan(db, order: PayoffOrder.snowball).map((s) => s.debt.name),
          ['Микрозайм', 'Кредитка', 'Ипотека']);
    });

    test('снежный ком отличается от лавины, когда остаток и ставка спорят', () {
      const db = Database(debts: [
        Debt(name: 'Дорогой', principal: 30000, rate: 30, minPayment: 2000, currency: 'MDL'),
        Debt(name: 'Мелкий', principal: 3000, rate: 10, minPayment: 500, currency: 'MDL'),
      ]);
      expect(payoffPlan(db, order: PayoffOrder.avalanche).first.debt.name, 'Дорогой');
      expect(payoffPlan(db, order: PayoffOrder.snowball).first.debt.name, 'Мелкий');
    });

    test('платёж, не перекрывающий проценты, не закрывает долг никогда', () {
      // 100 000 под 24% — это 2 000 процентов в месяц.
      expect(monthsToClose(100000, 24, 1500), isNull);
      expect(monthsToClose(100000, 24, 5000), isNotNull);
    });

    test('беспроцентный долг закрывается делением', () {
      expect(monthsToClose(10000, 0, 2500), 4);
    });

    test('сводка считает только открытые долги', () {
      final db = Database(
        debts: const [
          Debt(name: 'Закрытый', principal: 1000, rate: 10, minPayment: 100, currency: 'MDL'),
          Debt(name: 'Живой', principal: 5000, rate: 12, minPayment: 500, currency: 'MDL'),
        ],
        transactions: [
          Transaction(
            id: 'x', date: '2026-09-01', kind: TxKind.transfer,
            account: 'Долг: Закрытый', currency: 'MDL',
            amount: 1000, amountBase: 1000, author: 'u_me', payer: 'u_me',
          ),
        ],
      );
      final totals = debtTotals(db);
      expect(totals.open, 1);
      expect(totals.left, 5000);
      expect(totals.minPayments, 500);
      expect(totals.monthlyInterest, 50);
    });

    test('лишняя сумма поверх минимального платежа сокращает срок', () {
      final gain = payoffGain(sample(), 2000);
      expect(gain.monthsWithExtra! < gain.months!, isTrue);
    });
  });

  group('план на месяц', () {
    test('нераспределённое обязано сойтись в ноль', () {
      final db = Database(
        baseCurrency: 'MDL',
        plan: const [
          PlanItem(month: '2026-09', kind: PlanItemKind.category, name: 'Продукты',
              amount: 8000),
          PlanItem(month: '2026-09', kind: PlanItemKind.goal, name: 'Отпуск', amount: 2000),
        ],
        transactions: [
          tx('i1', '2026-09-05', 10000, kind: TxKind.income, category: 'Зарплата'),
          tx('e1', '2026-09-06', -7500, category: 'Продукты'),
        ],
      );
      final plan = planOf(db, DateTime(2026, 9, 12));
      expect(plan.income, 10000);
      expect(plan.planned, 10000);
      expect(plan.unassigned, 0);
      expect(plan.balanced, isTrue);
      final row = plan.rows.firstWhere((r) => r.name == 'Продукты');
      expect(row.actual, 7500);
      expect(row.left, 500);
    });

    test('незапланированная трата попадает в план строкой без плана', () {
      final db = Database(
        baseCurrency: 'MDL',
        transactions: [
          tx('e1', '2026-09-06', -300, category: 'Такси'),
        ],
      );
      final plan = planOf(db, DateTime(2026, 9, 12));
      final row = plan.rows.firstWhere((r) => r.name == 'Такси');
      expect(row.planned, 0);
      expect(row.actual, 300);
      expect(row.over, isTrue);
    });

    test('черновик раскладывает доход по правилу и прошлым тратам', () {
      final db = Database(
        baseCurrency: 'MDL',
        categories: const [
          Category(name: 'Продукты', bucket: Bucket.needs),
          Category(name: 'Аренда', bucket: Bucket.needs),
          Category(name: 'Кафе', bucket: Bucket.wants),
        ],
        goals: const [Goal(name: 'Отпуск', target: 100000, currency: 'MDL')],
        transactions: [
          tx('i1', '2026-09-01', 20000, kind: TxKind.income, category: 'Зарплата'),
          // Прошлый месяц: продукты 6000, аренда 2000, кафе 2000.
          tx('a', '2026-08-05', -6000, category: 'Продукты'),
          tx('b', '2026-08-06', -2000, category: 'Аренда'),
          tx('c', '2026-08-07', -2000, category: 'Кафе'),
        ],
      );
      final draft = draftPlan(db, DateTime(2026, 9, 12), lookback: 1);
      final by = {for (final x in draft) '${planItemKindName(x.kind)}|${x.name}': x.amount};
      // Нужды: 50% от 20 000 = 10 000, делятся 6:2 между продуктами и арендой.
      expect(by['category|Продукты'], 7500);
      expect(by['category|Аренда'], 2500);
      // Желания: 30% = 6 000, кафе единственное.
      expect(by['category|Кафе'], 6000);
      // Сбережения: 20% = 4 000, долгов нет, всё в цель.
      expect(by['goal|Отпуск'], 4000);
      expect(draft.fold<double>(0, (s, x) => s + x.amount), 20000);
    });

    test('минимальные платежи по долгам идут раньше целей', () {
      final db = Database(
        baseCurrency: 'MDL',
        categories: const [Category(name: 'Продукты', bucket: Bucket.needs)],
        goals: const [Goal(name: 'Отпуск', target: 100000, currency: 'MDL')],
        debts: const [
          Debt(name: 'Кредитка', principal: 20000, rate: 25, minPayment: 3000,
              currency: 'MDL'),
        ],
        transactions: [
          tx('i1', '2026-09-01', 20000, kind: TxKind.income, category: 'Зарплата'),
          tx('a', '2026-08-05', -6000, category: 'Продукты'),
        ],
      );
      final draft = draftPlan(db, DateTime(2026, 9, 12), lookback: 1);
      final by = {for (final x in draft) '${planItemKindName(x.kind)}|${x.name}': x.amount};
      expect(by['debt|Кредитка'], 3000);
      expect(by['goal|Отпуск'], 1000);
    });
  });

  group('регулярное', () {
    test('следующая дата не уползает по календарю', () {
      expect(nextAfter('2026-01-31', RecurringEvery.monthly), '2026-02-28');
      expect(nextAfter('2026-02-28', RecurringEvery.monthly), '2026-03-28');
      expect(nextAfter('2026-11-15', RecurringEvery.quarterly), '2027-02-15');
      expect(nextAfter('2026-09-12', RecurringEvery.yearly), '2027-09-12');
    });

    test('просроченное тоже ждёт своей очереди', () {
      const db = Database(recurring: [
        Recurring(id: 'a', name: 'Квартплата', amount: 2000, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-09-05',
            kind: 'expense', active: true),
        Recurring(id: 'b', name: 'Интернет', amount: 300, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-10-01',
            kind: 'expense', active: true),
        Recurring(id: 'c', name: 'Выключено', amount: 100, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-09-01',
            kind: 'expense', active: false),
      ]);
      expect(dueOn(db, today: DateTime(2026, 9, 12)).map((r) => r.id), ['a']);
    });

    test('отработавшая запись второй раз не срабатывает', () {
      const db = Database(recurring: [
        Recurring(id: 'a', name: 'Квартплата', amount: 2000, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-09-05',
            kind: 'expense', active: true, lastRun: '2026-09-05'),
      ]);
      expect(dueOn(db, today: DateTime(2026, 9, 12)), isEmpty);
    });

    test('месячная стоимость сводит кварталы и годы к месяцу', () {
      const db = Database(recurring: [
        Recurring(id: 'a', name: 'Месячное', amount: 300, currency: 'MDL',
            account: 'Карта', interval: 'monthly', nextDate: '2026-09-05',
            kind: 'expense', active: true),
        Recurring(id: 'b', name: 'Годовое', amount: 1200, currency: 'MDL',
            account: 'Карта', interval: 'yearly', nextDate: '2026-09-05',
            kind: 'expense', active: true),
      ]);
      expect(monthlyOf(db, RecurringKind.expense), 400);
    });
  });

  group('округление в копилку', () {
    test('добор до кратного считается по копейкам', () {
      expect(roundUpFor(137.40, 10), closeTo(2.60, 0.001));
      expect(roundUpFor(137.40, 50), closeTo(12.60, 0.001));
      expect(roundUpFor(100, 50), 0);
      expect(roundUpFor(0.5, 10), closeTo(9.50, 0.001));
    });

    test('округляется только обычный расход', () {
      const rules = Rules(roundUpStep: 10, roundUpGoal: 'Подушка');
      const op = Transaction(id: 'a', date: '2026-09-12', kind: TxKind.expense,
          account: 'Карта', currency: 'MDL', amount: -137.40, amountBase: -137.40);
      expect(roundUpApplies(op, rules), isTrue);
      expect(roundUpApplies(op, const Rules()), isFalse);

      const secret = Transaction(id: 'b', date: '2026-09-12', kind: TxKind.expense,
          account: 'Карта', currency: 'MDL', amount: -137.40, amountBase: -137.40,
          secret: true);
      // Вторая запись рядом со скрытой тратой выдала бы сюрприз.
      expect(roundUpApplies(secret, rules), isFalse);

      const income = Transaction(id: 'c', date: '2026-09-12', kind: TxKind.income,
          account: 'Карта', currency: 'MDL', amount: 1000, amountBase: 1000);
      expect(roundUpApplies(income, rules), isFalse);
    });
  });

  group('деньги переложены, а не потрачены', () {
    test('счета целей и долгов не попадают в кошельки и в расходы', () {
      final db = Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта', currency: 'MDL')],
        transactions: [
          tx('a', '2026-09-10', -2000),
          Transaction(
            id: 'g', date: '2026-09-10', kind: TxKind.transfer,
            account: goalAccountOf('Отпуск'), currency: 'MDL',
            amount: 2000, amountBase: 2000, author: 'u_me', payer: 'u_me',
          ),
          Transaction(
            id: 'd', date: '2026-09-10', kind: TxKind.transfer,
            account: debtAccountOf('Кредитка'), currency: 'MDL',
            amount: 1000, amountBase: 1000, author: 'u_me', payer: 'u_me',
          ),
        ],
      );
      expect(balances(db).map((a) => a.name), ['Карта']);
      expect(goalsTotal(db), 2000);
    });
  });

  group('прогон регулярного и платёж по долгу', () {
    Store storeWith(Database db) {
      final store = Store()..importBackupForTest(db);
      store.syncEnabled = true;
      store.viewer = 'u_me';
      return store;
    }

    test('платёж по долгу уводит деньги с кошелька и уменьшает остаток', () {
      final store = storeWith(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        debts: [
          Debt(name: 'Кредитка', principal: 24000, rate: 25, minPayment: 1200,
              currency: 'MDL'),
        ],
      ));
      store.payDebt(store.db.debts.first, from: 'Карта', amount: 1200);
      expect(balances(store.db).first.converted, -1200);
      expect(stateOf(store.db, store.db.debts.first).left, 22800);
      expect(store.outbox.where((k) => k.startsWith('tx:')).length, 2);
    });

    test('регулярный взнос в цель срабатывает сам и сдвигает дату', () {
      final store = storeWith(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        goals: [Goal(name: 'Подушка', target: 60000, currency: 'MDL')],
        recurring: [
          Recurring(id: 'r1', name: 'В подушку', amount: 1500, currency: 'MDL',
              account: 'Карта', interval: 'monthly', nextDate: '2026-09-05',
              kind: 'goal', active: true, target: 'Подушка'),
        ],
      ));
      final done = store.runRecurringDue(today: DateTime(2026, 9, 12));
      expect(done, 1);
      expect(progressOf(store.db, store.db.goals.first).saved, 1500);
      final r = store.db.recurring.first;
      expect(r.lastRun, '2026-09-05');
      expect(r.nextDate, '2026-10-05');
      // Второй прогон в тот же день ничего не добавляет.
      expect(store.runRecurringDue(today: DateTime(2026, 9, 12)), 0);
      expect(progressOf(store.db, store.db.goals.first).saved, 1500);
    });

    test('регулярный платёж записывается своей датой, а не сегодняшней', () {
      final store = storeWith(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        recurring: [
          Recurring(id: 'r1', name: 'Квартплата', amount: 2000, currency: 'MDL',
              account: 'Карта', interval: 'monthly', nextDate: '2026-09-05',
              kind: 'expense', active: true, category: 'Дом'),
        ],
      ));
      store.runRecurringDue(today: DateTime(2026, 9, 12));
      final op = store.db.transactions.firstWhere((t) => t.note == 'Квартплата');
      expect(op.date, '2026-09-05');
      expect(op.amount, -2000);
      expect(op.category, 'Дом');
    });

    test('округление кладёт разницу в цель отдельным переводом', () {
      final store = storeWith(const Database(
        baseCurrency: 'MDL',
        accounts: [Account(name: 'Карта', currency: 'MDL')],
        goals: [Goal(name: 'Подушка', target: 60000, currency: 'MDL')],
        rules: Rules(roundUpStep: 10, roundUpGoal: 'Подушка'),
      ));
      const op = Transaction(id: 'a', date: '2026-09-12', kind: TxKind.expense,
          account: 'Карта', currency: 'MDL', amount: -137.40, amountBase: -137.40,
          payer: 'u_me', author: 'u_me');
      store.saveOperation(op);
      final extra = store.roundUpAfter(op);
      expect(extra, closeTo(2.60, 0.001));
      expect(progressOf(store.db, store.db.goals.first).saved, closeTo(2.60, 0.001));
    });

    test('долг и план уезжают на сервер своими ключами', () {
      final store = storeWith(const Database(baseCurrency: 'MDL'));
      store.saveDebt(const Debt(name: 'Кредитка', principal: 1000, currency: 'MDL'));
      store.setPlanItem(const PlanItem(month: '2026-09', kind: PlanItemKind.category,
          name: 'Продукты', amount: 500));
      store.setRules(const Rules(roundUpStep: 50, roundUpGoal: 'Подушка'));
      expect(store.outbox, contains('debt:Кредитка'));
      expect(store.outbox, contains('plan:2026-09|category|Продукты'));
      expect(store.outbox, contains('settings:base'));
    });

    test('нулевая строка плана убирается, а не хранится нулём', () {
      final store = storeWith(const Database(plan: [
        PlanItem(month: '2026-09', kind: PlanItemKind.category, name: 'Продукты',
            amount: 500),
      ]));
      store.setPlanItem(const PlanItem(month: '2026-09', kind: PlanItemKind.category,
          name: 'Продукты', amount: 0));
      expect(store.db.plan, isEmpty);
    });

    test('долги и план приезжают дельтой, своё из очереди не затирается', () {
      final store = storeWith(const Database(baseCurrency: 'MDL'));
      store.saveDebt(const Debt(name: 'Своя', principal: 100, currency: 'MDL'));
      store.applyRemote({
        'now': 3,
        'debts': [
          {'name': 'Своя', 'principal': 999, 'currency': 'MDL', 'rate': 1, 'min_payment': 1},
          {'name': 'Чужая', 'principal': 5000, 'currency': 'MDL', 'rate': 20,
           'min_payment': 500, 'kind': 'card'},
        ],
        'plan': [
          {'month': '2026-09', 'item_kind': 'debt', 'item_name': 'Чужая', 'amount': 500},
        ],
        'recurring': [
          {'id': 'r1', 'name': 'Интернет', 'amount': 300, 'currency': 'MDL',
           'account': 'Карта', 'interval_rule': 'monthly', 'next_date': '2026-10-01',
           'kind': 'expense', 'active': true},
        ],
      });
      final by = {for (final d in store.db.debts) d.name: d};
      expect(by['Своя']!.principal, 100);
      expect(by['Чужая']!.kind, DebtKind.card);
      expect(store.db.plan.single.amount, 500);
      expect(store.db.recurring.single.name, 'Интернет');
    });

    test('разметка категории и подушка приезжают с сервера', () {
      final store = storeWith(const Database(baseCurrency: 'MDL'));
      store.applyRemote({
        'now': 5,
        'categories': [
          {'name': 'Кафе', 'bucket': 'needs'},
        ],
        'goals': [
          {'name': 'Подушка', 'target': 60000, 'currency': 'MDL', 'kind': 'reserve',
           'months': 6},
        ],
        'budgets': [
          {'category': 'Кафе', 'subcategory': '', 'limit_value': 900, 'currency': 'MDL',
           'period': 'weekly', 'rollover': true, 'scope': 'shared'},
        ],
      });
      expect(store.db.categories.single.bucket, Bucket.needs);
      expect(store.db.goals.single.isReserve, isTrue);
      expect(store.db.goals.single.months, 6);
      expect(store.db.budgets.single.rollover, isTrue);
      expect(store.db.budgets.single.periodKind, BudgetPeriod.weekly);
    });

    test('правила пары приезжают с сервера', () {
      final store = storeWith(const Database(baseCurrency: 'MDL'));
      store.applyRemote({
        'now': 4,
        'settings': {
          'base_currency': 'MDL',
          'plan_targets': {'needs': 6000, 'wants': 2000, 'savings': 2000},
          'round_up': 50,
          'round_up_goal': 'Подушка',
          'review_months': 3,
          'review_at': '2026-09-01',
          'pot_rules': {'notice': true, 'max_once': 3000},
        },
      });
      final rules = store.db.rules;
      expect(rules.needsBp, 6000);
      expect(rules.roundUpStep, 50);
      expect(rules.roundUpGoal, 'Подушка');
      expect(rules.reviewMonths, 3);
      expect(rules.potNotice, isTrue);
      expect(rules.potMaxOnce, 3000);
    });
  });
}
