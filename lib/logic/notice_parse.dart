import '../data/models.dart';

/// Разбор банковского уведомления.
///
/// Приложение читает пуш банка на устройстве и предлагает записать трату.
/// Текст уведомления НИКУДА не уезжает: разбор целиком локальный, на сервер
/// уходит только готовая операция — так требует и политика Play, и здравый
/// смысл про чужие деньги.
///
/// Разбор не по списку банков, а по форме текста. Список банков — это вечная
/// догонялка: у каждого банка десяток форматов, они меняются без спроса, а
/// приложение должно работать и в Молдове, и в России, и у Payoneer. Поэтому
/// правила общие: сумма с валютой, слово направления, четыре цифры карты,
/// остаток отдельно от суммы операции.

/// Что удалось понять из уведомления.
class ParsedNotice {
  /// Пакет приложения-источника: `md.maib.mobile`, `ru.sberbankmobile`…
  final String package;

  /// Заголовок и текст как пришли: нужны человеку, чтобы проверить разбор.
  final String title;
  final String body;

  /// Когда пришло, миллисекунды.
  final int at;

  /// Сумма операции, всегда положительная. Ноль — разобрать не удалось.
  final double amount;

  /// Валюта операции в трёхбуквенном коде.
  final String currency;

  /// Расход это или доход.
  final TxKind kind;

  /// Последние четыре цифры карты или счёта, если банк их назвал.
  final String? last4;

  /// Где потратили: магазин, перевод, снятие.
  final String? merchant;

  /// Остаток, который банк назвал в том же уведомлении. Нужен только чтобы
  /// НЕ спутать его с суммой операции.
  final double? balance;

  /// Уверенность разбора, 0..1. Ниже 0.5 показываем человеку, но не
  /// записываем сами даже в режиме «записывать сразу».
  final double confidence;

  const ParsedNotice({
    required this.package,
    required this.title,
    required this.body,
    required this.at,
    required this.amount,
    required this.currency,
    required this.kind,
    this.last4,
    this.merchant,
    this.balance,
    required this.confidence,
  });

  bool get ok => amount > 0 && confidence >= 0.5;

  /// Ключ против двойной записи: банк повторяет уведомление, а система
  /// пересылает его при каждом обновлении.
  String get fingerprint {
    final minute = at ~/ 60000;
    return '$package|${amount.toStringAsFixed(2)}|$currency|${last4 ?? ''}|$minute';
  }

  Map<String, dynamic> toJson() => {
        'package': package,
        'title': title,
        'body': body,
        'at': at,
        'amount': amount,
        'currency': currency,
        'kind': kind.name,
        if (last4 != null) 'last4': last4,
        if (merchant != null) 'merchant': merchant,
        if (balance != null) 'balance': balance,
        'confidence': confidence,
      };

