import '../data/models.dart';
import 'money.dart';

/// Запрос к базе от лица модели: она говорит, что ей нужно, а считает
/// приложение. Операции наружу не уходят — уходит ответ на заданный вопрос.
class DataQuery {
  final String what; // операции | категории | месяцы | счета
  final String? account;
  final String? category;
  final String? subcategory;
  final String? from;
  final String? to;
  final String? search;
  final String? side; // расход | доход | все
  final int limit;

  const DataQuery({
    required this.what,
    this.account,
    this.category,
    this.subcategory,
    this.from,
    this.to,
    this.search,
    this.side,
    this.limit = 20,
  });

  factory DataQuery.fromJson(Map<String, dynamic> j) => DataQuery(
        what: (j['что'] ?? j['what'] ?? 'операции').toString(),
        account: j['счёт']?.toString() ?? j['счет']?.toString(),
        category: j['категория']?.toString(),
        subcategory: j['подкатегория']?.toString(),
        from: j['с']?.toString(),
        to: j['по']?.toString(),
        search: j['поиск']?.toString(),
        side: j['вид']?.toString(),
        limit: (j['сколько'] as num?)?.toInt() ?? 20,
      );

  Map<String, dynamic> toJson() => {
        'что': what,
        if (account != null) 'счёт': account,
        if (category != null) 'категория': category,
        if (subcategory != null) 'подкатегория': subcategory,
        if (from != null) 'с': from,
        if (to != null) 'по': to,
        if (search != null) 'поиск': search,
        if (side != null) 'вид': side,
        'сколько': limit,
      };
}

class QueryResult {
  final List<Transaction> rows;
  final String text;
  final String title;
  final double total;
  final ({String? category, String from, String to})? filter;
  const QueryResult({
    required this.rows, required this.text, required this.title,
    required this.total, this.filter,
  });
}

const _limit = 50;

QueryResult runQuery(Database db, DataQuery q) {
  String money(double v) => '${v.round()} ${db.baseCurrency}';
  final low = q.search?.trim().toLowerCase();

  final found = db.transactions.where((t) {
    if (t.kind == TxKind.transfer || t.hidden) return false;
    if (q.from != null && t.date.compareTo(q.from!) < 0) return false;
    if (q.to != null && t.date.compareTo(q.to!) > 0) return false;
    if (q.account != null && t.account != q.account) return false;
    if (q.category != null && t.category != q.category) return false;
    if (q.subcategory != null && t.subcategory != q.subcategory) return false;
    if (q.side == 'расход' && t.amount >= 0) return false;
    if (q.side == 'доход' && t.amount <= 0) return false;
    if (low != null && low.isNotEmpty &&
        ![t.note, t.category, t.subcategory, t.account]
            .any((v) => (v ?? '').toLowerCase().contains(low))) {
      return false;
    }
    return true;
  }).toList();

  final total = found.fold<double>(0, (s, t) => s + convert(db, t.amount, t.currency));
  final dates = found.map((t) => t.date).toList()..sort();
  final range = (
    category: q.category,
    from: q.from ?? (dates.isEmpty ? '1970-01-01' : dates.first),
    to: q.to ?? (dates.isEmpty ? '2999-12-31' : dates.last),
  );
  final label = [q.category ?? q.subcategory ?? q.search ?? q.account]
      .whereType<String>()
      .join(' · ');

  if (q.what == 'категории') {
    final sums = <String, ({double sum, int count, String last})>{};
    for (final t in found) {
      final base = convert(db, t.amount, t.currency);
      final name = t.category ?? '—';
      final was = sums[name] ?? (sum: 0.0, count: 0, last: '');
      sums[name] = (
        sum: was.sum + base,
        count: was.count + 1,
        last: t.date.compareTo(was.last) > 0 ? t.date : was.last,
      );
    }
    final rows = sums.entries.toList()
      ..sort((a, b) => b.value.sum.abs().compareTo(a.value.sum.abs()));
    return QueryResult(
      rows: const [], total: total, title: 'По категориям', filter: range,
      text: rows.isEmpty
          ? 'Ничего не нашлось.'
          : rows.take(25).map((e) =>
              '${e.key}: ${money(e.value.sum)} за ${e.value.count}, последняя ${e.value.last}').join('\n'),
    );
  }

  if (q.what == 'месяцы') {
    final sums = <String, ({double plus, double minus})>{};
    for (final t in found) {
      final key = t.date.substring(0, 7);
      final was = sums[key] ?? (plus: 0.0, minus: 0.0);
      final base = convert(db, t.amount, t.currency);
      sums[key] = base < 0
          ? (plus: was.plus, minus: was.minus - base)
          : (plus: was.plus + base, minus: was.minus);
    }
    final keys = sums.keys.toList()..sort();
    return QueryResult(
      rows: const [], total: total, title: 'По месяцам', filter: range,
      text: keys.isEmpty
          ? 'Ничего не нашлось.'
          : keys.map((k) =>
              '$k: доход ${sums[k]!.plus.round()}, расход ${sums[k]!.minus.round()}').join('\n'),
    );
  }

  if (q.what == 'счета') {
    final list = balances(db);
    return QueryResult(
      rows: const [], total: totalBase(list), title: 'Счета',
      text: list.map((a) => '${a.name}: ${money(a.converted)}').join('\n'),
    );
  }

  final rows = (found..sort((a, b) => b.date.compareTo(a.date)))
      .take(q.limit > _limit ? _limit : q.limit)
      .toList();
  return QueryResult(
    rows: rows, total: total, filter: range,
    title: label.isEmpty ? 'Найденное' : label,
    text: rows.isEmpty
        ? 'Ничего не нашлось.'
        : [
            'Найдено ${found.length}, показаны ${rows.length}. Итог ${money(total)}.',
            ...rows.map((t) =>
                '${t.date} ${t.account} ${t.category ?? '—'}'
                '${t.subcategory != null ? ' · ${t.subcategory}' : ''} '
                '${convert(db, t.amount, t.currency).round()} ${db.baseCurrency}'
                '${t.note != null ? ' (${t.note!.length > 50 ? t.note!.substring(0, 50) : t.note})' : ''}'),
          ].join('\n'),
  );
}
