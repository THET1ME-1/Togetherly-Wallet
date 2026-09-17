/// Прогноз конца месяца: сколько останется такими темпами и чего не хватит.
///
/// Считается НА УСТРОЙСТВЕ и из своих же записей: модель тут не нужна, а
/// деньги пары на сервер ради арифметики гонять незачем.
///
/// Правило прогноза одно и простое: продолжить то, что человек уже делает.
/// Темп берётся по ПРОЖИТЫМ дням этого месяца, а не по среднему за год —
/// спрашивают про этот месяц, в котором уже потрачено. Обязательное впереди
/// (регулярные платежи) вычитается отдельно: темп о них не знает, аренда
/// приходит одним куском в конце месяца.
library;

import '../data/models.dart';
import 'envelope.dart';
import 'money.dart';

/// Бюджет, который кончится раньше конца отрезка.
class DryingBudget {
  const DryingBudget({
    required this.category,
    required this.day,
    required this.left,
  });

  final String category;

  /// Число месяца, когда деньги в бюджете кончатся при нынешнем темпе.
  final int day;

  /// Сколько в нём осталось сейчас.
  final double left;
}

/// Платёж, который ещё придёт в этом месяце.
class DuePayment {
  const DuePayment({
    required this.name,
    required this.amount,
    required this.day,
  });

  final String name;
  final double amount;
  final int day;
}

/// Что будет к концу месяца.
class Forecast {
  const Forecast({
    required this.balance,
    required this.perDay,
    required this.daysLeft,
    required this.spendAhead,
    required this.due,
    required this.drying,
    required this.ready,
  });

  /// Сколько денег на счетах сейчас, в базовой валюте. Цели и долги сюда не
  /// входят: они уже отложены и потрачены быть не могут.
  final double balance;

  /// Средний расход в день по прожитым дням месяца.
  final double perDay;

  /// Сколько дней месяца ещё осталось.
  final int daysLeft;

  /// Сколько уйдёт до конца месяца по темпу.
  final double spendAhead;

  /// Обязательное впереди: регулярные платежи этого месяца.
  final List<DuePayment> due;

  /// Бюджеты, которые кончатся раньше срока.
  final List<DryingBudget> drying;

  /// Есть ли из чего считать. Первый день месяца темпа не даёт, и обещать по
  /// одной трате «вы потратите тридцать таких» — врать.
  final bool ready;

  double get dueAhead => _round2(due.fold<double>(0, (s, d) => s + d.amount));

  /// Сколько останется к концу месяца.
  double get left => _round2(balance - spendAhead - dueAhead);

  /// Денег не хватит: прогноз уходит в минус.
  bool get short => left < 0;
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Посчитать прогноз на конец месяца.
Forecast forecastOf(Database db, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final first = DateTime(today.year, today.month, 1);
  final lastDay = DateTime(today.year, today.month + 1, 0).day;
  final lived = today.day;
  final daysLeft = lastDay - lived;

  // Деньги, которыми человек реально распоряжается: счета без целей, долгов и
  // служебных. На цели отложенное тратить не планируют.
  final balance = totalBase([
    for (final a in balances(db))
      if (!isGoalAccount(a.name) &&
          !isDebtAccount(a.name) &&
          !isOutsideAccount(a.name))
        a,
  ]);

  // Расход месяца по прожитым дням. Взносы в цели и платежи по долгам сюда не
  // идут: это перекладывание своих же денег, а не трата.
  var spent = 0.0;
  for (final t in db.transactions) {
    if (t.kind != TxKind.expense) continue;
    if (isGoalAccount(t.account) || isDebtAccount(t.account)) continue;
    final at = DateTime.tryParse(t.date);
    if (at == null || at.isBefore(first) || at.isAfter(today)) continue;
    spent += convert(db, t.amount.abs(), t.currency);
  }

  final ready = lived > 1 && spent > 0;
  final perDay = ready ? _round2(spent / lived) : 0.0;
  final spendAhead = _round2(perDay * daysLeft);

  // Регулярное впереди: только платежи и только этого месяца. Доход в плюс не
  // берём — обещать деньги, которых ещё нет, хуже, чем промолчать.
  final due = <DuePayment>[];
  for (final r in db.recurring) {
    if (!r.active || r.kind == 'income') continue;
    final next = DateTime.tryParse(r.nextDate);
    if (next == null) continue;
    if (next.year != today.year || next.month != today.month) continue;
    if (next.day <= today.day) continue;
    due.add(DuePayment(
      name: r.name,
      amount: convert(db, r.amount.abs(), r.currency),
      day: next.day,
    ));
  }
  due.sort((a, b) => a.day.compareTo(b.day));

  // Бюджеты, которые кончатся раньше срока: считаем по темпу самого бюджета,
  // а не по общему — в кафе и на продукты тратят по-разному.
  final drying = <DryingBudget>[];
  for (final b in db.budgets) {
    final env = envelopeOf(db, b, today: today);
    if (env.left <= 0 || env.spent <= 0) continue;
    final daysIn = today.difference(DateTime.parse(env.window.from)).inDays + 1;
    if (daysIn < 2) continue;
    final rate = env.spent / daysIn;
    if (rate <= 0) continue;
    final daysToDry = (env.left / rate).floor();
    final dryAt = today.add(Duration(days: daysToDry));
    // Кончится ПОСЛЕ конца отрезка — значит человек уложился, и говорить не о
    // чем: бюджет на то и бюджет.
    if (!dryAt.isBefore(DateTime.parse(env.window.to))) continue;
    drying.add(DryingBudget(
      category: b.subcategory ?? b.category,
      day: dryAt.day,
      left: env.left,
    ));
  }
  drying.sort((a, b) => a.day.compareTo(b.day));

  return Forecast(
    balance: balance,
    perDay: perDay,
    daysLeft: daysLeft,
    spendAhead: spendAhead,
    due: due,
    drying: drying,
    ready: ready,
  );
}
