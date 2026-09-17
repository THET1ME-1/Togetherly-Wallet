import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/screens/notices_review_screen.dart';
import 'package:togetherly_money/screens/notices_screen.dart';

import 'tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Database sample() => const Database(
      baseCurrency: 'MDL',
      pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: [
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true, last4: '4568'),
        Account(name: 'Карта maib', currency: 'MDL', last4: '1234', owner: 'u_me'),
      ],
      categories: [Category(name: 'Продукты'), Category(name: 'Транспорт')],
    );

Store storeOf() {
  final store = Store()..importBackupForTest(sample());
  store.viewer = me.uid;
  return store;
}

ParsedNotice notice([String body = 'Achitare 300,00 MDL, card *1234, Linella']) =>
    parseNotice(
      package: 'md.maib.mobile',
      title: 'maib',
      body: body,
      at: DateTime.utc(2026, 9, 12, 14, 30).millisecondsSinceEpoch,
    );

/// Настройки чтения.
Widget app(Store store) => MaterialApp(
      theme: MoneyTheme.light(),
      home: NoticesScreen(store: store),
    );

/// Разбор списаний — отдельный экран.
Widget review(Store store) => MaterialApp(
      theme: MoneyTheme.light(),
      home: NoticesReviewScreen(store: store),
    );

