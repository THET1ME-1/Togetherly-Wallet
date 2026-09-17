import '../data/models.dart';
import '../l10n/strings.dart';
import 'money.dart';
import 'period.dart';

/// Счёт по базе за отрезок. Всё, что рисуют главная, категории и статистика,
/// приходит отсюда: экраны только раскладывают числа, а не считают их сами —
/// иначе одна и та же сумма выходит разной на двух вкладках.

/// Отбор поверх периода: пустой набор значит «все».
/// Чьи деньги показывать. У одиночки разреза нет вовсе, у пары он главный:
/// «сколько ушло из общего» и «сколько я потратил своего» — разные вопросы,
/// и один ответ на оба ничего не объясняет.
enum MoneyScope { all, shared, mine }

class Filter {
  final Set<String> accounts;
  final Set<String> categories;
  final Set<TxKind> kinds;
  final String search;

  /// Разрез по владельцу счёта. Считается вместе с `viewer`: без него
  /// «моё личное» неотличимо от «личного партнёра», которого тут и нет —
  /// чужие личные счета на устройство не приезжают.
  final MoneyScope scope;
  final String viewer;

  /// Чьи операции показывать: uid плательщиков. Пусто — всех, и это
  /// умолчание: история у пары общая, разделение по людям человек включает
  /// сам, когда ему нужно.
  final Set<String> people;

  const Filter({
    this.accounts = const {},
    this.categories = const {},
    this.kinds = const {},
    this.search = '',
    this.scope = MoneyScope.all,
    this.viewer = '',
    this.people = const {},
  });

  bool get isEmpty =>
      accounts.isEmpty &&
      categories.isEmpty &&
      kinds.isEmpty &&
      people.isEmpty &&
      search.trim().isEmpty;

  int get count =>
      accounts.length +
      categories.length +
      kinds.length +
      people.length +
      (search.trim().isEmpty ? 0 : 1);

  Filter copyWith({
    Set<String>? accounts,
    Set<String>? categories,
    Set<TxKind>? kinds,
    String? search,
    MoneyScope? scope,
    String? viewer,
    Set<String>? people,
  }) =>
      Filter(
        accounts: accounts ?? this.accounts,
        categories: categories ?? this.categories,
        kinds: kinds ?? this.kinds,
        search: search ?? this.search,
        scope: scope ?? this.scope,
        viewer: viewer ?? this.viewer,
        people: people ?? this.people,
      );

  /// Разрез применяется ОТДЕЛЬНО от прочих условий: ему нужен список счетов,
  /// а `allows` знает только саму операцию.
  bool allowsScope(Transaction t, Database db) {
    if (scope == MoneyScope.all) return true;
    final at = db.accounts.indexWhere((a) => a.name == t.account);
    if (at < 0) return scope == MoneyScope.shared;
    final account = db.accounts[at];
    return switch (scope) {
      MoneyScope.shared => account.isShared,
      MoneyScope.mine => !account.isShared && account.owner == viewer,
      MoneyScope.all => true,
    };
  }

  bool allows(Transaction t) {
    if (people.isNotEmpty && !people.contains(t.payer ?? t.author ?? '')) return false;
    if (accounts.isNotEmpty && !accounts.contains(t.account)) return false;
    // Отбор принимает и подкатегорию: она такая же строка в том же наборе, и
    // человек, выбравший «Кофе», ждёт кофе, а не все продукты.
    if (categories.isNotEmpty &&
        !categories.contains(t.category ?? '') &&
        !categories.contains(t.subcategory ?? '')) {
      return false;
    }
    if (kinds.isNotEmpty && !kinds.contains(t.kind)) return false;
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [t.note, t.category, t.subcategory, t.account]
        .any((v) => (v ?? '').toLowerCase().contains(q));
  }
}

/// Порядок в ленте.
///
/// «Сначала крупные» отвечает на самый частый вопрос к трекеру — «куда ушли
/// деньги»: по дням это видно плохо, а по сумме сразу. День при таком порядке
/// перестаёт группировать: сортировка по сумме внутри дней читалась бы как
/// поломка.
enum LedgerSort { dateDesc, dateAsc, amountDesc, amountAsc }

String ledgerSortTitle(LedgerSort s) => switch (s) {
      LedgerSort.dateDesc => tr('sortNewest'),
      LedgerSort.dateAsc => tr('sortOldest'),
      LedgerSort.amountDesc => tr('sortBiggest'),
      LedgerSort.amountAsc => tr('sortSmallest'),
    };

bool ledgerSortByDay(LedgerSort s) =>
    s == LedgerSort.dateDesc || s == LedgerSort.dateAsc;

