import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/notice_parse.dart';

/// Корпус форматов: Молдова, Россия и то, что шлют иностранные кошельки.
///
/// Разбор проверяется текстом, а не банком: у каждого банка десяток форматов,
/// они меняются без спроса, и правила должны держаться на форме, а не на
/// списке имён.
ParsedNotice p(String title, String body, {String pkg = 'test.bank'}) =>
    parseNotice(package: pkg, title: title, body: body, at: 1789200000000);

void main() {
  group('Молдова', () {
    test('maib: румынская покупка со остатком', () {
      final n = p('maib', 'Achitare: -137.40 MDL, card *1234, LINELLA, '
          'disponibil: 4 300.00 MDL');
      expect(n.amount, 137.40);
      expect(n.currency, 'MDL');
      expect(n.kind, TxKind.expense);
      expect(n.last4, '1234');
      // Остаток не должен подменять сумму операции — главная ошибка разбора.
      expect(n.balance, 4300.00);
      expect(n.ok, isTrue);
    });

    test('maib: русская покупка', () {
      final n = p('maib', 'Оплата: -249,99 MDL, карта *8413, ANDY\'S PIZZA. '
          'Доступно 1 050,10 MDL');
      expect(n.amount, 249.99);
      expect(n.last4, '8413');
      expect(n.kind, TxKind.expense);
      expect(n.balance, 1050.10);
    });

    test('maib: зачисление зарплаты', () {
      final n = p('maib', 'Încasare +9 800.00 MDL, card *1234, SALARIU');
      expect(n.amount, 9800);
      expect(n.kind, TxKind.income);
    });

    test('Victoriabank: сумма без знака, направление словом', () {
      final n = p('Victoriabank', 'Plata cu cardul *4568: 137,40 MDL la LINELLA. '
          'Disponibil 1 234,56 MDL');
      expect(n.amount, 137.40);
      expect(n.kind, TxKind.expense);
      expect(n.last4, '4568');
      expect(n.balance, 1234.56);
    });

    test('MICB: лей одной буквой', () {
      final n = p('MICB', 'Tranzacție: -250,00 L, card ***1234, KAUFLAND');
      expect(n.amount, 250);
      expect(n.currency, 'MDL');
      expect(n.last4, '1234');
    });

    test('снятие наличных', () {
      final n = p('maib', 'Retragere numerar -1000.00 MDL, card *1234, ATM MAIB');
      expect(n.amount, 1000);
      expect(n.kind, TxKind.expense);
    });
  });

  group('Россия', () {
    test('Сбербанк: покупка с балансом', () {
      final n = p('Сбербанк', 'Покупка 1 234,56 ₽, VKUSVILL, карта *1234. '
          'Баланс: 12 345,67 ₽');
      expect(n.amount, 1234.56);
      expect(n.currency, 'RUB');
      expect(n.kind, TxKind.expense);
      expect(n.last4, '1234');
      expect(n.balance, 12345.67);
    });

    test('Сбербанк: перевод по СБП', () {
      final n = p('Сбербанк', 'СБП. Перевод 500 ₽ Ивану И.');
      expect(n.amount, 500);
      expect(n.currency, 'RUB');
      expect(n.kind, TxKind.expense);
    });

    test('Т-Банк: остаток отдельной фразой', () {
      final n = p('Т-Банк', 'Списание 450 ₽. Пятёрочка. Карта *4568. Остаток 12 345 ₽');
      expect(n.amount, 450);
      expect(n.last4, '4568');
      expect(n.balance, 12345);
    });

    test('Альфа: счёт вместо карты', () {
      final n = p('Альфа-Банк', 'Оплата 1 500,00 ₽, ЯНДЕКС.ЕДА, счёт *1234');
      expect(n.amount, 1500);
      expect(n.last4, '1234');
    });

    test('ВТБ: валюта кодом после суммы', () {
      final n = p('ВТБ', 'Покупка. Карта*1234. 799.00 RUB. WILDBERRIES. '
          'Доступно 5 000.00 RUB');
      expect(n.amount, 799);
      expect(n.currency, 'RUB');
      expect(n.last4, '1234');
    });

    test('зачисление на карту', () {
      final n = p('Сбербанк', 'Зачисление 25 000,00 ₽, карта *1234. Баланс 30 000 ₽');
      expect(n.amount, 25000);
      expect(n.kind, TxKind.income);
    });

    test('кэшбэк — это доход, а не трата', () {
      final n = p('Т-Банк', 'Кэшбэк 120 ₽ за август. Карта *4568');
      expect(n.amount, 120);
      expect(n.kind, TxKind.income);
    });

    test('Ozon: сумма без копеек и без карты', () {
      final n = p('Ozon Банк', 'Оплата 2 390 ₽ в Ozon');
      expect(n.amount, 2390);
      expect(n.kind, TxKind.expense);
      expect(n.last4, isNull);
      expect(n.ok, isTrue, reason: 'суммы и направления хватает, карта не обязательна');
    });
  });

  group('иностранные кошельки', () {
    test('Payoneer: получен платёж', () {
      final n = p('Payoneer', 'You received a payment of \$250.00 USD from ACME Inc.');
      expect(n.amount, 250);
      expect(n.currency, 'USD');
      expect(n.kind, TxKind.income);
    });

    test('Payoneer: списание с карты', () {
      final n = p('Payoneer',
          'A payment of \$19.99 was charged to your Payoneer card ending in 4568');
      expect(n.amount, 19.99);
      expect(n.currency, 'USD');
      expect(n.kind, TxKind.expense);
      expect(n.last4, '4568');
    });

    test('Revolut: евро с запятой', () {
      final n = p('Revolut', 'You spent €12,30 at Starbucks');
      expect(n.amount, 12.30);
      expect(n.currency, 'EUR');
      expect(n.kind, TxKind.expense);
    });

    test('PayPal: американский формат разрядов', () {
      final n = p('PayPal', 'You sent \$1,234.56 USD to STORE LLC');
      expect(n.amount, 1234.56);
      expect(n.currency, 'USD');
      expect(n.kind, TxKind.expense);
    });

    test('Wise: валюта кодом после суммы', () {
      final n = p('Wise', 'You spent 12.30 EUR at LIDL');
      expect(n.amount, 12.30);
      expect(n.currency, 'EUR');
    });
  });

  group('платёж телефоном', () {
    test('Google Wallet по-русски: «Оплачено» тоже слово траты', () {
      final n = p('Google Pay', 'Оплачено 249,00 MDL, maib Mastercard ••1234');
      expect(n.amount, 249);
      expect(n.currency, 'MDL');
      expect(n.kind, TxKind.expense);
      expect(n.last4, '1234');
      expect(n.ok, isTrue);
    });

    test('способ оплаты в название магазина не входит', () {
      final n = p('Google Wallet', 'You paid 12.50 USD at Starbucks with Visa ••4568');
      expect(n.amount, 12.5);
      expect(n.merchant, 'Starbucks');
      expect(n.last4, '4568');
    });

    test('сумма и магазин через точку-разделитель', () {
      final n = p('Google Pay', '\$12.50 · Starbucks');
      expect(n.amount, 12.5);
      expect(n.currency, 'USD');
      expect(n.merchant, 'Starbucks');
      // Слова направления нет — сами такое не пишем, только показываем.
      expect(n.ok, isFalse);
    });

    test('«Карта использована» без суммы — не операция', () {
      expect(p('Google Wallet', 'Карта использована. Mastercard ••1234').amount, 0);
    });
  });

  group('чего разбор делать не должен', () {
    test('не берёт остаток за сумму, если суммы нет вовсе', () {
      final n = p('Банк', 'Доступно 4 300,00 MDL');
      expect(n.amount, 0);
      expect(n.balance, 4300);
      expect(n.ok, isFalse);
    });

    test('не считает суммой номер карты и время', () {
      final n = p('Банк', 'Карта 1234 заблокирована в 15:30');
      expect(n.amount, 0);
      expect(n.ok, isFalse);
    });

    test('не берёт комиссию за сумму операции', () {
      final n = p('Банк', 'Перевод 1 000,00 MDL, комиссия 15,00 MDL, карта *1234');
      expect(n.amount, 1000);
    });

    test('рекламное уведомление не проходит порог', () {
      final n = p('Банк', 'Кредит до 100 000 MDL за 5 минут! Успейте до 30 сентября');
      expect(n.ok, isFalse, reason: 'ни направления, ни карты — только число');
    });

    test('код подтверждения не становится тратой', () {
      final n = p('Банк', 'Код 4821 никому не сообщайте');
      expect(n.amount, 0);
      expect(n.ok, isFalse);
    });

    test('неизвестный язык с суммой и картой всё равно разбирается', () {
      // Турецкий банк: слов мы не знаем, но минус, сумма и карта на месте.
      final n = p('Bank', 'Kart *4568 ile -137,40 TRY harcama');
      expect(n.amount, 137.40);
      expect(n.currency, 'TRY');
      expect(n.kind, TxKind.expense);
      expect(n.last4, '4568');
    });
  });

  group('отпечаток против двойной записи', () {
    test('одно и то же уведомление даёт один отпечаток', () {
      final a = p('maib', 'Achitare: -137.40 MDL, card *1234, LINELLA');
      final b = p('maib', 'Achitare: -137.40 MDL, card *1234, LINELLA');
      expect(a.fingerprint, b.fingerprint);
    });

    test('другая сумма или другая карта — другой отпечаток', () {
      final a = p('maib', 'Achitare: -137.40 MDL, card *1234');
      final b = p('maib', 'Achitare: -137.41 MDL, card *1234');
      final c = p('maib', 'Achitare: -137.40 MDL, card *9999');
      expect(a.fingerprint == b.fingerprint, isFalse);
      expect(a.fingerprint == c.fingerprint, isFalse);
    });
  });

  group('где потратили', () {
    test('магазин берётся после предлога', () {
      expect(p('Банк', 'Оплата 300 ₽ в Пятёрочка, карта *1234').merchant, 'Пятёрочка');
    });

    test('точка кончает название, буква следующего слова не липнет', () {
      final n = p('maib',
          'Achitare 417,60 MDL, card *1234, LINELLA CENTRU. Disponibil: 4 512,30 MDL');
      expect(n.merchant, 'LINELLA CENTRU');
    });

    test('магазин капсом берётся целиком', () {
      expect(p('maib', 'Achitare -137.40 MDL, card *1234, ANDY\'S PIZZA').merchant,
          contains('ANDY'));
    });

    test('остаток магазином не становится', () {
      final n = p('maib', 'Achitare -137.40 MDL, card *1234, disponibil 4 300 MDL');
      expect(n.merchant, isNot(contains('disponibil')));
    });

    test('магазин строчными буквами сразу после суммы', () {
      expect(p('СберБанк', 'Покупка 1 289,00 ₽ Пятёрочка. Баланс: 12 400,55 ₽').merchant,
          'Пятёрочка');
    });

    test('магазин через запятую без предлога', () {
      expect(p('maib', 'Achitare 417,60 MDL, card *1234, Linella Centru').merchant,
          'Linella Centru');
    });

    test('имя банка из заголовка магазином не становится', () {
      final n = p('Т-Банк', 'Оплата 450 ₽. Остаток 3 200 ₽');
      expect(n.merchant, isNot('Т-Банк'));
    });

    test('номер карты магазином не становится', () {
      final n = p('maib', 'Achitare 90,00 MDL, card *1234');
      expect(n.merchant, isNull);
    });
  });

  group('разбор чисел', () {
    test('разные разделители дают одно число', () {
      expect(p('b', 'Оплата 1 234,56 MDL, карта *1').amount, 1234.56);
      expect(p('b', 'Оплата 1,234.56 USD').amount, 1234.56);
      expect(p('b', 'Оплата 1.234,56 EUR').amount, 1234.56);
      expect(p('b', 'Оплата 137.4 MDL, карта *1').amount, 137.4);
      expect(p('b', 'Оплата 5 MDL, карта *1').amount, 5);
    });
  });
}
