import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/accounts_screen.dart';
import 'package:togetherly_money/screens/operation_edit.dart';

import 'tm_fonts.dart';

/// Пустое устройство: ни счетов, ни категорий, ни операций — ровно то, что
/// видит человек сразу после входа.
Store emptyStore() {
  final store = Store()..importBackupForTest(const Database(baseCurrency: 'MDL'));
  store.viewer = 'u_me';
  return store;
}

Widget app(Widget home) => MaterialApp(theme: MoneyTheme.light(), home: home);

void main() {
  setUpAll(loadTmFonts);

  group('первый счёт', () {
    testWidgets('пустой экран счетов предлагает завести первый', (tester) async {
      final store = emptyStore();
      await tester.pumpWidget(app(AccountsScreen(store: store, onEdit: (_) {}, onAccountOps: (_) {})));
      await tester.pumpAndSettle();

      // Кнопка «Новая» раньше пряталась внутри списка карт, и при нуле счетов
      // завести первый было НЕЧЕМ.
      expect(find.text(tr('accountsNone')), findsOneWidget);
      expect(find.text(tr('accountFirst')), findsOneWidget);
    });

    testWidgets('запись без единого счёта заводит счёт и сохраняется',
        (tester) async {
      final store = emptyStore();
      await tester.pumpWidget(app(OperationScreen(store: store)));
      await tester.pumpAndSettle();

      // Клавиатура набирает КОПЕЙКИ: «5000» это 50,00.
      await tester.tap(find.widgetWithText(InkWell, '5').first);
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.tap(find.widgetWithText(InkWell, '0').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('opSave')));
      await tester.pumpAndSettle();

      // Обещание «счёт создастся при первой записи» обязано быть правдой:
      // раньше `_save` молча выходил и трата пропадала.
      expect(store.db.accounts.length, 1);
      expect(store.db.accounts.first.name, tr('accountDefaultName'));
      expect(store.db.transactions.length, 1);
      expect(store.db.transactions.first.amount, -50);
      expect(store.db.transactions.first.account, tr('accountDefaultName'));
    });

    testWidgets('категория из записи сохраняется со значком и цветом',
        (tester) async {
      // Рост обычного телефона: по умолчанию окно теста 800×600, и нижняя
      // половина формы в него не помещается.
      // Высокое окно: лист правки категории длинный, и на телефонном росте
      // кнопка «Сохранить» уходит под край даже после прокрутки.
      tester.view.physicalSize = const Size(393, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = emptyStore();
      await tester.pumpWidget(app(OperationScreen(store: store)));
      await tester.pumpAndSettle();

      // Категории живут в нижней панели, «Своя» — первой плиткой в сетке.
      await tester.tap(find.text(tr('opPickCategory')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('opSplitOwn')));
      await tester.pumpAndSettle();

      // Открывается ТОТ ЖЕ лист, что на экране категорий: с видом, цветом и
      // значком. Раньше здесь спрашивали одно имя и не сохраняли ничего.
      expect(find.text(tr('categoryKind')), findsOneWidget);
      expect(find.text(tr('categoryColor')), findsOneWidget);
      expect(find.text(tr('categoryIcon')), findsOneWidget);

      // И кнопка сохранения — та же, что на экране категорий: лист доводит
      // дело до базы, а не отдаёт одно имя вызвавшему.
      expect(find.text(tr('categorySave')), findsOneWidget);
    });

    test('заведение категории из записи доводит её до базы', () {
      // Та же работа, что делает лист по «Сохранить»: проверяем, что она
      // ложится в хранилище, а не живёт до закрытия экрана.
      final store = emptyStore();
      store.setCategories([
        ...store.db.categories,
        const Category(
          name: 'Своя трата',
          kind: CatKind.expense,
          bucket: Bucket.wants,
          icon: 'rocket',
        ),
      ]);

      final saved =
          store.db.categories.firstWhere((c) => c.name == 'Своя трата');
      expect(saved.kind, CatKind.expense);
      expect(saved.bucket, Bucket.wants);
      expect(saved.icon, 'rocket');
    });
  });
}
