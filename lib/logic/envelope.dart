import '../data/models.dart';
import 'money.dart';

/// Конверты: сколько осталось в лимите за нынешний период и что перенеслось
/// с прошлого.
///
/// Лимит без периода и переноса — это месячный потолок, а не конверт.
/// Сэкономил на кафе в марте — в апреле у тебя больше запаса; вышел за предел
/// — в следующем периоде запас меньше. Ровно так работает система конвертов из
/// обеих статей, только без наличных.

double _round2(double v) => (v * 100).roundToDouble() / 100;

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Отрезок конверта: с какого дня по какой включительно.
class EnvelopeWindow {
  final String from;
  final String to;
  const EnvelopeWindow(this.from, this.to);

  bool contains(String date) => date.compareTo(from) >= 0 && date.compareTo(to) <= 0;
}

/// Нынешний отрезок ЛИМИТА — с его собственной длиной и началом.
///
/// Календарные периоды считает `windowOf`, а свой отрезок и предел без
/// периода живут только здесь: у них есть якорь, которого у месяца нет.
EnvelopeWindow windowFor(Budget budget, DateTime day) {
  final period = budget.periodKind;
  if (period == BudgetPeriod.once) {
    // Предел без периода не обнуляется: он считает всё с первого дня и до
    // скончания времён. Раньше начала бюджета трат у него нет по определению.
    return EnvelopeWindow(budget.startDate ?? '0000-01-01', '9999-12-31');
  }
  if (period == BudgetPeriod.custom) {
    final days = budget.days ?? 0;
    // Длины нет — период ведёт себя как месяц: это честнее, чем делить на ноль
    // или показывать пустой отрезок.
    if (days <= 0) return windowOf(BudgetPeriod.monthly, day);
    final start = DateTime.tryParse(budget.startDate ?? '') ??
        DateTime(day.year, day.month, 1);
    final from = DateTime(start.year, start.month, start.day);
    final today = DateTime(day.year, day.month, day.day);
    final passed = today.difference(from).inDays;
    // До начала бюджет стоит на первом отрезке: отрицательный номер уводил бы
    // окно в прошлое, которого у этого лимита не было.
    final step = passed < 0 ? 0 : passed ~/ days;
    final left = from.add(Duration(days: step * days));
    return EnvelopeWindow(_iso(left), _iso(left.add(Duration(days: days - 1))));
  }
  return windowOf(period, day);
}

/// Предыдущий отрезок ЛИМИТА.
EnvelopeWindow? previousWindowFor(Budget budget, DateTime day) {
  final period = budget.periodKind;
  // У предела без периода прошлого отрезка не бывает: он один на всю жизнь.
  if (period == BudgetPeriod.once) return null;
  if (period == BudgetPeriod.custom) {
    final days = budget.days ?? 0;
    if (days <= 0) return previousWindow(BudgetPeriod.monthly, day);
    final now = windowFor(budget, day);
    final from = DateTime.parse(now.from);
    final start = DateTime.tryParse(budget.startDate ?? '') ?? from;
    // Первый отрезок — самый первый: переносить в него неоткуда.
    if (!from.isAfter(start)) return null;
    final left = from.subtract(Duration(days: days));
    return EnvelopeWindow(_iso(left), _iso(left.add(Duration(days: days - 1))));
  }
  return previousWindow(period, day);
}

/// Нынешний отрезок для календарного периода. Неделя считается с понедельника:
/// у людей неделя начинается с него, а не с воскресенья.
EnvelopeWindow windowOf(BudgetPeriod period, DateTime day) {
  switch (period) {
    case BudgetPeriod.daily:
      final d = _iso(day);
      return EnvelopeWindow(d, d);
    case BudgetPeriod.weekly:
      final start = day.subtract(Duration(days: day.weekday - 1));
      return EnvelopeWindow(_iso(start), _iso(start.add(const Duration(days: 6))));
    case BudgetPeriod.monthly:
    case BudgetPeriod.custom:
    case BudgetPeriod.once:
      final start = DateTime(day.year, day.month, 1);
      final end = DateTime(day.year, day.month + 1, 0);
      return EnvelopeWindow(_iso(start), _iso(end));
  }
}

