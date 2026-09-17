import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/budgets_screen.dart';

import 'tm_fonts.dart';

/// Бюджет в паре.
///
/// До 17.09.2026 кнопка «Бюджеты» у пары открывала ДРУГОЙ экран —
/// «Договорённости» — со своей формой: выпадающий список категорий без
/// поиска, сумма всегда в базовой валюте, ни периода, ни переноса. Человек
/// ставил бюджет там, шёл на главную и видел «Нет активных бюджетов»:
/// «Я создал бюджет, но в главном меню пусто пишет».
///
/// Здесь проверяется то, что это чинит: экран один, форма одна, предложение
/// видно в списке бюджетов, а согласие партнёра переносит бюджет ЦЕЛИКОМ.

const me = 'uid-me';
const you = 'uid-you';

Store storeOf({List<Agreement> agreements = const [], List<Budget> budgets = const []}) =>
    Store()
      ..importBackupForTest(Database(
        baseCurrency: 'MDL',
        pair: const Pair(
          groupId: 'grp1',
          members: [
            Member(uid: me, name: 'Саша'),
            Member(uid: you, name: 'Линелла'),
          ],
        ),
        accounts: const [Account(name: 'Карта', currency: 'MDL')],
        categories: const [Category(name: 'Зал'), Category(name: 'Еда')],
        budgets: budgets,
        agreements: agreements,
      ))
      ..viewer = me;

Budget gym() => const Budget(
      category: 'Зал',
      subcategory: 'Абонемент',
      limit: 600,
      currency: 'EUR',
      period: 'weekly',
      rollover: true,
    );

void main() {
  setUpAll(loadTmFonts);

  group('предложение', () {
    test('в паре бюджет уходит предложением, а не записью', () {
      final store = storeOf();
      store.proposeBudget(gym(), note: 'ходим вдвоём');

      expect(store.db.budgets, isEmpty, reason: 'второй ещё не согласился');
      final a = store.db.agreements.single;
      expect(a.status, AgreementStatus.proposed);
      expect(a.proposedBy, me);
      expect(a.category, 'Зал');
      expect(a.note, 'ходим вдвоём');
    });

    test('предложение несёт бюджет целиком', () {
      // Раньше в договорённости ехали только категория и сумма, и согласие
      // собирало из них МЕСЯЧНЫЙ бюджет в базовой валюте: подкатегория,
      // неделя, перенос и евро пропадали по дороге.
      final store = storeOf();
      store.proposeBudget(gym());

      final b = store.db.agreements.single.budget!;
      expect(b.subcategory, 'Абонемент');
      expect(b.currency, 'EUR');
      expect(b.period, 'weekly');
      expect(b.rollover, isTrue);
    });

    test('повторное предложение по той же категории не плодит вторую карточку', () {
      final store = storeOf();
      store.proposeBudget(gym());
      store.proposeBudget(gym().copyWith(limit: 800));

      expect(store.db.agreements, hasLength(1));
      expect(store.db.agreements.single.amount, 800);
    });

    test('прежняя сумма запоминается для разговора', () {
      final store = storeOf(budgets: [gym().copyWith(limit: 400)]);
      store.proposeBudget(gym());
      expect(store.db.agreements.single.oldAmount, 400);
    });
  });

  group('согласие', () {
    test('бюджет восстанавливается целиком', () {
      final store = storeOf();
      store.proposeBudget(gym());
      store.acceptAgreement(store.db.agreements.single, you);

      final b = store.db.budgets.single;
      expect(b.category, 'Зал');
      expect(b.subcategory, 'Абонемент');
      expect(b.limit, 600);
      expect(b.currency, 'EUR');
      expect(b.period, 'weekly');
      expect(b.rollover, isTrue);
      expect(store.db.agreements.single.status, AgreementStatus.active);
    });

    test('старое предложение из двух полей принимается месячным бюджетом', () {
      // Совместимость: договорённости, отправленные до 17.09.2026, лежат у
      // пар на сервере и обязаны открываться сегодня.
      final store = storeOf(agreements: const [
        Agreement(
          id: 'agr-old',
          proposedBy: you,
          payload: {'category': 'Еда', 'amount': 2500, 'currency': 'MDL'},
        ),
      ]);
      store.acceptAgreement(store.db.agreements.single, me);

      final b = store.db.budgets.single;
      expect(b.category, 'Еда');
      expect(b.limit, 2500);
      expect(b.period, 'monthly');
      expect(b.subcategory, isNull);
    });

    test('согласие правит уже стоящий бюджет, а не заводит второй', () {
      final store = storeOf(budgets: [gym().copyWith(limit: 400)]);
      store.proposeBudget(gym());
      store.acceptAgreement(store.db.agreements.single, you);

      expect(store.db.budgets, hasLength(1));
      expect(store.db.budgets.single.limit, 600);
    });
  });

  group('экран', () {
    Widget app(Store store) => MaterialApp(
          theme: MoneyTheme.light(),
          home: BudgetsScreen(store: store),
        );

    testWidgets('предложенное видно там же, где бюджеты', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      store.proposeBudget(gym(), note: 'ходим вдвоём');

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text('Зал · Абонемент'), findsOneWidget);
      expect(find.text(trf('budgetWaiting', ['Линелла'])), findsOneWidget);
      // Пустой экран с «Ни одного бюджета» при отправленном предложении — та
      // самая пропажа, с которой всё началось.
      expect(find.text(tr('budgetsEmpty')), findsNothing);
    });

    testWidgets('чужое предложение спрашивает согласия', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      store.viewer = you;
      store.proposeBudget(gym());
      store.viewer = me;

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('agreementAgree')));
      await tester.pumpAndSettle();

      expect(store.db.budgets.single.category, 'Зал');
    });

    testWidgets('отказ партнёра виден и предлагается заново', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      store.proposeBudget(gym());
      store.saveAgreement(store.db.agreements.single.copyWith(
        status: AgreementStatus.declined,
        acceptedBy: you,
      ));

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text(trf('budgetDeclinedBy', ['Линелла'])), findsOneWidget);

      await tester.tap(find.text(tr('budgetDropProposal')));
      await tester.pumpAndSettle();
      expect(store.db.agreements, isEmpty);
    });

    testWidgets('у одиночки бюджет пишется сразу, без предложения',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = Store()
        ..importBackupForTest(const Database(
          baseCurrency: 'MDL',
          categories: [Category(name: 'Зал')],
        ));

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text(tr('budgetsEmpty')), findsOneWidget);
      expect(find.text(tr('budgetsEmptyPair')), findsNothing);
    });
  });
}
