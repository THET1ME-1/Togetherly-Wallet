import '../data/models.dart';

/// Пора ли пересматривать бюджет.
///
/// Обе статьи говорят одно: план надо пересматривать — раз в месяц или хотя
/// бы раз в квартал. Иначе он остаётся верным ровно до первой смены работы,
/// цен или привычек, и человек живёт по бумажке, которая уже врёт.

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Когда следующий пересмотр. Пусто — напоминать не просили.
String? reviewNext(Rules rules) {
  if (rules.reviewMonths <= 0) return null;
  final from = DateTime.tryParse(rules.reviewAt);
  if (from == null) return _iso(DateTime.now());
  final month = from.month + rules.reviewMonths;
  final year = from.year + (month - 1) ~/ 12;
  final m = (month - 1) % 12 + 1;
  final lastDay = DateTime(year, m + 1, 0).day;
  return _iso(DateTime(year, m, from.day > lastDay ? lastDay : from.day));
}

/// Пора ли сверяться.
bool reviewDue(Rules rules, {DateTime? today}) {
  final next = reviewNext(rules);
  if (next == null) return false;
  return _iso(today ?? DateTime.now()).compareTo(next) >= 0;
}

/// Отметка «сверились сегодня».
Rules markReviewed(Rules rules, {DateTime? today}) =>
    rules.copyWith(reviewAt: _iso(today ?? DateTime.now()));
