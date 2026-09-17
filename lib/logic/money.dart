import '../data/models.dart';
import 'currencies.dart';

const goalPrefix = 'Цель: ';
bool isGoalAccount(String name) => name.startsWith(goalPrefix);

/// Счёт долга. Живёт тем же приёмом, что счёт цели: платежи видно в истории, а
/// «осталось» считается из них, а не из числа, которое кто-то забыл поправить.
const debtPrefix = 'Долг: ';
bool isDebtAccount(String name) => name.startsWith(debtPrefix);
String debtAccountOf(String name) => '$debtPrefix$name';
String debtNameOf(String account) =>
    account.startsWith(debtPrefix) ? account.substring(debtPrefix.length) : account;

/// Служебный счёт: цель или долг. В списке кошельков их нет, в расходы и
/// доходы они не попадают — это места, куда деньги переложили, а не потратили.
/// Счёт-расчёт: «платил из своих».
///
/// Появляется, когда человек платит за ДРУГУЮ пару со счёта, который к ней не
/// относится: карта общая с Аней, а обед куплен Кириллу. Пара с Кириллом
/// обязана увидеть трату — иначе долг не посчитать, — но чужой счёт ей знать
/// незачем и нельзя. Поэтому в её хранилище запись ложится на такой счёт: он
/// не входит ни в один остаток и живёт ровно ради расчёта между людьми.
/// Счёт расчёта: «мы рассчитались».
///
/// Долг между людьми гасится передачей денег, и она часто идёт мимо
/// приложения — наличными или переводом с карты на карту, которой тут нет.
/// Поэтому расчёт не двигает остатки, а только обнуляет сальдо. Так же
/// устроен «settle up» у Splitwise.
const settlePrefix = 'Расчёт: ';
bool isSettleAccount(String name) => name.startsWith(settlePrefix);

const outsidePrefix = 'Свои деньги: ';
bool isOutsideAccount(String name) => name.startsWith(outsidePrefix);
String outsideAccountOf(String who) => '$outsidePrefix$who';

bool isVirtualAccount(String name) =>
    isGoalAccount(name) ||
    isDebtAccount(name) ||
    isOutsideAccount(name) ||
    isSettleAccount(name);

/// Остаток по счёту. Валюты одного счёта складывать нельзя: на Togetherly+
/// лежат рубли, доллары и леи одновременно, и «сумма» из них — выдумка.
class AccountBalance {
  final String name;
  final List<({String currency, double amount})> byCurrency;
  final String mainCurrency;
  final double mainAmount;
  /// Всё вместе, пересчитанное в базовую по текущему курсу.
  final double converted;
  final bool multiCurrency;
  final int operations;

