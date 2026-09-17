import '../data/models.dart';
import 'buckets.dart';
import 'debts.dart';
import 'goals.dart';
import 'money.dart';
import 'period.dart';

/// План на месяц: «каждый рубль имеет работу».
///
/// Бюджет с нулевым балансом из второй статьи: доход раскладывается по
/// категориям, целям и долгам, пока нераспределённого не останется ноль.
/// План живёт рядом с фактом, поэтому в конце месяца видно не «много ли
/// потратили», а «сошлось ли с тем, о чём договаривались».

double _round2(double v) => (v * 100).roundToDouble() / 100;

String monthKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}';

/// Строка плана вместе с фактом.
class PlanRow {
  final PlanItemKind kind;
  final String name;

  /// Сколько отвели.
  final double planned;

  /// Сколько получилось.
  final double actual;

  const PlanRow({
    required this.kind,
    required this.name,
    required this.planned,
    required this.actual,
  });

  double get left => _round2(planned - actual);
  bool get over => left < -0.005;
  double get share => planned <= 0 ? (actual > 0 ? 1 : 0) : (actual / planned).clamp(0.0, 1.0);
}

/// План месяца целиком.
class MonthPlan {
  final String month;

  /// Доход, из которого раскладывается план: план строится на том, что
  /// приходит в этом месяце.
  final double income;

  final List<PlanRow> rows;

  /// Сколько строк человек завёл САМ. Ноль — плана нет, и всё, что лежит в
  /// `rows`, это просто траты месяца: показывать их планом нельзя.
  ///
  /// «Зачем мне создан план, который ещё не удаляется... я просил сделать
  /// ПУСТОЙ экран, где планы создаёт сам пользователь» (14.09.2026).
  final int ownRows;

  const MonthPlan({
    required this.month,
    required this.income,
    required this.rows,
    this.ownRows = 0,
  });

  /// Плана нет: человек не завёл ни одной строки за этот месяц.
  bool get isEmpty => ownRows == 0;

  double get planned => _round2(rows.fold<double>(0, (s, r) => s + r.planned));

  double get actual => _round2(rows.fold<double>(0, (s, r) => s + r.actual));

  /// Нераспределённое: в бюджете с нулевым балансом оно обязано быть нулём.
  double get unassigned => _round2(income - planned);

  bool get balanced => unassigned.abs() < 0.005;
}

/// Факт по строке плана за месяц, в базовой валюте.
double actualOf(Database db, PlanItemKind kind, String name, Period period) {
  var sum = 0.0;
  for (final t in db.transactions) {
    if (!period.contains(t.date)) continue;
    switch (kind) {
      case PlanItemKind.category:
        if (t.hidden || t.kind != TxKind.expense || t.category != name) continue;
        sum += convert(db, t.amount, t.currency).abs();
      case PlanItemKind.goal:
        if (t.account != goalAccountOf(name) || t.amount <= 0) continue;
        sum += convert(db, t.amount, t.currency);
      case PlanItemKind.debt:
        if (t.account != debtAccountOf(name) || t.amount <= 0) continue;
        sum += convert(db, t.amount, t.currency);
    }
  }
  return _round2(sum);
}

/// План месяца: отведённое рядом с фактом.
///
/// В плане показываются и строки без плана, у которых есть факт: трата,
/// которую не планировали, — самая важная строка в этом разговоре.
MonthPlan planOf(Database db, DateTime day) {
  final month = monthKey(day);
  final period = Period.month(day);

  final rows = <PlanRow>[];
  final seen = <String>{};

  for (final item in db.plan.where((x) => x.month == month)) {
    rows.add(PlanRow(
      kind: item.kind,
      name: item.name,
      planned: item.amount,
      actual: actualOf(db, item.kind, item.name, period),
    ));
    seen.add('${planItemKindName(item.kind)}|${item.name}');
  }

  // Незапланированные траты по категориям.
  final spent = <String, double>{};
  for (final t in db.transactions) {
    if (t.hidden || t.kind != TxKind.expense) continue;
    if (!period.contains(t.date)) continue;
    final name = (t.category ?? '').trim();
    if (name.isEmpty) continue;
    if (seen.contains('category|$name')) continue;
    spent[name] = (spent[name] ?? 0) + convert(db, t.amount, t.currency).abs();
  }
  for (final e in spent.entries) {
    rows.add(PlanRow(
      kind: PlanItemKind.category,
      name: e.key,
      planned: 0,
      actual: _round2(e.value),
    ));
  }

  var income = 0.0;
  for (final t in db.transactions) {
    if (t.hidden || t.kind != TxKind.income || !period.contains(t.date)) continue;
    income += convert(db, t.amount, t.currency).abs();
  }

  rows.sort((a, b) {
    if (a.planned == 0 && b.planned != 0) return 1;
    if (b.planned == 0 && a.planned != 0) return -1;
    return b.planned.compareTo(a.planned);
  });

  return MonthPlan(
    month: month,
    income: _round2(income),
    rows: rows,
    ownRows: seen.length,
  );
}

