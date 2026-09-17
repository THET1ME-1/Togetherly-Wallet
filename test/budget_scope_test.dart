import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/envelope.dart';

/// Охват бюджета: какие категории и какие счета он считает.
///
/// «Почему в бюджете главного меню нет всего нужного? Нет даты, нет периода с
/// кастомный, нет иконки, нет выбора валюты, нет учёта с каких категории его
/// считать» (17.09.2026). Дата, период и валюта в форме были; не было имени со
/// значком и цветом, нескольких категорий и выбора счетов.
///
/// Главная категория осталась КЛЮЧОМ записи: менять первичный ключ на сервере
/// ради этого значило бы переносить бюджеты у всех пар разом.

Transaction tx(
  String id, {
  required String category,
  String account = 'Карта',
  String? sub,
  double amount = -100,
  String date = '2026-09-10',
}) =>
    Transaction(
      id: id,
      date: date,
      kind: TxKind.expense,
      account: account,
      currency: 'MDL',
      amount: amount,
      amountBase: amount,
      category: category,
      subcategory: sub,
      author: 'u_me',
      payer: 'u_me',
    );

Database dbWith(List<Transaction> txs) => Database(
      baseCurrency: 'MDL',
      accounts: const [
        Account(name: 'Карта', currency: 'MDL'),
        Account(name: 'Наличные', currency: 'MDL'),
      ],
      categories: const [
        Category(name: 'Бензин'),
        Category(name: 'Мойка'),
        Category(name: 'Страховка'),
        Category(name: 'Еда'),
      ],
      transactions: txs,
    );

Budget car({List<String> accounts = const []}) => Budget(
      category: 'Бензин',
      limit: 3000,
      currency: 'MDL',
      period: 'monthly',
      name: 'Машина',
      icon: 'car',
      extraCategories: const ['Мойка', 'Страховка'],
      accounts: accounts,
    );

void main() {
  final day = DateTime(2026, 9, 15);

  group('несколько категорий', () {
    test('считаются все, а чужая — нет', () {
      // Бюджет на машину — это бензин, мойка и страховка вместе: по
      // отдельности их никто не планирует.
      final db = dbWith([
        tx('a', category: 'Бензин', amount: -700),
        tx('b', category: 'Мойка', amount: -200),
        tx('c', category: 'Страховка', amount: -1200),
        tx('d', category: 'Еда', amount: -500),
      ]);
      final env = envelopeOf(db, car(), today: day);
      expect(env.spent, 2100);
      expect(env.left, 900);
    });

    test('подкатегория сужает ТОЛЬКО главную категорию', () {
      // «Продукты · Кофе» плюс «Кафе» целиком — обычный бюджет на кофе, и
      // уточнение главной не должно отсекать вторую категорию.
      final db = dbWith([
        tx('a', category: 'Бензин', sub: '95-й', amount: -400),
        tx('b', category: 'Бензин', sub: 'Дизель', amount: -900),
        tx('c', category: 'Мойка', amount: -150),
      ]);
      final b = Budget(
        category: 'Бензин',
        subcategory: '95-й',
        limit: 1000,
        currency: 'MDL',
        period: 'monthly',
        extraCategories: const ['Мойка'],
      );
      expect(envelopeOf(db, b, today: day).spent, 550);
    });
  });

  group('счета', () {
    test('пустой список — считаются все счета', () {
      final db = dbWith([
        tx('a', category: 'Бензин', account: 'Карта', amount: -300),
        tx('b', category: 'Бензин', account: 'Наличные', amount: -200),
      ]);
      expect(envelopeOf(db, car(), today: day).spent, 500);
    });

    test('заданные счета отсекают чужие траты', () {
      // Бюджет на командировки считает служебную карту, а не всё подряд.
      final db = dbWith([
        tx('a', category: 'Бензин', account: 'Карта', amount: -300),
        tx('b', category: 'Бензин', account: 'Наличные', amount: -200),
      ]);
      final env = envelopeOf(db, car(accounts: ['Карта']), today: day);
      expect(env.spent, 300);
    });
  });

  group('имя', () {
    test('своё имя сильнее категории', () {
      expect(car().title, 'Машина');
    });

    test('без имени бюджет зовётся категорией с уточнением', () {
      const b = Budget(
        category: 'Продукты',
        subcategory: 'Кофе',
        limit: 500,
        currency: 'MDL',
        period: 'monthly',
      );
      expect(b.title, 'Продукты · Кофе');
    });
  });

  group('синхронизация', () {
    test('правка имени, значка и категорий уезжает на сервер', () {
      // Грабля этого проекта, сработавшая трижды: новое поле есть в модели, а
      // в отправке его нет — сервер отвечает 200 и молча теряет значение.
      final store = Store()
        ..importBackupForTest(dbWith(const []).copyWith(budgets: [car()]))
        ..syncEnabled = true;
      final before = {...store.outbox};

      store.setBudgets([
        car().copyWith(name: 'Авто', icon: 'wheel', color: 0xFF112233,
            extraCategories: const ['Мойка'], accounts: const ['Карта']),
      ]);

      expect(
        store.outbox.difference(before),
        contains(Store.budgetKey('Бензин', null)),
        reason: 'правка вида бюджета обязана уехать к партнёру',
      );
    });

    test('дельта приносит списки и строкой, и списком', () {
      // jsonb приезжает по-разному в зависимости от драйвера, и разбор обязан
      // понимать оба вида: иначе категории молча теряются.
      final store = Store()..importBackupForTest(dbWith(const []));
      store.applyRemote({
        'budgets': [
          {
            'category': 'Бензин',
            'subcategory': '',
            'limit_value': 3000,
            'currency': 'MDL',
            'period': 'monthly',
            'name': 'Машина',
            'icon': 'car',
            'color': 0xFF112233,
            'extra_categories': jsonEncode(['Мойка', 'Страховка']),
            'accounts': const ['Карта'],
          },
        ],
      });

      final b = store.db.budgets.single;
      expect(b.title, 'Машина');
      expect(b.icon, 'car');
      expect(b.color, 0xFF112233);
      expect(b.extraCategories, ['Мойка', 'Страховка']);
      expect(b.accounts, ['Карта']);
    });
  });
}