  factory ParsedNotice.fromJson(Map<String, dynamic> j) => ParsedNotice(
        package: '${j['package'] ?? ''}',
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        at: (j['at'] as num?)?.toInt() ?? 0,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        currency: '${j['currency'] ?? 'MDL'}',
        kind: kindOf(j['kind'] as String?),
        last4: j['last4'] as String?,
        merchant: j['merchant'] as String?,
        balance: (j['balance'] as num?)?.toDouble(),
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Знаки и слова валют. Лей пишут и «MDL», и «lei», и одной буквой «L».
const _currencies = <String, String>{
  '₽': 'RUB', 'руб': 'RUB', 'р.': 'RUB', 'rub': 'RUB',
  'lei': 'MDL', 'mdl': 'MDL', 'л.': 'MDL',
  '€': 'EUR', 'eur': 'EUR',
  r'$': 'USD', 'usd': 'USD',
  '£': 'GBP', 'gbp': 'GBP',
  '₴': 'UAH', 'uah': 'UAH',
  '₸': 'KZT', 'kzt': 'KZT',
  '₾': 'GEL', 'gel': 'GEL',
  '₺': 'TRY', 'try': 'TRY',
  'ron': 'RON', 'lej': 'RON',
  'pln': 'PLN', 'zł': 'PLN',
};

/// Слова расхода. Румынские и английские нужны не для красоты: в Молдове
/// половина банков пишет по-румынски, Payoneer и Revolut — по-английски.
const _spendWords = [
  'списан', 'покупка', 'оплата', 'оплат', 'оплач', 'платеж', 'платёж',
  'снятие', 'снял', 'перевод', 'перечислен', 'выдача', 'взнос',
  'achitare', 'achitat', 'plata', 'plată', 'plati', 'retragere', 'cumparare',
  'cumpărare', 'tranzac', 'transfer',
  'spent', 'charged', 'debited', 'debit', 'withdraw', 'payment of',
  'purchase', 'you sent', 'paid',
];

/// Слова дохода.
const _incomeWords = [
  'зачислен', 'пополнен', 'поступлен', 'возврат', 'кэшбэк', 'кешбэк',
  'получен', 'начислен', 'приход',
  'incasare', 'încasare', 'alimentare', 'rambursare', 'primit', 'suplinire',
  'received', 'credited', 'refund', 'deposited', 'you got',
  'payment from', 'salary',
];

/// Слова остатка: сумма после них — НЕ сумма операции. Самая частая ошибка
/// такого разбора: записать доступный остаток как трату.
const _balanceWords = [
  'доступно', 'остаток', 'баланс', 'на счете', 'на счёте', 'доступный',
  'disponibil', 'balanta', 'balanță', 'sold',
  'balance', 'available', 'remaining',
];

/// Слова, после которых сумма — это лимит, комиссия или что-то ещё, но не
/// сама операция.
const _skipWords = ['комисси', 'comision', 'fee', 'лимит', 'limita', 'кэшбэк с'];

final _amountRe = RegExp(
  // Сумма и валюта в любом порядке: «137.40 MDL», «MDL 137.40», «-1 234,56 ₽».
  r'(?:(?<cur1>[₽$€£₴₸₾₺]|\b(?:MDL|RUB|USD|EUR|GBP|RON|UAH|KZT|GEL|TRY|PLN|lei|руб|rub)\b\.?)\s*)?'
  r'(?<sign>[-+−–])?\s*'
  r'(?<num>\d{1,3}(?:[    .,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)'
  r'(?:\s*(?<cur2>[₽$€£₴₸₾₺]|\b(?:MDL|RUB|USD|EUR|GBP|RON|UAH|KZT|GEL|TRY|PLN|lei|LEI|Lei|руб|руб\.|rub|L)\b\.?))?',
  caseSensitive: false,
);

final _last4Re = RegExp(
  r'(?:'
  r'\*{1,4}\s?(\d{4})'
  r'|(?:карт[аеыу]?|card|cont|счет|счёт|account)\s*(?:№|no\.?|nr\.?)?\s*\*{0,4}\s?(\d{4})'
  r'|ending\s+(?:in|with)\s+(\d{4})'
  r'|•{2,}\s?(\d{4})'
  r')',
  caseSensitive: false,
);

String _normalize(String raw) => raw
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ')
    .replaceAll(' ', ' ')
    .replaceAll('−', '-')
    .replaceAll('–', '-')
    .replaceAll(RegExp(r'[ \t]+'), ' ')
    .trim();

/// «1 234,56» и «1,234.56» дают одно число.
double? _number(String raw) {
  var s = raw.replaceAll(RegExp(r'[    ]'), '');
  final dot = s.lastIndexOf('.');
  final comma = s.lastIndexOf(',');
  if (dot >= 0 && comma >= 0) {
    // Разделитель — тот, что стоит правее: «1.234,56» и «1,234.56».
    final decimal = dot > comma ? '.' : ',';
    final thousands = decimal == '.' ? ',' : '.';
    s = s.replaceAll(thousands, '').replaceAll(decimal, '.');
  } else if (comma >= 0) {
    // Запятая с тремя цифрами после неё — разряд, а не копейки: «1,234».
    s = s.length - comma - 1 == 3 ? s.replaceAll(',', '') : s.replaceAll(',', '.');
  } else if (dot >= 0 && s.length - dot - 1 == 3) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

String? _currencyOf(String? token) {
  if (token == null) return null;
  final key = token.toLowerCase().replaceAll('.', '').trim();
  if (key.isEmpty) return null;
  if (key == 'l') return 'MDL';
  return _currencies[key] ?? (key.length == 3 ? key.toUpperCase() : null);
}

bool _hasAny(String low, List<String> words) => words.any(low.contains);

/// Где впервые встретилось любое из слов. −1 — ни одного.
int _firstOf(String low, List<String> words) {
  var best = -1;
  for (final w in words) {
    final at = low.indexOf(w);
    if (at >= 0 && (best < 0 || at < best)) best = at;
  }
  return best;
}

/// Есть ли слово из [words] в двадцати пяти знаках перед [at].
bool _before(String low, int at, List<String> words) {
  final from = at - 25 < 0 ? 0 : at - 25;
  final window = low.substring(from, at);
  return words.any(window.contains);
}

/// Разобрать уведомление. Возвращает разбор всегда — с нулевой суммой и
/// низкой уверенностью, если понять ничего не удалось: человек должен видеть,
/// что уведомление пришло, а не гадать, почему приложение молчит.
ParsedNotice parseNotice({
  required String package,
  required String title,
  required String body,
  required int at,
  String fallbackCurrency = 'MDL',
}) {
  final text = _normalize('$title. $body');
  final low = text.toLowerCase();

  double? amount;
  String? currency;
  double? balance;
  var signed = 0;

  for (final m in _amountRe.allMatches(text)) {
    final value = _number(m.namedGroup('num') ?? '');
    if (value == null || value == 0) continue;
    final cur = _currencyOf(m.namedGroup('cur1')) ?? _currencyOf(m.namedGroup('cur2'));
    final start = m.start;

    if (_before(low, start, _balanceWords)) {
      balance ??= value;
      continue;
    }
    if (_before(low, start, _skipWords)) continue;
    // Число без валюты годится только если валюту не нашли вовсе: иначе
    // «карта 1234» и «в 15:30» попадут в сумму.
    if (cur == null && amount != null) continue;
    if (cur == null && !RegExp(r'[.,]\d{2}$').hasMatch(m.namedGroup('num') ?? '')) {
      continue;
    }

    if (amount == null) {
      amount = value;
      currency = cur;
      final sign = m.namedGroup('sign');
      if (sign == '-') signed = -1;
      if (sign == '+') signed = 1;
    }
  }

  final last4Match = _last4Re.firstMatch(text);
  final last4 = last4Match == null
      ? null
      : (last4Match.group(1) ??
          last4Match.group(2) ??
          last4Match.group(3) ??
          last4Match.group(4));

  // Направление решает слово, которое стоит РАНЬШЕ: «You received a payment
  // of» — доход, «A payment of … was charged» — расход. Оба списка в таком
  // тексте срабатывают, и выигрывать должен первый.
  final spendAt = _firstOf(low, _spendWords);
  final incomeAt = _firstOf(low, _incomeWords);
  final bool income;
  if (signed != 0) {
    income = signed > 0;
  } else if (incomeAt >= 0 && spendAt >= 0) {
    income = incomeAt < spendAt;
  } else {
    income = incomeAt >= 0;
  }
  final known = signed != 0 || incomeAt >= 0 || spendAt >= 0;

  final merchant = _merchantOf(text, _normalize(body), title.trim());

  var confidence = 0.0;
  if (amount != null) confidence += 0.45;
  if (known) confidence += 0.3;
  if (last4 != null) confidence += 0.15;
  if (currency != null) confidence += 0.1;
  // Без направления это не операция, а реклама или код из СМС: «Кредит до
  // 100 000 MDL» суммой и валютой набирал проходной балл.
  //
  // Кроме одного случая: сумма, НОМЕР КАРТЫ и название магазина вместе. Так
  // пишут кошельки — «USM CONTABILITATEA · 4 500,00 MDL с карты Visa Classic
  // ••0354», и слова направления там нет ни на одном языке. У рекламы номера
  // карты не бывает, поэтому спутать не с чем. Потолок всё равно ниже 0,7:
  // молча такая трата не запишется, её подтверждает человек.
  if (!known) {
    final named = last4 != null && merchant != null;
    final cap = named ? 0.6 : 0.35;
    if (confidence > cap) confidence = cap;
  }

  return ParsedNotice(
    package: package,
    title: title,
    body: body,
    at: at,
    amount: amount ?? 0,
    currency: currency ?? fallbackCurrency,
    kind: income ? TxKind.income : TxKind.expense,
    last4: last4,
    merchant: merchant,
    balance: balance,
    confidence: confidence > 1 ? 1 : confidence,
  );
}

final _merchantAfter = RegExp(
  r'(?:(?:^|[\s,;:(])(?:в|at|la|to|from|от)\s|merchant[:\s]|магазин[:\s])'
  r'([A-ZА-ЯĂÂÎȘȚ][^,.;]{2,40})',
);

/// Где потратили. Берём либо слово после предлога, либо самый длинный кусок
/// из заглавных букв: банки пишут магазин капсом.
///
/// Заголовок уведомления в поиск не идёт: там стоит имя банка, и «СберБанк»
/// вместо «Пятёрочка» — не магазин, а название приложения.
String? _merchantOf(String text, String body, String title) {
  final after = _merchantAfter.firstMatch(text);
  if (after != null) {
    // «at Starbucks with Visa ••4568» — магазин здесь Starbucks: способ
    // оплаты и номер карты в название не входят.
    final name = _trimPayment(after.group(1)!);
    if (name.length >= 3 &&
        _looksLikeName(name) &&
        !_hasAny(name.toLowerCase(), _balanceWords)) {
      return name;
    }
  }

  String? best;
  for (final m in RegExp(r"[A-ZА-ЯĂÂÎȘȚ][A-ZА-ЯĂÂÎȘȚ0-9'&.\- ]{3,40}").allMatches(text)) {
    // «LINELLA CENTRU. Disponibil…» — точка кончает название, а следующая
    // заглавная буква к магазину не относится: раньше выходило «LINELLA
    // CENTRU. D».
    final candidate = m.group(0)!.split('. ').first.trim();
    final low = candidate.toLowerCase();
    // Валюты, слова направления и слова остатка магазином не бывают.
    if (_currencies.containsKey(low) || low.length < 4) continue;
    if (_hasAny(low, _balanceWords) || _hasAny(low, _spendWords)) continue;
    if (RegExp(r'^\d').hasMatch(candidate)) continue;
    if (best == null || candidate.length > best.length) best = candidate;
  }
  if (best != null) return best;

  // Магазин без предлога и без капса: «Achitare 300,00 MDL, card *1234,
  // Linella», «Покупка 1 289,00 ₽ Пятёрочка». Берём кусок между запятыми,
  // вычищаем из него сумму, валюту и слово направления — что осталось с
  // заглавной буквы, то и магазин.
  for (final part in body.split(RegExp(r'[,.;·•|]'))) {
    final low = part.toLowerCase();
    if (_hasAny(low, _balanceWords) || _hasAny(low, _skipWords)) continue;

    final candidate = _plainTail(part);
    if (candidate.length < 3 || candidate.length > 40) continue;
    if (!RegExp(r'^[A-ZА-ЯĂÂÎȘȚ]').hasMatch(candidate)) continue;
    if (!_looksLikeName(candidate)) continue;
    if (candidate.toLowerCase() == title.toLowerCase()) continue;
    if (_currencies.containsKey(candidate.toLowerCase())) continue;
    return candidate;
  }
  return null;
}

final _currencyWord = RegExp(
  r'(?:MDL|RUB|USD|EUR|GBP|RON|UAH|KZT|GEL|TRY|PLN|lei|руб|rub)\.?',
  caseSensitive: false,
);

/// Слова, после которых идёт уже не магазин, а способ оплаты: «Starbucks with
/// Visa ••4568». Google Wallet и иностранные банки пишут карту в той же фразе.
const _payWords = [
  ' with ', ' using ', ' card', ' visa', ' mastercard', ' maestro',
  ' amex', ' unionpay', ' карт', ' мир', ' via ', ' по карте',
];

/// Что осталось от куска текста, когда убрали сумму, валюту и слово
/// направления. Работает и с «Покупка 1 289,00 ₽ Пятёрочка», и с «Linella».
String _plainTail(String part) {
  final low = part.toLowerCase();
  // Название стоит ПОСЛЕ слова направления: «Покупка … Пятёрочка».
  var cut = 0;
  for (final word in [..._spendWords, ..._incomeWords]) {
    final at = low.lastIndexOf(word);
    if (at >= 0 && at + word.length > cut) cut = at + word.length;
  }

  var tail = part
      .substring(cut)
      .replaceAll(RegExp(r'[₽\$€£₴₸₾₺]'), ' ')
      .replaceAll(_currencyWord, ' ')
      .replaceAll(RegExp(r'[-+−–]?\d[\d\s.,]*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return _trimPayment(tail);
}

/// Название магазина или предложение рекламы.
///
/// «Credit pina la 100 000 MDL pentru tine!» тоже даёт кусок с заглавной
/// буквы, и без этой проверки реклама попадала в очередь вопросов как трата в
/// магазине с названием во всю фразу. У названия слов мало, и восклицаний в
/// нём не бывает.
bool _looksLikeName(String raw) {
  final name = raw.trim();
  if (name.contains('!') || name.contains('?') || name.contains(':')) return false;
  return name.split(RegExp(r'\s+')).length <= 3;
}

/// Отрезает от названия способ оплаты и номер карты: «Starbucks with Visa
/// ••4568» — это Starbucks.
String _trimPayment(String raw) {
  var tail = raw.trim();
  final low = tail.toLowerCase();
  for (final word in _payWords) {
    final at = low.indexOf(word);
    if (at > 0) tail = tail.substring(0, at.clamp(0, tail.length));
  }
  return tail
      .replaceAll(RegExp(r'[•*]+\s*\d*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
