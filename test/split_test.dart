import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/split.dart';

const artem = Member(uid: 'u_artem', name: 'Артём', incomeShareBp: 6000);
const lena = Member(uid: 'u_lena', name: 'Лена', incomeShareBp: 4000);
const pair = Pair(groupId: 'g1', members: [artem, lena], baseCurrency: 'MDL');

Transaction tx({
  required double amount,
  SplitMode split = SplitMode.equal,
  String payer = 'u_artem',
  TxKind kind = TxKind.expense,
  Map<String, int>? shares,
  String id = 't1',
}) =>
    Transaction(
      id: id,
      date: '2026-09-12',
      kind: kind,
      account: 'Общий кошелёк',
      currency: 'MDL',
      amount: -amount,
      amountBase: -amount,
      author: payer,
      payer: payer,
      split: split,
      shares: shares,
    );

void main() {
  group('доли', () {
    test('поровну, сумма долей равна трате до копейки', () {
      for (final total in [800.0, 100.01, 0.07, 1234.56]) {
        final parts = splitOf(tx(amount: total), pair);
        final sum = parts.values.fold<double>(0, (a, b) => a + b);
        expect((sum * 100).round(), (total * 100).round(), reason: 'сумма $total');
      }
    });

    test('нечётная копейка достаётся плательщику', () {
      final parts = splitOf(tx(amount: 100.01), pair);
      expect(parts['u_artem'], closeTo(50.01, 0.001));
      expect(parts['u_lena'], closeTo(50.00, 0.001));
    });

    test('по доходу: 60 на 40', () {
      final parts = splitOf(tx(amount: 1000, split: SplitMode.income), pair);
      expect(parts['u_artem'], closeTo(600, 0.001));
      expect(parts['u_lena'], closeTo(400, 0.001));
    });

    test('только плательщик — вся трата его', () {
      final parts = splitOf(tx(amount: 500, split: SplitMode.payerOnly), pair);
      expect(parts['u_artem'], closeTo(500, 0.001));
      expect(parts.containsKey('u_lena'), isFalse);
    });

    test('свои доли', () {
      final parts = splitOf(
        tx(amount: 300, split: SplitMode.custom, shares: {'u_artem': 7000, 'u_lena': 3000}),
        pair,
      );
      expect(parts['u_artem'], closeTo(210, 0.001));
      expect(parts['u_lena'], closeTo(90, 0.001));
    });

    test('операция одиночки без дележа никого не трогает', () {
      final parts = splitOf(tx(amount: 200, split: SplitMode.none), pair);
      expect(parts['u_artem'], closeTo(200, 0.001));
      expect(parts.length, 1);
    });
  });

  group('сальдо', () {
    test('одна трата пополам: за партнёром половина', () {
      final s = settlement([tx(amount: 1480)], pair);
      expect(s['u_artem'], closeTo(740, 0.001));
      expect(s['u_lena'], closeTo(-740, 0.001));
    });

    test('встречные траты гасят друг друга', () {
      final s = settlement([
        tx(amount: 1000, id: 'a'),
        tx(amount: 1000, id: 'b', payer: 'u_lena'),
      ], pair);
      expect(s['u_artem'], closeTo(0, 0.001));
      expect(s['u_lena'], closeTo(0, 0.001));
    });

    test('доход и перевод в сальдо не идут', () {
      final s = settlement([
        tx(amount: 5000, kind: TxKind.income, id: 'i'),
        tx(amount: 300, kind: TxKind.transfer, id: 'tr'),
      ], pair);
      expect(s['u_artem'], closeTo(0, 0.001));
    });

    // «За Леной 740,00» человек читал и не понимал, кто кому должен, а рядом
    // стоит кнопка «Выровнять» (16.09.2026). Направление теперь в самой
    // строке, имя партнёра — подписью над ней.
    test('строка для главной говорит направление, а не падеж имени', () {
      final s = settlement([tx(amount: 1480)], pair);
      expect(debtLine(s, pair, 'u_artem'), 'Вам должны 740,00');
      expect(debtLine(s, pair, 'u_lena'), 'Вы должны 740,00');
      expect(debtLine(settlement(const [], pair), pair, 'u_artem'), 'Вы в расчёте');
    });

    test('подпись над строкой называет партнёра', () {
      expect(debtWith(pair, 'u_artem'), 'Сальдо с Леной');
      expect(debtWith(pair, 'u_lena'), 'Сальдо с Артёмом');
    });
  });

  group('приватность', () {
    test('чужая скрытая трата приходит без сути, но с суммой', () {
      final secret = Transaction(
        id: 's1', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -12000, amountBase: -12000,
        category: 'Подарки', note: 'Серьги', author: 'u_artem', payer: 'u_artem',
        secret: true, revealAt: '2027-02-14',
      );
      final seen = redactFor(secret, 'u_lena', today: DateTime(2026, 9, 12));
      expect(seen.amount, secret.amount, reason: 'сумма видна всегда, иначе баланс врёт');
      expect(seen.category, isNull);
      expect(seen.note, isNull);
      expect(seen.secret, isTrue);
    });

    test('своя скрытая трата видна целиком', () {
      final secret = Transaction(
        id: 's2', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -12000, amountBase: -12000,
        note: 'Серьги', author: 'u_artem', payer: 'u_artem', secret: true,
      );
      expect(redactFor(secret, 'u_artem', today: DateTime(2026, 9, 12)).note, 'Серьги');
    });

    test('после даты раскрытия видно всем', () {
      final secret = Transaction(
        id: 's3', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -12000, amountBase: -12000,
        note: 'Серьги', author: 'u_artem', payer: 'u_artem',
        secret: true, revealAt: '2027-02-14',
      );
      expect(redactFor(secret, 'u_lena', today: DateTime(2027, 2, 14)).note, 'Серьги');
    });
  });
}
