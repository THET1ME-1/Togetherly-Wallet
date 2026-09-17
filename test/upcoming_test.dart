import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/recurring.dart';
import 'package:togetherly_money/logic/subscriptions.dart';

Recurring rec(String name, String next, {bool active = true}) => Recurring(
      id: name,
      name: name,
      amount: 1000,
      currency: 'MDL',
      account: 'Карта',
      interval: 'monthly',
      nextDate: next,
      kind: 'expense',
      active: active,
    );

Transaction spend(String id, String date, double amount, String note) =>
    Transaction(
      id: id,
      date: date,
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -amount,
      amountBase: -amount,
      note: note,
      category: 'Связь и подписки',
      author: 'u_me',
      payer: 'u_me',
    );

void main() {
  group('скоро списания', () {
    test('показывает ближайшие и не показывает далёкие', () {
      final db = Database(
        baseCurrency: 'MDL',
        recurring: [
          rec('Квартплата', '2026-09-15'),
          rec('Интернет', '2026-09-14'),
          rec('Страховка', '2026-10-20'),
          rec('Выключенное', '2026-09-14', active: false),
        ],
      );
      final soon = dueSoon(db, today: DateTime(2026, 9, 13), days: 3);
      expect(soon.map((r) => r.name), ['Интернет', 'Квартплата']);
    });

    test('просроченное тоже здесь: о нём забыть страшнее всего', () {
      final db = Database(
        baseCurrency: 'MDL',
        recurring: [rec('Кредит', '2026-09-10')],
      );
      final soon = dueSoon(db, today: DateTime(2026, 9, 13));
      expect(soon.single.name, 'Кредит');
    });
  });

  group('забытые подписки', () {
    test('три одинаковых списания с месячным шагом — подписка', () {
      final db = Database(
        baseCurrency: 'MDL',
        transactions: [
          spend('a', '2026-07-11', 149, 'Netflix'),
          spend('b', '2026-08-11', 149, 'Netflix'),
          spend('c', '2026-09-11', 149, 'Netflix'),
        ],
      );
      final found = subscriptionsOf(db, today: DateTime(2026, 9, 13));
      expect(found.single.name, 'Netflix');
      expect(found.single.amount, 149);
      expect(found.single.times, 3);
    });

    test('случайные траты подпиской не считаются', () {
      final db = Database(
        baseCurrency: 'MDL',
        transactions: [
          spend('a', '2026-07-11', 149, 'Кофе'),
          spend('b', '2026-07-19', 60, 'Кофе'),
          spend('c', '2026-08-02', 210, 'Кофе'),
        ],
      );
      expect(subscriptionsOf(db, today: DateTime(2026, 9, 13)), isEmpty);
    });

    test('то, что уже заведено регулярным, второй раз не предлагается', () {
      final db = Database(
        baseCurrency: 'MDL',
        recurring: [rec('Netflix', '2026-10-11')],
        transactions: [
          spend('a', '2026-07-11', 149, 'Netflix'),
          spend('b', '2026-08-11', 149, 'Netflix'),
          spend('c', '2026-09-11', 149, 'Netflix'),
        ],
      );
      expect(subscriptionsOf(db, today: DateTime(2026, 9, 13)), isEmpty);
    });
  });

  group('договорённости пары', () {
    test('порог крупной траты и дата разговора доживают до сервера', () {
      const rules = Rules(bigSpend: 5000, moneyDate: '2026-09-20');
      final again = Rules.fromJson(rules.toJson());
      expect(again.bigSpend, 5000);
      expect(again.moneyDate, '2026-09-20');

      // На сервер уезжает змеиной нотацией — в том же jsonb, что и правила
      // общего кошелька: колонок добавлять не пришлось.
      final body = rules.toServer()['pot_rules'] as Map;
      expect(body['big_spend'], 5000);
      expect(body['money_date'], '2026-09-20');
      expect(Rules.fromJson({'pot_rules': body}).bigSpend, 5000);
    });
  });
}