  const AccountBalance({
    required this.name, required this.byCurrency, required this.mainCurrency,
    required this.mainAmount, required this.converted, required this.multiCurrency,
    required this.operations,
  });
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Сколько базовой валюты стоит единица `code`.
///
/// Порядок такой: курс, заданный человеком или приехавший с сервера, — потом
/// встроенная таблица на день сборки. Единица остаётся последним ответом и
/// значит «такой валюты мы не знаем вовсе»: раньше она была ПЕРВЫМ ответом, и
/// зарплата в долларах превращалась в столько же леев.
double rateOf(Database db, String code) {
  if (code == db.baseCurrency) return 1;
  final r = db.rates[code];
  if (r != null && r > 0) return r;
  final fallback = fallbackRate(code, db.baseCurrency);
  return fallback > 0 ? fallback : 1;
}

double convert(Database db, double amount, String from) => amount * rateOf(db, from);

/// Остатки считаются в родной валюте каждого счёта, в базовую переводятся по
/// текущему курсу — так история не врёт при скачках курса. Виртуальные счета
/// целей в список не попадают.
List<AccountBalance> balances(Database db) {
  final acc = <String, Map<String, double>>{};
  final count = <String, int>{};

  for (final t in db.transactions) {
    if (isVirtualAccount(t.account)) continue;
    final m = acc.putIfAbsent(t.account, () => {});
    m[t.currency] = (m[t.currency] ?? 0) + t.amount;
    count[t.account] = (count[t.account] ?? 0) + 1;
  }
  // Счёт без единой операции тоже виден: его завели, значит он есть.
  for (final a in db.accounts) {
    if (isVirtualAccount(a.name)) continue;
    acc.putIfAbsent(a.name, () => {a.currency: 0});
  }

  final out = <AccountBalance>[];
  acc.forEach((name, m) {
    final byCurrency = m.entries
        .map((e) => (currency: e.key, amount: _round2(e.value)))
        .where((c) => c.amount.abs() >= 0.005 || m.length == 1)
        .toList()
      ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
    if (byCurrency.isEmpty) return;

    final converted = _round2(byCurrency.fold<double>(
        0, (sum, c) => sum + convert(db, c.amount, c.currency)));
    out.add(AccountBalance(
      name: name,
      byCurrency: byCurrency,
      mainCurrency: byCurrency.first.currency,
      mainAmount: byCurrency.first.amount,
      converted: converted,
      multiCurrency: byCurrency.length > 1,
      operations: count[name] ?? 0,
    ));
  });

  out.sort((a, b) => b.converted.abs().compareTo(a.converted.abs()));
  return out;
}

/// Сколько отложено на целях: виртуальные счета считаются отдельной строкой.
double goalsTotal(Database db) => db.transactions
    .where((t) => isGoalAccount(t.account))
    .fold<double>(0, (sum, t) => sum + convert(db, t.amount, t.currency));

double totalBase(List<AccountBalance> list) =>
    _round2(list.fold<double>(0, (sum, a) => sum + a.converted));

/// Итоги по валютам поверх всех счетов: под общей суммой видно, из чего она.
List<({String currency, double amount})> currencyTotals(List<AccountBalance> list) {
  final sums = <String, double>{};
  for (final a in list) {
    for (final c in a.byCurrency) {
      sums[c.currency] = (sums[c.currency] ?? 0) + c.amount;
    }
  }
  final out = sums.entries
      .map((e) => (currency: e.key, amount: _round2(e.value)))
      .where((c) => c.amount.abs() >= 0.005)
      .toList()
    ..sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));
  return out;
}

const _symbols = {
  'USD': r'$', 'EUR': '€', 'RUB': '₽', 'UAH': '₴', 'GBP': '£', 'RON': 'lei', 'PLN': 'zł',
};
String symbolOf(String code) => _symbols[code] ?? code;

/// 15768.69 → «15 768,69»: тонкий неразрывный пробел в тысячах, запятая в
/// дробной части. Минус настоящий, не дефис.
String formatAmount(double v, {int decimals = 2, bool sign = false}) {
  final parts = v.abs().toStringAsFixed(decimals).split('.');
  final digits = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    // Разделитель — ОБЫЧНЫЙ неразрывный пробел, а не узкий (U+202F):
    // Unbounded, которым набраны крупные числа в кварталах и на карточках,
    // узкого глифа не имеет, и миллиард слипался в «987654321».
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('\u00A0');
    buf.write(digits[i]);
  }
  final body = parts.length > 1 ? '$buf,${parts[1]}' : buf.toString();
  return (v < 0 ? '−' : sign ? '+' : '') + body;
}

/// Делит сумму на крупную часть и мелкий хвост: «15 767» и «,97».
({String head, String tail}) splitAmount(double v, {int decimals = 2, bool sign = false}) {
  final s = formatAmount(v, decimals: decimals, sign: sign);
  final i = s.lastIndexOf(',');
  return i < 0 ? (head: s, tail: '') : (head: s.substring(0, i), tail: s.substring(i));
}

/// Обратное [formatAmount]: «15 767,97» и «15767.97» дают одно число.
double? parseAmount(String text) {
  final clean = text
      .replaceAll(RegExp(r'[\s  ]'), '')
      .replaceAll('−', '-')
      .replaceAll(',', '.');
  if (!RegExp(r'^-?\d+(\.\d+)?$').hasMatch(clean)) return null;
  return (double.parse(clean) * 100).roundToDouble() / 100;
}

/// Операции счёта: свежие сверху.
List<Transaction> operationsOf(Database db, String account) =>
    db.transactions.where((t) => t.account == account).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
