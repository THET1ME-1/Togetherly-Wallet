/// Деньги — целые минорные единицы. double запрещён:
/// 0.1 + 0.2 = 0.30000000000000004, и на сводке за год это расходится с выпиской.
class Money {
  const Money(this.minor, {this.currency = 'RUB'});

  final int minor;
  final String currency;

  static const _thin = ' '; // тонкий пробел как разрядный разделитель
  static const _minus = '−'; // типографский минус, не дефис

  String get symbol => switch (currency) {
        'RUB' => '₽',
        'MDL' => 'L',
        'RON' => 'lei',
        'EUR' => '€',
        'USD' => r'$',
        _ => currency,
      };

  /// 1480 копеек → «14,80 ₽»; 12864000 → «128 640,00 ₽».
  ///
  /// Копейки стоят ВСЕГДА, даже нулевые: «128 640» читается как округление, а
  /// в деньгах округление — это чужая, пусть и правдоподобная сумма. Правило
  /// заказчика, отменять его нельзя.
  String format({bool withSymbol = true, bool signed = false}) {
    final neg = minor < 0;
    final abs = minor.abs();
    final whole = abs ~/ 100;
    final frac = abs % 100;
    final digits = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_thin);
      buf.write(digits[i]);
    }
    var out = buf.toString();
    out = '$out,${frac.toString().padLeft(2, '0')}';
    if (withSymbol) out = '$out$_thin$symbol';
    if (neg) return '$_minus$out';
    return signed ? '+$out' : out;
  }

  /// Дробная часть отдельной строкой: в крупных суммах её печатают
  /// на 0.55 кегля и 60% прозрачности.
  String get fractionPart => (minor.abs() % 100).toString().padLeft(2, '0');

  /// Складывать лей с евро нельзя. Пара живёт в разных валютах, и молчаливое
  /// сложение дало бы правдоподобную, но неверную сумму — худший вид ошибки
  /// в деньгах. Пересчёт делает вызывающий, по курсу на дату операции.
  Money operator +(Money o) => Money(minor + _same(o).minor, currency: currency);

  Money operator -(Money o) => Money(minor - _same(o).minor, currency: currency);

  Money _same(Money o) {
    if (o.currency != currency) {
      throw ArgumentError('Разные валюты: $currency и ${o.currency}. Пересчитайте по курсу.');
    }
    return o;
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  @override
  String toString() => 'Money(${format()})';

  /// Дележ базисными пунктами (сумма shares = 10000).
  /// Остаток от деления достаётся плательщику — сумма долей обязана
  /// совпасть с суммой операции до копейки.
  ///
  /// Проверка бросает, а не ассертит: в релизной сборке ассерт выключен,
  /// и кривые доли прошли бы молча, оставив копейки висеть в воздухе.
  static List<int> split(int totalMinor, List<int> sharesBp, {int payerIndex = 0}) {
    if (sharesBp.isEmpty) {
      throw ArgumentError('Доли не заданы');
    }
    final sum = sharesBp.fold<int>(0, (a, b) => a + b);
    if (sum != 10000) {
      throw ArgumentError('Доли должны давать 10000 bp, пришло $sum');
    }
    if (payerIndex < 0 || payerIndex >= sharesBp.length) {
      throw RangeError.index(payerIndex, sharesBp, 'payerIndex');
    }
    final out = <int>[];
    var used = 0;
    for (final bp in sharesBp) {
      final part = totalMinor * bp ~/ 10000;
      out.add(part);
      used += part;
    }
    out[payerIndex] += totalMinor - used;
    return out;
  }
}