/// Операции отрезка, которые видит человек. Выравнивания остатка спрятаны:
/// они правят баланс, но в ленте выглядят как чужая операция.
List<Transaction> visible(
  Database db,
  Period period, {
  Filter filter = const Filter(),
  LedgerSort sort = LedgerSort.dateDesc,
}) {
  final out = db.transactions
      .where((t) =>
          !t.hidden &&
          !isVirtualAccount(t.account) &&
          period.contains(t.date) &&
          filter.allows(t) &&
          filter.allowsScope(t, db))
      .toList();

  // Внутри одного дня порядок держит время: две покупки подряд обязаны стоять
  // так, как их сделали, а не так, как легли в файл. У записи без времени —
  // полночь, и она стоит в начале дня.
  int byMoment(Transaction a, Transaction b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.at.compareTo(b.at);
  }

  switch (sort) {
    case LedgerSort.dateDesc:
      out.sort((a, b) => byMoment(b, a));
    case LedgerSort.dateAsc:
      out.sort(byMoment);
    case LedgerSort.amountDesc:
      // Сравниваем по величине в базовой валюте: иначе тысяча лей окажется
      // «крупнее» сотни евро.
      out.sort((a, b) => convert(db, b.amount, b.currency)
          .abs()
          .compareTo(convert(db, a.amount, a.currency).abs()));
    case LedgerSort.amountAsc:
      out.sort((a, b) => convert(db, a.amount, a.currency)
          .abs()
          .compareTo(convert(db, b.amount, b.currency).abs()));
  }
  return out;
}

/// Доход, расход и итог. Переводы и открывающие остатки в поток не входят:
/// деньги внутри своих счетов не появляются и не исчезают.
class CashFlow {
  final double income;
  final double expense;
  const CashFlow(this.income, this.expense);

  double get total => income - expense;
  bool get isEmpty => income == 0 && expense == 0;
}

bool _isCashFlow(Transaction t) =>
    t.kind == TxKind.income || t.kind == TxKind.expense;

CashFlow cashflow(Database db, Period period, {Filter filter = const Filter()}) {
  var income = 0.0;
  var expense = 0.0;
  for (final t in db.transactions) {
    if (t.hidden || isVirtualAccount(t.account)) continue;
    if (!_isCashFlow(t)) continue;
    if (!period.contains(t.date)) continue;
    if (!filter.allows(t) || !filter.allowsScope(t, db)) continue;
    final v = convert(db, t.amount, t.currency);
    if (v >= 0) {
      income += v;
    } else {
      expense += -v;
    }
  }
  return CashFlow(income, expense);
}

/// Доля категории в расходе или доходе за отрезок.
class CategorySlice {
  final String name;
  final double sum;
  final int count;
  final double share; // 0..1
  const CategorySlice(this.name, this.sum, this.count, this.share);
}

/// [income] = true — доходные категории, иначе расходные. Суммы положительные:
/// знак несёт сама сторона, и рисовать долю от отрицательного числа неудобно.
/// Порядок среза по категориям.
enum SliceSort { sum, name, count }

String sliceSortTitle(SliceSort s) => switch (s) {
      SliceSort.sum => tr('sortByAmount'),
      SliceSort.name => tr('sortByName'),
      SliceSort.count => tr('sortByCount'),
    };

List<CategorySlice> byCategory(
  Database db,
  Period period, {
  required bool income,
  Filter filter = const Filter(),
  SliceSort sort = SliceSort.sum,
}) {
  final sums = <String, ({double sum, int count})>{};
  for (final t in db.transactions) {
    if (t.hidden || isVirtualAccount(t.account)) continue;
    if (!_isCashFlow(t)) continue;
    if (!period.contains(t.date)) continue;
    if (!filter.allows(t) || !filter.allowsScope(t, db)) continue;
    final v = convert(db, t.amount, t.currency);
    if (income ? v <= 0 : v >= 0) continue;
    final name = (t.category ?? '').trim().isEmpty ? tr('noCategory') : t.category!;
    final was = sums[name] ?? (sum: 0.0, count: 0);
    sums[name] = (sum: was.sum + v.abs(), count: was.count + 1);
  }
  final total = sums.values.fold<double>(0, (s, e) => s + e.sum);
  final out = sums.entries
      .map((e) => CategorySlice(
            e.key,
            e.value.sum,
            e.value.count,
            total == 0 ? 0 : e.value.sum / total,
          ))
      .toList();

  switch (sort) {
    case SliceSort.sum:
      out.sort((a, b) => b.sum.compareTo(a.sum));
    case SliceSort.name:
      // Русские буквы сравниваются по коду, а не по алфавиту, поэтому
      // сравнение идёт по строчной форме: иначе «Еда» и «еда» разъезжаются.
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SliceSort.count:
      out.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : b.sum.compareTo(a.sum);
      });
  }
  return out;
}

