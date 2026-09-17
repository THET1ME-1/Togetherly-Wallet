import '../data/models.dart';
import 'buckets.dart';
import 'goals.dart';
import 'period.dart';

/// Подушка безопасности — в месяцах своих расходов, а не в сумме.
///
/// «Шесть месяцев» остаётся верным и когда траты выросли; «60 000» устаревает
/// молча и врёт в самый неподходящий момент. Обе статьи советуют от четырёх до
/// шести месяцев, поэтому цель задаётся месяцами, а сумма пересчитывается.

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Средний месячный расход за последние [months] полных месяцев.
///
/// Считаются только НУЖДЫ и обязательные платежи: подушка нужна, чтобы
/// пережить потерю дохода, а в такие месяцы поездки и кафе из расходов
/// уходят первыми. Если разметки нет вовсе, берётся весь расход — это
/// завышает подушку, и такая ошибка безопаснее обратной.
double monthlyNeeds(Database db, {int months = 3, DateTime? today}) {
  final day = today ?? DateTime.now();
  var needs = 0.0;
  var all = 0.0;
  var counted = 0;

  for (var back = 1; back <= months; back++) {
    final at = DateTime(day.year, day.month - back, 1);
    final period = Period.month(at);
    final split = bucketsOf(db, period);
    if (split.expense <= 0.005) continue;
    counted++;
    needs += split.needs;
    all += split.expense;
  }

  if (counted == 0) return 0;
  final byNeeds = needs / counted;
  return _round2(byNeeds > 0 ? byNeeds : all / counted);
}

/// Состояние подушки.
class Reserve {
  final Goal goal;

  /// Сколько уже лежит, в валюте цели.
  final double saved;

  /// Средний месячный расход, в валюте цели.
  final double perMonth;

  /// Сколько месяцев покрывает накопленное.
  final double monthsCovered;

  /// Сколько месяцев пара хочет покрыть.
  final int monthsWanted;

  const Reserve({
    required this.goal,
    required this.saved,
    required this.perMonth,
    required this.monthsCovered,
    required this.monthsWanted,
  });

  /// Сколько нужно накопить, чтобы покрыть [monthsWanted].
  double get target => _round2(perMonth * monthsWanted);

  double get left => _round2(target - saved > 0 ? target - saved : 0);

  double get share => target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0);

  bool get done => target > 0 && saved + 0.005 >= target;

  /// Считать не из чего: расходов за прошлые месяцы нет.
  bool get unknown => perMonth <= 0.005;
}

/// Подушка: накопленное, средний расход и сколько месяцев это покрывает.
Reserve reserveOf(Database db, Goal goal, {DateTime? today, int lookback = 3}) {
  final saved = progressOf(db, goal, today: today).saved;
  final perMonthBase = monthlyNeeds(db, months: lookback, today: today);
  final perMonth = _round2(inCurrency(db, perMonthBase, db.baseCurrency, goal.currency));
  final wanted = goal.months > 0 ? goal.months : 6;

  return Reserve(
    goal: goal,
    saved: saved,
    perMonth: perMonth,
    monthsCovered: perMonth <= 0 ? 0 : _round2(saved / perMonth),
    monthsWanted: wanted,
  );
}

/// Первая подушка среди целей. Их может быть несколько, но смысл имеет одна:
/// карточка на главной показывает её.
Goal? reserveGoal(Database db) {
  for (final g in db.goals) {
    if (g.isReserve) return g;
  }
  return null;
}

/// Сумма, которую стоит записать в цель-подушку, чтобы она не отставала от
/// выросших расходов: цель пересчитывается, а не хранится числом.
Goal withRecomputedTarget(Database db, Goal goal, {DateTime? today}) {
  if (!goal.isReserve) return goal;
  final r = reserveOf(db, goal, today: today);
  return goal.copyWith(target: r.target);
}
