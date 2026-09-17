import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// Wallet+ — своя подписка приложения денег, отдельная от Togetherly+.
///
/// Главное правило проверяется здесь первым: потолок считается ТОЛЬКО при
/// создании новой записи. У человека, который вёл семь конвертов до появления
/// подписки, они остаются все — отобрать выданное нельзя.

PlusPass passUntil(Duration left, {int checkedDaysAgo = 0}) => PlusPass(
      until: DateTime.now().add(left).millisecondsSinceEpoch,
      source: PlusSource.play,
      checkedAt: DateTime.now()
          .subtract(Duration(days: checkedDaysAgo))
          .millisecondsSinceEpoch,
    );

Database sample({int budgets = 0, int goals = 0}) => Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [
        Category(name: 'Продукты'),
        Category(name: 'Транспорт'),
        Category(name: 'Жильё'),
        Category(name: 'Связь'),
        Category(name: 'Развлечения'),
        Category(name: 'Здоровье'),
        Category(name: 'Одежда'),
      ],
      budgets: [
        for (var i = 0; i < budgets; i++)
          Budget(
            category: ['Продукты', 'Транспорт', 'Жильё', 'Связь',
                'Развлечения', 'Здоровье', 'Одежда'][i % 7],
            limit: 1000,
            currency: 'MDL',
            period: 'monthly',
          ),
      ],
      goals: [
        for (var i = 0; i < goals; i++)
          Goal(name: 'Цель $i', target: 5000, currency: 'MDL'),
      ],
    );

Store storeOf({int budgets = 0, int goals = 0}) =>
    Store()..importBackupForTest(sample(budgets: budgets, goals: goals));

PlusService plusOf({PlusPass? pass}) => PlusService()..setForTest(pass);

Widget app(Widget home) => MaterialApp(theme: MoneyTheme.light(), home: home);

void main() {
  setUpAll(loadTmFonts);

  group('талон', () {
    test('оплаченный работает', () {
      expect(passUntil(const Duration(days: 10)).activeAt(DateTime.now()), isTrue);
    });

    test('после конца срока живёт ровно грейс', () {
      // Банк отклоняет платёж чаще, чем человек передумывает: три дня форы.
      expect(passUntil(const Duration(days: -1)).activeAt(DateTime.now()), isTrue);
      expect(passUntil(const Duration(days: -5)).activeAt(DateTime.now()), isFalse);
    });

    test('без сверки живёт месяц, потом закрывается', () {
      expect(
        passUntil(const Duration(days: 300), checkedDaysAgo: 20)
            .activeAt(DateTime.now()),
        isTrue,
        reason: 'поездка без сети не должна выключать оплаченное',
      );
      expect(
        passUntil(const Duration(days: 300), checkedDaysAgo: 40)
            .activeAt(DateTime.now()),
        isFalse,
        reason: 'иначе отменивший подписку пользуется ей, не включая интернет',
      );
    });

    test('талон переживает запись и чтение', () {
      final pass = passUntil(const Duration(days: 30));
      final back = PlusPass.fromJson(pass.toJson());
      expect(back!.until, pass.until);
      expect(back.source, PlusSource.play);
    });

    test('битый талон читается как «подписки нет»', () {
      expect(PlusPass.fromJson({'until': 'скоро'}), isNull);
      expect(PlusPass.fromJson(null), isNull);
    });
  });

  group('потолки', () {
    test('без подписки потолок держится', () {
      expect(canAddMore(plus: false, have: 4, limit: 5), isTrue);
      expect(canAddMore(plus: false, have: 5, limit: 5), isFalse);
    });

    test('с подпиской потолка нет', () {
      expect(canAddMore(plus: true, have: 99, limit: 5), isTrue);
    });

    test('заведённое сверх потолка не отбирается', () {
      // Семь конвертов у человека, который вёл их до появления подписки.
      // Восьмой он не заведёт, но и ни одного не потеряет.
      final store = storeOf(budgets: 7);
      expect(store.db.budgets, hasLength(7));
      expect(canAddMore(plus: false, have: 7, limit: PlusLimits.envelopes),
          isFalse);
    });
  });

  group('калитка', () {
    testWidgets('шестой конверт спрашивает подписку', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf(budgets: 5);
      await tester.pumpWidget(app(
        BudgetsScreen(store: store, plus: plusOf()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('budgetOne')));
      await tester.pumpAndSettle();

      // Стены-листа больше нет: упёрся — и сразу витрина Wallet+
      // (решение человека 17.09.2026).
      expect(find.byType(PlusScreen), findsOneWidget);
      // Форму не открыли: калитка встаёт ПЕРЕД работой, а не после неё.
      expect(find.text(tr('budgetNew')), findsNothing);
    });

    testWidgets('пятый конверт заводится молча', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf(budgets: 4);
      await tester.pumpWidget(app(
        BudgetsScreen(store: store, plus: plusOf()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('budgetOne')));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing);
    });

    testWidgets('с подпиской калитки нет вовсе', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf(budgets: 9);
      await tester.pumpWidget(app(BudgetsScreen(
        store: store,
        plus: plusOf(pass: passUntil(const Duration(days: 20))),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('budgetOne')));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing);
    });

    testWidgets('третья цель спрашивает подписку', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf(goals: 2);
      await tester.pumpWidget(app(GoalsScreen(store: store, plus: plusOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('goalOne')));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsOneWidget);
    });

    testWidgets('правка существующей записи мимо калитки', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Конвертов больше бесплатного числа, и человек правит один из них.
      final store = storeOf(budgets: 7);
      await tester.pumpWidget(app(
        BudgetsScreen(store: store, plus: plusOf()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Продукты').first);
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing,
          reason: 'правка своей записи не продаётся');
    });
  });

  group('витрина', () {
    testWidgets('показывает цены, что входит и что бесплатно', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(PlusScreen(plus: plusOf())));
      await tester.pumpAndSettle();

      expect(find.text(PlusPrice.rub.month), findsOneWidget);
      expect(find.text(PlusPrice.rub.year), findsOneWidget);
      expect(find.text(tr('plusFeatureChat')), findsOneWidget);

      // Блок «бесплатно навсегда» обязателен: без него витрина читается как
      // объявление о том, что приложение закрывается на замок.
      await tester.scrollUntilVisible(
        find.text(tr('plusFreeText')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(tr('plusFreeText')), findsOneWidget);
    });

    testWidgets('у действующей подписки вместо цен — срок', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(PlusScreen(
        plus: plusOf(pass: passUntil(const Duration(days: 40))),
      )));
      await tester.pumpAndSettle();

      expect(find.text(tr('plusActive')), findsOneWidget);
      expect(find.text(PlusPrice.rub.year), findsNothing);
      expect(find.text(tr('plusManage')), findsOneWidget);
    });
  });

  group('подписи витрины', () {
    test('в выгоде один процент, а не два', () {
      // `trf` подставляет только %s и экранирования не знает: «%%» доезжало
      // до человека как есть — «Выгода 43%%» (поймано на эмуляторе
      // 17.09.2026).
      final line = trf('plusSaving', ['43']);
      expect(line, 'Выгода 43%');
      expect(line, isNot(contains('%%')));
    });

    test('ни одна строка словаря не держит двойной процент', () {
      final guilty = <String>[];
      for (final entry in kMoneyStrings.entries) {
        for (final text in entry.value.values) {
          if (text.contains('%%')) guilty.add(entry.key);
        }
      }
      expect(guilty, isEmpty, reason: 'с «%%»: ${guilty.join(', ')}');
    });
  });

}