/// Точка графика: день и значение в базовой валюте.
class Point {
  final DateTime date;
  final double value;
  const Point(this.date, this.value);
}

/// Ряд по дням отрезка. Дни без операций дают ноль, иначе график врёт наклоном
/// в пропусках.
List<Point> daily(
  Database db,
  Period period, {
  required bool income,
  bool net = false,
  Filter filter = const Filter(),
}) {
  final span = _span(db, period);
  if (span == null) return const [];
  final sums = <String, double>{};
  for (final t in db.transactions) {
    if (t.hidden || isVirtualAccount(t.account)) continue;
    if (!_isCashFlow(t)) continue;
    if (!period.contains(t.date)) continue;
    if (!filter.allows(t) || !filter.allowsScope(t, db)) continue;
    final v = convert(db, t.amount, t.currency);
    if (!net && (income ? v <= 0 : v >= 0)) continue;
    sums[t.date] = (sums[t.date] ?? 0) + (net ? v : v.abs());
  }
  return _walk(span, (d) => Point(d, sums[iso(d)] ?? 0));
}

/// Остаток на конец каждого дня отрезка: сумма всего, что было до этого дня
/// включительно. Так график показывает деньги, а не движение.
List<Point> balanceSeries(
  Database db,
  Period period, {
  /// Счета, которые входят в баланс. Пусто — все: человек смотрит общий
  /// баланс, а отбор включает сам.
  Set<String> accounts = const {},
}) {
  final span = _span(db, period);
  if (span == null) return const [];
  final byDay = <String, double>{};
  var before = 0.0;
  for (final t in db.transactions) {
    if (isVirtualAccount(t.account)) continue;
    if (accounts.isNotEmpty && !accounts.contains(t.account)) continue;
    final v = convert(db, t.amount, t.currency);
    if (t.date.compareTo(iso(span.from)) < 0) {
      before += v;
    } else if (t.date.compareTo(iso(span.to)) <= 0) {
      byDay[t.date] = (byDay[t.date] ?? 0) + v;
    }
  }
  var running = before;
  return _walk(span, (d) {
    running += byDay[iso(d)] ?? 0;
    return Point(d, running);
  });
}

/// Средние за день, неделю и месяц отрезка.
class Averages {
  final double perDay;
  final double perWeek;
  final double perMonth;
  const Averages(this.perDay, this.perWeek, this.perMonth);

  factory Averages.of(double total, int days) {
    if (days <= 0) return const Averages(0, 0, 0);
    final d = total / days;
    return Averages(d, d * 7, d * 30.44);
  }
}

/// Границы отрезка, обрезанные по данным: «всё время» иначе тянется от 1970
/// года и график вырождается в точку у правого края.
({DateTime from, DateTime to})? _span(Database db, Period period) {
  var from = period.from;
  var to = period.to;
  if (period.kind == PeriodKind.all) {
    final dates = db.transactions
        .where((t) => !isVirtualAccount(t.account))
        .map((t) => t.date)
        .toList()
      ..sort();
    if (dates.isEmpty) return null;
    from = DateTime.parse(dates.first);
    to = DateTime.parse(dates.last);
  }
  final today = dayOf(DateTime.now());
  if (to.isAfter(today) && period.kind != PeriodKind.custom) to = today;
  if (to.isBefore(from)) to = from;
  // Ряд длиной в годы не нужен подробнее месяца: точек больше, чем пикселей.
  final maxDays = 400;
  if (to.difference(from).inDays > maxDays) {
    from = to.subtract(Duration(days: maxDays));
  }
  return (from: from, to: to);
}

List<Point> _walk(({DateTime from, DateTime to}) span, Point Function(DateTime) make) {
  final out = <Point>[];
  for (var d = span.from; !d.isAfter(span.to); d = d.add(const Duration(days: 1))) {
    out.add(make(d));
  }
  return out;
}

/// Операции, сгруппированные по дню: лента рисует заголовок дня с итогом.
class DayGroup {
  final String date;
  final List<Transaction> rows;
  final double total;
  const DayGroup(this.date, this.rows, this.total);
}

List<DayGroup> groupByDay(Database db, List<Transaction> rows) {
  final byDate = <String, List<Transaction>>{};
  for (final t in rows) {
    byDate.putIfAbsent(t.date, () => []).add(t);
  }
  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
  return dates.map((d) {
    final list = byDate[d]!;
    final total = list
        .where(_isCashFlow)
        .fold<double>(0, (s, t) => s + convert(db, t.amount, t.currency));
    return DayGroup(d, list, total);
  }).toList();
}