/// Предыдущий отрезок того же периода.
EnvelopeWindow previousWindow(BudgetPeriod period, DateTime day) {
  switch (period) {
    case BudgetPeriod.daily:
      return windowOf(period, day.subtract(const Duration(days: 1)));
    case BudgetPeriod.weekly:
      return windowOf(period, day.subtract(const Duration(days: 7)));
    case BudgetPeriod.monthly:
    case BudgetPeriod.custom:
    case BudgetPeriod.once:
      return windowOf(BudgetPeriod.monthly,
          DateTime(day.year, day.month, 1).subtract(const Duration(days: 1)));
  }
}

/// Состояние конверта.
class Envelope {
  final Budget budget;
  final EnvelopeWindow window;

  /// Истрачено в нынешнем отрезке.
  final double spent;

  /// Перенесено с прошлых отрезков: плюс — сэкономленное, минус — перерасход.
  final double carried;

  const Envelope({
    required this.budget,
    required this.window,
    required this.spent,
    required this.carried,
  });

  /// Сколько можно тратить в этом отрезке с учётом переноса.
  double get allowance => _round2(budget.limit + carried);

  /// Сколько осталось. Отрицательное — перерасход.
  double get left => _round2(allowance - spent);

  double get share => allowance <= 0 ? 1 : (spent / allowance).clamp(0.0, 1.0);

  bool get over => left < -0.005;
}

/// Считается ли трата в этом бюджете.
///
/// Категорий у бюджета бывает НЕСКОЛЬКО: «Машина» — это бензин, мойка и
/// страховка вместе, по отдельности человек их не планирует. И счета бывают
/// свои: бюджет на командировки считает только служебную карту.
bool budgetCovers(Budget budget, Transaction t) {
  if (t.hidden || t.kind != TxKind.expense) return false;
  if (!budget.categories.contains(t.category)) return false;
  // Подкатегория сужает ТОЛЬКО главную категорию: «Продукты · Кофе» плюс
  // «Кафе» целиком — обычный бюджет на кофе.
  final sub = budget.subcategory;
  if (sub != null && sub.isNotEmpty && t.category == budget.category &&
      t.subcategory != sub) {
    return false;
  }
  if (budget.accounts.isNotEmpty && !budget.accounts.contains(t.account)) {
    return false;
  }
  return true;
}

/// Истрачено по лимиту в заданном отрезке, в валюте лимита.
double spentIn(Database db, Budget budget, EnvelopeWindow window) {
  var sum = 0.0;
  for (final t in db.transactions) {
    if (!budgetCovers(budget, t)) continue;
    if (!window.contains(t.date)) continue;
    sum += convert(db, t.amount, t.currency).abs() / rateOf(db, budget.currency);
  }
  return _round2(sum);
}

/// Конверт на сегодня с переносом из ПРОШЛОГО отрезка.
///
/// Переносится ровно один отрезок, и это решение, а не упрощение. Складывать
/// экономию за полгода нельзя по двум причинам: во-первых, у только что
/// заведённого конверта «перенос» из тех недель, когда его не было, — деньги
/// из воздуха; во-вторых, «осталось 12 000» вместо недельной тысячи убивает
/// сам смысл предела. [depth] оставлен для расчётов и тестов.
Envelope envelopeOf(Database db, Budget budget, {DateTime? today, int depth = 1}) {
  final day = today ?? DateTime.now();
  final window = windowFor(budget, day);
  final spent = spentIn(db, budget, window);

  if (!budget.rollover) {
    return Envelope(budget: budget, window: window, spent: spent, carried: 0);
  }

  var carried = 0.0;
  var cursor = day;
  for (var i = 0; i < depth; i++) {
    final past = previousWindowFor(budget, cursor);
    if (past == null) break;
    final was = spentIn(db, budget, past);
    // В отрезке, где по этой категории не было НИ ОДНОЙ траты, конверта,
    // скорее всего, ещё не существовало: переносить оттуда целый лимит
    // значило бы выдать человеку деньги, которых он не экономил.
    if (was <= 0.005) break;
    carried += budget.limit - was;
    cursor = DateTime.parse(past.from);
  }
  return Envelope(
    budget: budget,
    window: window,
    spent: spent,
    carried: _round2(carried),
  );
}
