import '../data/models.dart';
import '../l10n/strings.dart';

/// Регулярное: обязательные платежи и правило «заплати себе первым».
///
/// Взнос в цель сразу после дохода — не пожелание, а запись, которая
/// срабатывает сама. Обе статьи говорят об этом одинаково: откладывать надо
/// первым платежом, а не тем, что осталось к концу месяца.

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Следующая дата после [from] по правилу [every].
///
/// Месяц считается календарно: 31 января плюс месяц — это 28 февраля, а не
/// 3 марта. Иначе платёж уползает по календарю, а он привязан к числу.
String nextAfter(String from, RecurringEvery every, {int? days}) {
  final at = DateTime.tryParse(from);
  if (at == null) return from;
  // Недели и свой интервал считаются ДНЯМИ: «каждые десять дней» не ложится
  // на числа месяца, а неделя ложится только случайно.
  if (every == RecurringEvery.weekly) {
    return _iso(at.add(const Duration(days: 7)));
  }
  if (every == RecurringEvery.custom && (days ?? 0) > 0) {
    return _iso(at.add(Duration(days: days!)));
  }
  // Разовая запись никуда не переезжает: её выключает `afterRun`.
  if (every == RecurringEvery.once) return from;
  final step = switch (every) {
    RecurringEvery.quarterly => 3,
    RecurringEvery.yearly => 12,
    _ => 1,
  };
  final year = at.year + ((at.month - 1 + step) ~/ 12);
  final month = (at.month - 1 + step) % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return _iso(DateTime(year, month, at.day > lastDay ? lastDay : at.day));
}

/// Запись после срабатывания: разовая выключается, остальные переезжают на
/// следующий срок.
///
/// Раньше это лежало прямо в `Store.runRecurringDue` одной строкой — и разовый
/// платёж, которого тогда не было, уехал бы на месяц вперёд.
Recurring afterRun(Recurring r, {String? on}) {
  final day = on ?? r.nextDate;
  if (r.every == RecurringEvery.once) {
    return r.copyWith(lastRun: day, active: false);
  }
  return r.copyWith(
    lastRun: day,
    nextDate: nextAfter(day, r.every, days: r.days),
  );
}

/// Записи, которым пора сработать на [today] включительно.
///
/// Просроченные тоже здесь: приложение открывают не каждый день, и платёж от
/// пятого числа обязан появиться седьмого, а не пропасть.
List<Recurring> dueOn(Database db, {DateTime? today}) {
  final day = _iso(today ?? DateTime.now());
  final out = <Recurring>[];
  for (final r in db.recurring) {
    if (!r.active || r.nextDate.isEmpty) continue;
    if (r.nextDate.compareTo(day) > 0) continue;
    // Отметка прогона — вторая защита от двойного списания: дата могла не
    // сдвинуться, если запись не доехала на сервер.
    if (r.lastRun == r.nextDate) continue;
    out.add(r);
  }
  out.sort((a, b) => a.nextDate.compareTo(b.nextDate));
  return out;
}

/// Что спишется в ближайшие [days] дней — и что уже просрочено.
///
/// Напоминание о счёте до срока есть во всех приложениях для пар (Honeydue,
/// Monarch): забытый платёж стоит пени, а приложение о нём знало.
List<Recurring> dueSoon(Database db, {DateTime? today, int days = 3}) {
  final day = today ?? DateTime.now();
  final edge = _iso(DateTime(day.year, day.month, day.day + days));
  final out = <Recurring>[];
  for (final r in db.recurring) {
    if (!r.active || r.nextDate.isEmpty) continue;
    if (r.lastRun == r.nextDate) continue;
    if (r.nextDate.compareTo(edge) > 0) continue;
    out.add(r);
  }
  out.sort((a, b) => a.nextDate.compareTo(b.nextDate));
  return out;
}

/// Сколько всего уходит в месяц по регулярным записям заданного вида.
double monthlyOf(Database db, RecurringKind kind) {
  var sum = 0.0;
  for (final r in db.recurring) {
    if (!r.active || r.kindOf != kind) continue;
    sum += switch (r.every) {
      RecurringEvery.monthly => r.amount,
      RecurringEvery.quarterly => r.amount / 3,
      RecurringEvery.yearly => r.amount / 12,
      // Месяц считаем тридцатью днями: «каждые десять дней» это трижды в
      // месяц, и точность тут не нужнее простоты.
      RecurringEvery.weekly => r.amount * 30 / 7,
      RecurringEvery.custom => (r.days ?? 0) > 0 ? r.amount * 30 / r.days! : r.amount,
      // Разовая запись не нагрузка, а событие: в «сколько уходит в месяц» ей
      // не место.
      RecurringEvery.once => 0,
    };
  }
  return (sum * 100).roundToDouble() / 100;
}

/// Человеческое название срока. Было прибито русским прямо здесь: на
/// английском экране стояло «Каждый месяц».
String everyTitle(RecurringEvery e, {int? days}) => switch (e) {
      RecurringEvery.weekly => tr('everyWeekly'),
      RecurringEvery.monthly => tr('everyMonthly'),
      RecurringEvery.quarterly => tr('everyQuarterly'),
      RecurringEvery.yearly => tr('everyYearly'),
      RecurringEvery.custom => (days ?? 0) > 0
          ? trf('everyCustomDays', ['$days'])
          : tr('everyCustom'),
      RecurringEvery.once => tr('everyOnce'),
    };

String recurringKindTitle(RecurringKind k) => switch (k) {
      RecurringKind.expense => tr('recurringKindPayment'),
      RecurringKind.income => tr('recurringKindIncome'),
      RecurringKind.goal => tr('recurringKindGoal'),
      RecurringKind.debt => tr('recurringKindDebt'),
    };
