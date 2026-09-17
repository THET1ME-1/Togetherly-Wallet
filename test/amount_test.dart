import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/money.dart';
import 'package:togetherly_money/widgets/money_text.dart';

/// Разбор введённой суммы: в поле правки лежит уже отформатированное число с
/// разрядными пробелами и запятой. Обычный `double.tryParse` на таком отдаёт
/// null, то есть молча превращает лимит в ноль.
void main() {
  group('разбор введённой суммы', () {
    test('разрядные пробелы и запятая не мешают', () {
      expect(parseAmount('45 000,00'), 45000.0);
      expect(parseAmount('45000.5'), 45000.5);
      expect(parseAmount('1 200'), 1200.0);
      expect(parseAmount('  17,00  '), 17.0);
    });

    test('пустая строка и мусор дают null, а не ноль', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('абв'), isNull);
    });

    test('копейки не теряются при выводе в поле правки', () {
      // Поле правки заполняется formatAmount: с decimals: 0 лимит 4000,50
      // округлялся до 4 001 и сохранялся уже неверным.
      expect(parseAmount(formatAmount(4000.50)), 4000.50);
      expect(parseAmount(formatAmount(14.67)), 14.67);
    });
  });

  test('сумма с валютой не разрывается по пробелу', () {
    // «MDL 1 000,00» обычными пробелами — это три слова. В строке на одну
    // строчку Flutter переносит по ним, и на экране записи от суммы
    // оставалось «MDL», а цифры уходили за её край (поймано 14.09.2026).
    final s = formatMoney(1000, 'MDL');
    expect(s.contains(' '), isFalse, reason: 'обычный пробел рвёт строку: $s');
    expect(s, 'MDL\u00A01\u00A0000,00');
    // Разбор обратно от этого не страдает.
    expect(parseAmount(formatAmount(1000)), 1000);
  });
}
