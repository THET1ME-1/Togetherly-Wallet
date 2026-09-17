import '../data/models.dart';

/// Забытые подписки: повторяющиеся списания, которых нет в регулярных.
///
/// Приём из Rocket Money и PocketGuard: приложение видит, что одна и та же
/// сумма уходит каждый месяц одному и тому же получателю, и спрашивает —
/// точно ли она ещё нужна. Человек про половину таких списаний не помнит.

/// Найденная подписка.
class Subscription {
  /// Кому платят: заметка или категория.
  final String name;

  /// Сколько уходит за раз, в валюте записи.
  final double amount;
  final String currency;

  /// Сколько раз подряд списывали.
  final int times;

  /// Когда списали в последний раз.
  final String lastDate;

  const Subscription({
    required this.name,
    required this.amount,
    required this.currency,
    required this.times,
    required this.lastDate,
  });
}

String _key(Transaction t) {
  final note = (t.note ?? '').trim();
  return note.isEmpty ? (t.category ?? '').trim() : note;
}

/// Подписки, которых нет в регулярных записях.
///
/// Правило: три и больше списаний одному получателю, сумма гуляет не больше
/// чем на пять процентов, шаг между ними похож на месяц (от 25 до 35 дней), и
/// последнее было не позже, чем сорок дней назад. Всё это — чтобы кофе по
/// вторникам не назвался подпиской.
List<Subscription> subscriptionsOf(Database db, {DateTime? today}) {
  final day = today ?? DateTime.now();
  final known = {
    for (final r in db.recurring) r.name.trim().toLowerCase(),
  };

  final groups = <String, List<Transaction>>{};
  for (final t in db.transactions) {
    if (t.kind != TxKind.expense || t.hidden) continue;
    final key = _key(t);
    if (key.isEmpty) continue;
    (groups[key] ??= []).add(t);
  }

  final out = <Subscription>[];
  for (final e in groups.entries) {
    if (known.contains(e.key.toLowerCase())) continue;
    final list = [...e.value]..sort((a, b) => a.date.compareTo(b.date));
    if (list.length < 3) continue;

    final amounts = list.map((t) => t.amount.abs()).toList();
    final first = amounts.first;
    if (first <= 0) continue;
    final steady = amounts.every((v) => (v - first).abs() / first <= 0.05);
    if (!steady) continue;

    var monthly = true;
    for (var i = 1; i < list.length; i++) {
      final a = DateTime.tryParse(list[i - 1].date);
      final b = DateTime.tryParse(list[i].date);
      if (a == null || b == null) {
        monthly = false;
        break;
      }
      final gap = b.difference(a).inDays;
      if (gap < 25 || gap > 35) {
        monthly = false;
        break;
      }
    }
    if (!monthly) continue;

    final last = DateTime.tryParse(list.last.date);
    if (last == null || day.difference(last).inDays > 40) continue;

    out.add(Subscription(
      name: e.key,
      amount: first,
      currency: list.last.currency,
      times: list.length,
      lastDate: list.last.date,
    ));
  }

  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}
