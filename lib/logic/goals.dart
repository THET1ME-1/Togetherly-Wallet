import '../data/models.dart';
import 'money.dart';

/// Цели с вкладами каждого.
///
/// Отложенное не хранится числом: вклад — это ПЕРЕВОД, две записи, и деньги
/// видно там, где они лежат. Иначе «накоплено» разошлось бы с остатками
/// кошельков на первом же снятии, а спорить с парой о пропавших деньгах хуже,
/// чем о лишней строке в истории.
///
/// Кто сколько положил, считается по `payer` записи на счёте цели. Поэтому
/// вклад партнёра видно и тогда, когда вносил его другой человек с другого
/// устройства.

/// Виртуальный счёт цели: `Цель: Отпуск`.
String goalAccountOf(String name) => '$goalPrefix$name';

/// Обратно: из имени счёта — имя цели.
String goalNameOf(String account) =>
    account.startsWith(goalPrefix) ? account.substring(goalPrefix.length) : account;

/// Пересчёт между валютами через базовую: своего курса «из в» у нас нет.
double inCurrency(Database db, double amount, String from, String to) {
  if (from == to) return amount;
  final base = convert(db, amount, from);
  final rate = rateOf(db, to);
  return rate == 0 ? base : base / rate;
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Что видно про одну цель.
class GoalProgress {
  final Goal goal;

  /// Накоплено в валюте цели.
  final double saved;

  /// Кто сколько внёс: uid → сумма в валюте цели. Пустой uid — вклады, у
  /// которых плательщик не записан (данные Орбиты до пары).
  final Map<String, double> byMember;

  /// Сколько осталось до цели. Ноль, если цель без суммы или уже закрыта.
  final double left;

  /// Доля от цели, 0..1. У цели без суммы — 0.
  final double share;

  /// Дней до срока. Пусто — срока нет; отрицательное — срок прошёл.
  final int? daysLeft;

  const GoalProgress({
    required this.goal,
    required this.saved,
    required this.byMember,
    required this.left,
    required this.share,
    required this.daysLeft,
  });

  bool get hasTarget => goal.target > 0;
  bool get done => hasTarget && saved + 0.005 >= goal.target;
  bool get overdue => daysLeft != null && daysLeft! < 0 && !done;

  /// Сколько откладывать в день, чтобы успеть к сроку. Пусто — считать не от
  /// чего: нет суммы, нет срока или уже накоплено.
  double? get perDay {
    final days = daysLeft;
    if (!hasTarget || days == null || done) return null;
    if (days <= 0) return null;
    return _round2(left / days);
  }
}

/// Сколько лежит на счёте цели и чьими вкладами.
GoalProgress progressOf(Database db, Goal goal, {DateTime? today}) {
  final account = goalAccountOf(goal.name);
  var saved = 0.0;
  final by = <String, double>{};

  for (final t in db.transactions) {
    if (t.account != account) continue;
    final value = inCurrency(db, t.amount, t.currency, goal.currency);
    saved += value;
    final who = (t.payer ?? t.author ?? '').trim();
    by[who] = (by[who] ?? 0) + value;
  }

  saved = _round2(saved);
  final left = goal.target > 0 ? _round2(goal.target - saved) : 0.0;
  final share = goal.target > 0 ? (saved / goal.target).clamp(0.0, 1.0) : 0.0;

  int? days;
  final deadline = (goal.deadline ?? '').trim();
  if (deadline.isNotEmpty) {
    final at = DateTime.tryParse(deadline);
    if (at != null) {
      final now = today ?? DateTime.now();
      // Считаем календарными сутками, а не часами: «осталось 0 дней» в день
      // срока честнее, чем «осталось 18 часов».
      days = DateTime(at.year, at.month, at.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
    }
  }

  return GoalProgress(
    goal: goal,
    saved: saved,
    byMember: {for (final e in by.entries) e.key: _round2(e.value)},
    left: left < 0 ? 0 : left,
    share: share,
    daysLeft: days,
  );
}

/// Все цели пары: и заведённые, и просто накопленное на счёте цели.
///
/// Второе встречается в данных Орбиты: там цель — это счёт с приставкой, а
/// записи о сумме и сроке не было вовсе. Прятать такие деньги нельзя.
List<GoalProgress> allGoals(Database db, {DateTime? today}) {
  final named = {for (final g in db.goals) g.name: g};

  // Цель без записи собирается из операций по её счёту, но ТОЛЬКО пока на нём
  // лежат деньги. Иначе удалённая цель возвращалась на экран вечно: записи
  // нет, остаток ноль, а старые переводы никуда не делись («цели нельзя
  // удалить», 17.09.2026).
  final left = <String, double>{};
  final money = <String, String>{};
  for (final t in db.transactions) {
    if (!isGoalAccount(t.account)) continue;
    final name = goalNameOf(t.account);
    left[name] = (left[name] ?? 0) + t.amount;
    money[name] = t.currency;
  }
  left.forEach((name, saved) {
    if (saved.abs() < 0.005) return;
    named.putIfAbsent(
        name, () => Goal(name: name, target: 0, currency: money[name] ?? db.baseCurrency));
  });

  final out = [
    for (final g in named.values) progressOf(db, g, today: today),
  ];

  // Впереди то, что ещё копится, и раньше — то, чему ближе срок.
  out.sort((a, b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ad = a.daysLeft, bd = b.daysLeft;
    if (ad != null && bd != null && ad != bd) return ad.compareTo(bd);
    if (ad == null && bd != null) return 1;
    if (ad != null && bd == null) return -1;
    return a.goal.name.compareTo(b.goal.name);
  });
  return out;
}