/// Черновик плана по правилу распределения.
///
/// Доли правила раскладываются по категориям в пропорции прошлых трат: у
/// человека, который три месяца тратил на продукты втрое больше, чем на кафе,
/// пустой план с равными числами вызывает только раздражение. Цели и долги
/// получают своё из доли сбережений: сперва минимальные платежи по долгам —
/// их нельзя не заплатить, — потом остаток в цели.
List<PlanItem> draftPlan(Database db, DateTime day, {int lookback = 3}) {
  final month = monthKey(day);
  final period = Period.month(day);
  final rules = db.rules;

  var income = 0.0;
  for (final t in db.transactions) {
    if (t.hidden || t.kind != TxKind.income || !period.contains(t.date)) continue;
    income += convert(db, t.amount, t.currency).abs();
  }
  // Дохода за этот месяц может ещё не быть: тогда берём прошлый — план
  // составляют в начале месяца, а не в конце.
  if (income <= 0.005) {
    final prev = Period.month(DateTime(day.year, day.month - 1, 1));
    for (final t in db.transactions) {
      if (t.hidden || t.kind != TxKind.income || !prev.contains(t.date)) continue;
      income += convert(db, t.amount, t.currency).abs();
    }
  }
  if (income <= 0.005) return const [];

  final targets = targetsOf(rules, income);
  final out = <PlanItem>[];

  // Прошлые траты по категориям, разложенные по видам.
  final past = <Bucket, Map<String, double>>{
    Bucket.needs: {},
    Bucket.wants: {},
    Bucket.savings: {},
    Bucket.none: {},
  };
  for (var back = 1; back <= lookback; back++) {
    final at = Period.month(DateTime(day.year, day.month - back, 1));
    for (final t in db.transactions) {
      if (t.hidden || t.kind != TxKind.expense || !at.contains(t.date)) continue;
      final name = (t.category ?? '').trim();
      if (name.isEmpty) continue;
      final bucket = effectiveBucket(db, name);
      final table = past[bucket]!;
      table[name] = (table[name] ?? 0) + convert(db, t.amount, t.currency).abs();
    }
  }

  void spread(Bucket bucket, double amount) {
    if (amount <= 0.005) return;
    final table = past[bucket]!;
    final total = table.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0.005) return;
    for (final e in table.entries) {
      final part = _round2(amount * e.value / total);
      if (part <= 0.005) continue;
      out.add(PlanItem(
        month: month,
        kind: PlanItemKind.category,
        name: e.key,
        amount: part,
      ));
    }
  }

  spread(Bucket.needs, targets.needs);
  spread(Bucket.wants, targets.wants);

  // Доля сбережений: сперва минимальные платежи по открытым долгам.
  var savings = targets.savings;
  for (final st in payoffPlan(db)) {
    if (st.closed || st.debt.minPayment <= 0) continue;
    final pay = convert(db, st.debt.minPayment, st.debt.currency);
    final part = pay <= savings ? pay : savings;
    if (part <= 0.005) continue;
    out.add(PlanItem(
      month: month,
      kind: PlanItemKind.debt,
      name: st.debt.name,
      amount: _round2(part),
    ));
    savings -= part;
  }

  // Остаток доли — в цели, начиная с подушки: резерв важнее отпуска.
  final goals = [
    ...db.goals.where((g) => g.isReserve),
    ...db.goals.where((g) => !g.isReserve),
  ];
  for (final g in goals) {
    if (savings <= 0.005) break;
    final left = progressOf(db, g).left;
    final need = left > 0 ? convert(db, left, g.currency) : savings;
    final part = need <= savings ? need : savings;
    if (part <= 0.005) continue;
    out.add(PlanItem(
      month: month,
      kind: PlanItemKind.goal,
      name: g.name,
      amount: _round2(part),
    ));
    savings -= part;
  }

  return out;
}
