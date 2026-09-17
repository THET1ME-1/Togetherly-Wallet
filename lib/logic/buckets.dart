import '../data/models.dart';
import 'money.dart';
import 'period.dart';
import 'stats.dart';

/// Правило распределения дохода: нужды, желания, сбережения.
///
/// Оба разбора семейного бюджета сходятся на одном: доход делится на три
/// части, и полезно это только тогда, когда траты размечены. Разметку человек
/// правит руками, но начинать с пустого экрана нельзя — незнакомая категория
/// угадывается по имени, и это видно в интерфейсе.
///
/// Третья доля называется «сбережения и долги»: одна статья кладёт в 20%
/// резерв, вторая — резерв и платежи по кредитам. Платёж по долгу — это не
/// желание и не нужда, он уменьшает долг, то есть работает как сбережение.

const _needs = [
  'продукт', 'еда', 'магазин', 'аптек', 'лекарств', 'здоров', 'врач',
  'квартплат', 'коммунал', 'жкх', 'аренда', 'ипотек', 'кредит', 'долг',
  'транспорт', 'бензин', 'топлив', 'проезд', 'метро', 'автобус',
  'связь', 'интернет', 'телефон', 'школ', 'садик', 'детск', 'учеб',
  'одежд', 'обув', 'налог', 'страхов', 'дом', 'быт', 'уборк', 'ремонт',
];

const _wants = [
  'кафе', 'ресторан', 'бар', 'кофе', 'достав', 'фастфуд', 'пицц',
  'развлеч', 'кино', 'театр', 'концерт', 'игр', 'подар', 'хобби',
  'путешеств', 'отпуск', 'отель', 'красот', 'салон', 'маникюр',
  'подписк', 'сериал', 'музык', 'алког', 'сигарет', 'табак', 'спорт',
  'книг', 'техник', 'гаджет', 'сувенир', 'цвет',
];

const _savings = [
  'накоплен', 'сбереж', 'подушк', 'резерв', 'инвест', 'вклад', 'цель',
  'копилк', 'депозит',
];

/// Вид расхода по имени категории. Подсказка, а не приговор: человек меняет её
/// одним касанием, и его выбор хранится в самой категории.
Bucket bucketGuess(String category) {
  final low = category.toLowerCase();
  bool has(List<String> keys) => keys.any(low.contains);
  // Сбережения проверяются первыми: «цель» и «вклад» встречаются и в других
  // словах, но в имени категории они значат именно откладывание.
  if (has(_savings)) return Bucket.savings;
  if (has(_wants)) return Bucket.wants;
  if (has(_needs)) return Bucket.needs;
  return Bucket.none;
}

/// Вид расхода, с которым трата попадёт в расчёт: своя разметка сильнее
/// подсказки, у подкатегории берётся вид родителя.
Bucket effectiveBucket(Database db, String? category) {
  final name = (category ?? '').trim();
  if (name.isEmpty) return Bucket.none;
  final at = db.categories.indexWhere((c) => c.name == name);
  if (at >= 0) {
    final c = db.categories[at];
    if (c.bucket != Bucket.none) return c.bucket;
    final parent = (c.parent ?? '').trim();
    if (parent.isNotEmpty) {
      final up = db.categories.indexWhere((x) => x.name == parent);
      if (up >= 0 && db.categories[up].bucket != Bucket.none) {
        return db.categories[up].bucket;
      }
    }
  }
  return bucketGuess(name);
}

/// Сколько ушло в каждую долю и сколько было дохода.
class BucketSplit {
  final double income;
  final double needs;
  final double wants;

  /// Сбережения и платежи по долгам: та самая «двадцатка» из обеих статей.
  final double savings;

  /// Траты, которые не удалось отнести ни к чему. Прятать их нельзя: из них
  /// складывается разница между суммой долей и настоящим расходом.
  final double unknown;

  const BucketSplit({
    required this.income,
    required this.needs,
    required this.wants,
    required this.savings,
    required this.unknown,
  });

  double get expense => needs + wants + savings + unknown;

  /// Доля от дохода, 0..1. Считается от ДОХОДА, а не от расхода: правило
  /// 50/30/20 говорит, куда уходит заработанное, а не как поделён расход.
  double shareOf(double value) => income <= 0 ? 0 : value / income;

  /// Нераспределённый доход: то, что не потратили и не отложили.
  double get free {
    final rest = income - expense;
    return rest > 0 ? rest : 0;
  }
}

/// Доли за отрезок. Взносы в цели считаются сбережением: деньги ушли с
/// кошелька на счёт цели, и это ровно то, что правило называет «отложить».
BucketSplit bucketsOf(Database db, Period period, {Filter filter = const Filter()}) {
  var income = 0.0, needs = 0.0, wants = 0.0, savings = 0.0, unknown = 0.0;

  for (final t in db.transactions) {
    if (!period.contains(t.date)) continue;
    if (!filter.allowsScope(t, db)) continue;

    final base = convert(db, t.amount, t.currency).abs();

    // Перевод на счёт цели или долга — это сбережение, а не движение между
    // кошельками: с этого момента деньги перестали быть свободными.
    if (isVirtualAccount(t.account)) {
      if (t.amount > 0) savings += base;
      continue;
    }
    if (t.hidden) continue;

    switch (t.kind) {
      case TxKind.income:
        income += base;
      case TxKind.expense:
        switch (effectiveBucket(db, t.category)) {
          case Bucket.needs:
            needs += base;
          case Bucket.wants:
            wants += base;
          case Bucket.savings:
            savings += base;
          case Bucket.none:
            unknown += base;
        }
      case TxKind.transfer:
      case TxKind.opening:
        break;
    }
  }

  double r(double v) => (v * 100).roundToDouble() / 100;
  return BucketSplit(
    income: r(income),
    needs: r(needs),
    wants: r(wants),
    savings: r(savings),
    unknown: r(unknown),
  );
}

/// Сколько по правилу причитается каждой доле от этого дохода.
({double needs, double wants, double savings}) targetsOf(Rules rules, double income) => (
      needs: income * rules.needsBp / 10000,
      wants: income * rules.wantsBp / 10000,
      savings: income * rules.savingsBp / 10000,
    );

/// Категории, которые ещё не размечены человеком: у них вид взят подсказкой
/// или не найден вовсе. Экран правила показывает их списком — без разметки
/// правило считается по догадкам.
List<String> unmarkedCategories(Database db, Period period) {
  final marked = {
    for (final c in db.categories)
      if (c.bucket != Bucket.none) c.name,
  };
  final out = <String>{};
  for (final t in db.transactions) {
    if (t.kind != TxKind.expense || !period.contains(t.date)) continue;
    final name = (t.category ?? '').trim();
    if (name.isEmpty || marked.contains(name)) continue;
    out.add(name);
  }
  final list = out.toList()..sort();
  return list;
}
