import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/ledger.dart';
import 'package:togetherly_money/screens/notices_review_screen.dart';
import 'package:togetherly_money/screens/stats_screen.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/stats.dart';

import '../tm_fonts.dart';

/// Снимки для страницы приложения в Google Play.
///
/// Данные ЗДЕСЬ ВЫДУМАНЫ и выдуманы нарочно: `test/shots` рисуется настоящей
/// базой заказчика, и такие кадры показывать миллиону человек нельзя — там
/// его счета, остатки и названия подписок.
void main() {
  setUpAll(loadTmFonts);
  final dir = Directory('build/play')..createSync(recursive: true);

  const me = 'uid-sasha';
  const you = 'uid-lena';
  final period = Period.month(DateTime(2026, 9, 14));

  Transaction op(
    String id,
    String date,
    double sum,
    String category,
    String note, {
    String payer = me,
    String account = 'Общий кошелёк',
    String? subcategory,
    SplitMode split = SplitMode.equal,
  }) =>
      Transaction(
        id: id,
        date: date,
        kind: sum < 0 ? TxKind.expense : TxKind.income,
        account: account,
        currency: 'MDL',
        amount: sum,
        amountBase: sum,
        category: category,
        subcategory: subcategory,
        note: note,
        author: payer,
        payer: payer,
        split: split,
      );

  final db = Database(
    baseCurrency: 'MDL',
    pair: const Pair(
      groupId: 'grp-demo',
      members: [
        Member(uid: me, name: 'Саша', color: 0xFFB8E0C8),
        Member(uid: you, name: 'Лена', color: 0xFFDCD2F0),
      ],
    ),
    accounts: const [
      Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true),
      Account(name: 'Карта', currency: 'MDL', last4: '4417', brand: CardBrand.visa),
      Account(name: 'Наличные', currency: 'MDL', kind: AccountKind.cash),
      Account(name: 'Накопительный', currency: 'EUR', kind: AccountKind.savings),
    ],
    categories: const [
      Category(name: 'Продукты'),
      Category(name: 'Кофе', parent: 'Продукты'),
      Category(name: 'Кафе'),
      Category(name: 'Дом'),
      Category(name: 'Транспорт'),
      Category(name: 'Здоровье'),
      Category(name: 'Подарки'),
      Category(name: 'Зарплата', kind: CatKind.income),
    ],
    budgets: const [
      Budget(category: 'Продукты', limit: 4000, currency: 'MDL', period: 'monthly'),
      Budget(category: 'Кафе', limit: 1200, currency: 'MDL', period: 'monthly'),
      Budget(category: 'Транспорт', limit: 800, currency: 'MDL', period: 'monthly'),
      Budget(category: 'Дом', limit: 3500, currency: 'MDL', period: 'monthly'),
    ],
    goals: const [
      Goal(name: 'Поездка в Прагу', target: 18000, currency: 'MDL'),
      Goal(name: 'Подушка', target: 30000, currency: 'MDL', kind: GoalKind.reserve),
    ],
    transactions: [
      // Начальные остатки: без них счета уходят в минус, и витрина врёт.
      op('s1', '2026-09-01', 12000.00, 'Зарплата', 'остаток на начало',
          account: 'Карта', split: SplitMode.none),
      op('s2', '2026-09-01', 3400.00, 'Зарплата', 'остаток на начало',
          account: 'Наличные', split: SplitMode.none),
      op('t1', '2026-09-14', -284.50, 'Продукты', 'Linella', subcategory: 'Кофе'),
      op('t2', '2026-09-14', -96.00, 'Кафе', 'кофе с собой', payer: you,
          split: SplitMode.payerOnly, account: 'Карта'),
      op('t3', '2026-09-13', -1250.00, 'Дом', 'интернет за сентябрь', payer: you),
      op('t4', '2026-09-13', -340.00, 'Транспорт', 'такси домой'),
      op('t5', '2026-09-12', -612.30, 'Продукты', 'рынок', payer: you),
      op('t6', '2026-09-12', -180.00, 'Здоровье', 'аптека', account: 'Карта'),
      op('t7', '2026-09-11', -420.00, 'Кафе', 'ужин вдвоём', payer: you),
      op('t8', '2026-09-10', 21500.00, 'Зарплата', '', split: SplitMode.none),
      op('t9', '2026-09-09', -760.00, 'Подарки', 'цветы', account: 'Наличные'),
      op('t10', '2026-09-08', -95.40, 'Транспорт', 'троллейбус', payer: you),
      op('t11', '2026-09-07', -1840.00, 'Продукты', 'закупка на неделю'),
      op('t12', '2026-09-05', 9800.00, 'Зарплата', '', payer: you, split: SplitMode.none),
    ],
  );

  Store storeOf() {
    final store = Store()..importBackupForTest(db);
    store.viewer = me;
    return store;
  }

  /// Кадр телефона: 393×852 логических при трёхкратном увеличении.
  Future<void> shoot(WidgetTester tester, String name, Widget screen) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MoneyTheme.light(),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 40));

    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  testWidgets('главная', (tester) async {
    await shoot(tester, '1-home', HomeScreen(
      store: storeOf(),
      period: period,
      onPeriod: (_) {},
      onAccounts: () {},
      onBudgets: () {},
      onGoals: () {},
      onPlan: () {},
      onDebts: () {},
      onChat: () {},
      onSettings: () {},
      onDrill: (_, __, [Period? ___]) {},
    ));
  });

  testWidgets('лента', (tester) async {
    await shoot(tester, '2-ledger', LedgerScreen(
      store: storeOf(),
      period: period,
      onPeriod: (_) {},
      filter: const Filter(viewer: me),
      onFilter: (_) {},
      onEdit: ([Transaction? _]) {},
    ));
  });

  testWidgets('статистика', (tester) async {
    await shoot(tester, '3-stats', StatsScreen(
      store: storeOf(),
      period: period,
      onPeriod: (_) {},
      onDrill: (_, __, [Period? ___]) {},
    ));
  });

  testWidgets('конверты', (tester) async {
    await shoot(tester, '4-budgets', BudgetsScreen(store: storeOf()));
  });

  testWidgets('разбор списаний', (tester) async {
    final store = storeOf();
    for (final n in [
      ('md.maib.mobile', 'maib', 'Achitare 284,50 MDL, card *4417, LINELLA CHISINAU'),
      ('md.maib.mobile', 'maib', 'Achitare 96,00 MDL, card *4417, TUCANO COFFEE'),
      ('md.maib.mobile', 'maib', 'Achitare 340,00 MDL, card *4417, YANGO TAXI'),
    ]) {
      store.addNotice(parseNotice(
        package: n.$1,
        title: n.$2,
        body: n.$3,
        at: DateTime(2026, 9, 14, 13, 40).millisecondsSinceEpoch,
        fallbackCurrency: 'MDL',
      ));
    }
    await shoot(tester, '5-notices', NoticesReviewScreen(store: store));
  });
}