void main() {
  setUpAll(loadTmFonts);

  group('экран уведомлений банков', () {
    testWidgets('говорит про Android честно, когда чтения нет', (tester) async {
      await tester.pumpWidget(app(storeOf()));
      await tester.pumpAndSettle();

      expect(find.text('Только на Android'), findsOne);
      expect(find.textContaining('На iPhone доступа к ним нет'), findsOne);
    });

    testWidgets('«Понятно» убирает объяснение навсегда', (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Понятно'));
      await tester.pumpAndSettle();

      expect(find.text('Только на Android'), findsNothing);
      expect(store.noticeHintDone, isTrue);

      // Возврат на экран объяснение не возвращает.
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();
      expect(find.text('Только на Android'), findsNothing);
    });

    testWidgets('разобранное списание видно с суммой, магазином и счётом',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      expect(find.text('Новые списания'), findsOne);
      expect(find.textContaining('300,00'), findsOne);
      expect(find.text('Linella'), findsOne);
      // Счёт подставлен по четырём цифрам, спрашивать не надо.
      expect(find.textContaining('Карта maib'), findsWidgets);
    });

    testWidgets('«Записать» создаёт операцию и убирает карточку', (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Записать'));
      await tester.pumpAndSettle();

      expect(store.db.transactions.single.amount, -300);
      expect(store.db.transactions.single.account, 'Карта maib');
      expect(store.pendingNotices, isEmpty);
      expect(find.text('Записать'), findsNothing);
    });

    testWidgets('«Не надо» убирает списание, ничего не записав', (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Не надо'));
      await tester.pumpAndSettle();

      expect(store.db.transactions, isEmpty);
      expect(store.pendingNotices, isEmpty);
    });

    testWidgets('счёт выбирается листом, если банк назвал чужую карту',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice('Achitare 300,00 MDL, card *7777, Darwin'));

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      // Пока счёт не выбран, записывать нечего.
      expect(find.text('Выберите счёт'), findsOne);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Записать'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Выберите счёт'));
      await tester.pumpAndSettle();
      expect(find.text('Куда записать'), findsOne);

      await tester.tap(find.textContaining('Общий кошелёк').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Записать'));
      await tester.pumpAndSettle();

      expect(store.db.transactions.single.account, 'Общий кошелёк');
      // Выбор запомнился: тот же банк с той же картой больше не спросит.
      expect(store.noticeAccounts[noticeKey('md.maib.mobile', '7777')],
          'Общий кошелёк');
    });

    testWidgets('категория из листа попадает в операцию и запоминается',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Без категории'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Продукты').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Записать'));
      await tester.pumpAndSettle();

      expect(store.db.transactions.single.category, 'Продукты');
      expect(store.noticeCategories['linella'], 'Продукты');
    });

    testWidgets('текст уведомления открывается по кнопке, а не лежит открытым',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('card *1234'), findsNothing);
      await tester.tap(find.byTooltip('Текст уведомления'));
      await tester.pumpAndSettle();
      expect(find.textContaining('card *1234'), findsOne);
    });

    testWidgets('пока источников нет, экран не показывает чужие банки',
        (tester) async {
      await tester.pumpWidget(app(storeOf()));
      await tester.pumpAndSettle();

      expect(find.text('Пока никого'), findsOne);
      expect(find.text('Кто присылает'.toUpperCase()), findsOne);
      // Двадцати четырёх банков, которых нет на телефоне, на экране не видно.
      expect(find.text('Victoriabank'), findsNothing);
      expect(find.text('Сбербанк'), findsNothing);
    });

    testWidgets('источник появляется сам после первого уведомления',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text('maib'), findsOne);
      expect(find.text('Пока никого'), findsNothing);
      // Счёт ещё не выбран человеком, и экран этого не скрывает.
      expect(find.text('Счёт спросим один раз'), findsOne);
    });

    testWidgets('режим источника переключается касанием пилюли', (tester) async {
      final store = storeOf();
      store.setSenderMode('md.maib.mobile', NoticeMode.ask);

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Спросить').first);
      await tester.pumpAndSettle();
      expect(store.modeOf('md.maib.mobile'), NoticeMode.auto);

      await tester.tap(find.text('Сразу').first);
      await tester.pumpAndSettle();
      expect(store.modeOf('md.maib.mobile'), NoticeMode.ask);
    });

    testWidgets('тумблер выключает источник целиком', (tester) async {
      final store = storeOf();
      store.setSenderMode('md.maib.mobile', NoticeMode.ask);

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(store.modeOf('md.maib.mobile'), NoticeMode.off);
      // Выключенному источнику режим не предлагается.
      expect(find.text('Спросить'), findsNothing);
    });

    testWidgets('запомненное можно забыть', (tester) async {
      final store = storeOf();
      store.addNotice(notice());
      store.acceptNotice(
        store.pendingNotices.first,
        account: 'Карта maib',
        category: 'Продукты',
      );

      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      // Куда ложатся траты — видно маршрутом «карта → счёт».
      expect(find.textContaining('•••• 1234'), findsWidgets);
      expect(find.text('Карта maib'), findsWidgets);

      expect(find.textContaining('Linella → Продукты'), findsOne);
      await tester.ensureVisible(find.byIcon(Myna.x).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Myna.x).first);
      await tester.pumpAndSettle();

      expect(store.noticeCategories, isEmpty);
    });

    testWidgets('поиск находит банк и позволяет его отключить заранее',
        (tester) async {
      final store = storeOf();
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Найти банк или кошелёк'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Найти банк или кошелёк'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Victoria');
      await tester.pumpAndSettle();

      expect(find.text('Victoriabank'), findsOne);
      expect(find.text('Сбербанк'), findsNothing);

      // Банки читаются с самого начала: поиск нужен, чтобы выключить лишний
      // или включить обратно, а не чтобы «завести» банк.
      expect(store.modeOf('md.victoriabank.vbmobile'), NoticeMode.ask);
      final row = find.byType(SwitchListTile);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(store.modeOf('md.victoriabank.vbmobile'), NoticeMode.off);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(store.modeOf('md.victoriabank.vbmobile'), NoticeMode.ask);
    });

    testWidgets('источник выбирается одной кнопкой', (tester) async {
      final store = storeOf();
      // Блок появляется, только если кошелёк ЕСТЬ НА ТЕЛЕФОНЕ. Раньше признаком
      // служила запись в настройках, и на экран лезли приложения, которых у
      // человека нет (13.09.2026).
      store.installedSenders = {'com.google.android.apps.walletnfcrel'};
      store.setSenderMode('com.google.android.apps.walletnfcrel', NoticeMode.off);
      store.setSenderMode('md.maib.mobile', NoticeMode.ask);
      await tester.pumpWidget(app(store));
      await tester.pumpAndSettle();

      expect(find.text('Платежи телефоном'.toUpperCase()), findsOne);
      await tester.ensureVisible(find.text('Оба'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Оба'));
      await tester.pumpAndSettle();

      expect(store.noticeSource, NoticeSource.both);
      expect(store.modeOf('com.google.android.apps.walletnfcrel'), NoticeMode.ask);
      expect(find.textContaining('Одну покупку дважды'), findsOne);

      await tester.ensureVisible(find.text('Кошелёк'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Кошелёк'));
      await tester.pumpAndSettle();

      expect(store.noticeSource, NoticeSource.wallet);
      expect(store.modeOf('md.maib.mobile'), NoticeMode.off);
    });

    testWidgets('двойник помечен, но записать даёт', (tester) async {
      final store = storeOf();
      store.saveOperation(const Transaction(
        id: 'hand',
        date: '2026-09-12',
        kind: TxKind.expense,
        account: 'Карта maib',
        currency: 'MDL',
        amount: -300,
        amountBase: -300,
        author: 'u_me',
        payer: 'u_me',
      ));
      store.addNotice(notice());

      await tester.pumpWidget(review(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('Похоже, эта трата уже записана'), findsOne);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Записать'),
      );
      expect(button.onPressed, isNotNull);
    });

    for (final mode in [Brightness.light, Brightness.dark]) {
      testWidgets('собирается на 320dp при шрифте 1.3, ${mode.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = storeOf();
        store.addNotice(notice('Achitare 12 345,67 MDL, card *1234, SUPERMARKET LINELLA CENTRU'));
        store.acceptNotice(store.pendingNotices.first,
            account: 'Карта maib', category: 'Продукты');
        store.addNotice(notice('Achitare 89,90 MDL, card *1234, Darwin'));

        for (final screen in [
          NoticesScreen(store: store),
          NoticesReviewScreen(store: store),
        ]) {
          await tester.pumpWidget(MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: MaterialApp(
              theme: mode == Brightness.dark ? MoneyTheme.dark() : MoneyTheme.light(),
              home: screen,
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  });

  group('главная', () {
    Widget homeApp(Store store, VoidCallback onNotices) => MaterialApp(
          theme: MoneyTheme.light(),
          // Scaffold как в приложении: без него нажимаемым частям карточек
          // не хватает материала-предка.
          home: Scaffold(
            body: HomeScreen(
            store: store,
            period: Period.month(DateTime(2026, 9, 12)),
            onPeriod: (_) {},
            onAccounts: () {},
            onBudgets: () {},
            onGoals: () {},
            onPlan: () {},
            onDebts: () {},
            onChat: () {},
            onSettings: () {},
              onDrill: (_, __, [period]) {},
              onNotices: onNotices,
            ),
          ),
        );

    testWidgets('без новых списаний карточки нет', (tester) async {
      await tester.pumpWidget(homeApp(storeOf(), () {}));
      await tester.pumpAndSettle();

      expect(find.textContaining('списани'), findsNothing);
    });

    testWidgets('новые списания видны на главной и открывают разбор',
        (tester) async {
      final store = storeOf();
      store.addNotice(notice());

      var opened = false;
      await tester.pumpWidget(homeApp(store, () => opened = true));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('1 новое списание'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('1 новое списание'), findsOne);
      await tester.tap(find.text('1 новое списание'));
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets('счёт списаний пишется по-русски', (tester) async {
      final store = storeOf();
      for (var i = 0; i < 3; i++) {
        store.addNotice(parseNotice(
          package: 'md.maib.mobile',
          title: 'maib',
          body: 'Achitare ${10 + i}0,00 MDL, card *1234, Linella',
          at: DateTime.utc(2026, 9, 12, 10 + i).millisecondsSinceEpoch,
        ));
      }

      await tester.pumpWidget(homeApp(store, () {}));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('3 новых списания'), 250,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('3 новых списания'), findsOne);
    });
  });
}
