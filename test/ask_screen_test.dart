import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/chat_log.dart';
import 'package:togetherly_money/screens/ask_screen.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/services/plus.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/logic/plus.dart';

import 'tm_fonts.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

Store storeOf({bool paired = false}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Продукты')],
      pair: paired
          ? const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL')
          : const Pair(),
    ));
  store.viewer = me.uid;
  return store;
}

/// Сессия на подставном транспорте: отвечает так же, как сервер, и помнит,
/// сколько раз её спросили.
({Session session, List<Map<String, dynamic>> asked}) fakeSession({
  String answer = 'На карте 8241,25 MDL',
  List<Map<String, dynamic>> actions = const [],
  int left = 2,
}) {
  final asked = <Map<String, dynamic>>[];
  final client = MockClient((req) async {
    asked.add((jsonDecode(req.body) as Map).cast<String, dynamic>());
    return http.Response(
      jsonEncode({'answer': answer, 'actions': actions, 'left': left}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (session: Session(client: client), asked: asked);
}

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: home,
    );

/// Ответ приходит мгновенно, но проходит через микрозадачи и анимацию
/// прокрутки: `pumpAndSettle` тут не годится — точки ожидания крутятся вечно.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void main() {
  setUpAll(loadTmFonts);

  group('разговор о деньгах', () {
    testWidgets('пустой экран зовёт и спросить, и записать', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final t = fakeSession();
      await tester.pumpWidget(app(AskScreen(store: storeOf(), session: t.session)));
      await tester.pumpAndSettle();

      expect(find.text(tr('askExampleFood')), findsOneWidget);
      // Чат ДЕЛАЕТ, а не только отвечает: без примера дела человек об этом
      // не догадается.
      expect(find.text(tr('askExampleAdd')), findsOneWidget);

      // Ряд ПРОКРУЧИВАЕТСЯ: дальние примеры не потеряны, они за краем.
      await tester.drag(find.text(tr('askExampleAdd')), const Offset(-260, 0));
      await tester.pumpAndSettle();
      expect(find.text(tr('askExampleFile')), findsOneWidget);
    });

    testWidgets('подсказки лежат рядом с прокруткой, а не столбиком',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final t = fakeSession();
      await tester.pumpWidget(app(AskScreen(store: storeOf(), session: t.session)));
      await tester.pumpAndSettle();

      final rows = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((v) => v.scrollDirection == Axis.horizontal)
          .length;
      expect(rows, 2, reason: 'две группы подсказок, обе рядами');
    });

    testWidgets('пустое поле не отправляется, набранное — уходит',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final t = fakeSession();
      await tester.pumpWidget(app(AskScreen(store: storeOf(), session: t.session)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);
      expect(t.asked, isEmpty, reason: 'отправлять нечего');

      await tester.enterText(find.byType(TextField), 'Сколько я трачу?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);

      expect(t.asked.single['question'], 'Сколько я трачу?');
      expect(find.text('На карте 8241,25 MDL'), findsOneWidget);
    });

    testWidgets('сделанное стоит блоком под ответом', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeOf();
      final t = fakeSession(answer: 'Записал', actions: [
        {
          'do': 'add_transaction',
          'args': {
            'kind': 'expense',
            'amount': 150,
            'account': 'Карта',
            'category': 'Продукты',
          },
        },
      ]);
      await tester.pumpWidget(app(AskScreen(store: store, session: t.session)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Я потратил 150 на чипсы');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);

      expect(store.db.transactions.single.amount, -150);
      expect(find.text('Записал'), findsOneWidget);
      expect(find.text(tr('agentApplied')), findsOneWidget,
          reason: 'что сделано — отдельным блоком, а не строкой в пузыре');
    });

    testWidgets('у одиночки выбора контура нет, у пары есть', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final t = fakeSession();
      await tester.pumpWidget(app(AskScreen(store: storeOf(), session: t.session)));
      await tester.pumpAndSettle();
      expect(find.text(tr('askScopeShared')), findsNothing);

      await tester.pumpWidget(app(
        AskScreen(store: storeOf(paired: true), session: t.session),
      ));
      await tester.pumpAndSettle();
      expect(find.text(tr('askScopePersonal')), findsOneWidget);
      expect(find.text(tr('askScopeShared')), findsOneWidget);

      // Подписи человеческие: «личный контур» так никто не говорит.
      expect(find.textContaining('контур'), findsNothing);
    });

    testWidgets('переписка на месте после выхода с экрана', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final home = Directory.systemTemp.createTempSync('money-ask-');
      addTearDown(() => home.deleteSync(recursive: true));
      final log = ChatLog();
      // Настоящий файл читается ТОЛЬКО в runAsync: в фейковом времени
      // виджет-теста дисковый Future не завершается никогда, и тест виснет.
      await tester.runAsync(() => log.load(home));

      final t = fakeSession(answer: 'На карте 8241,25 MDL');
      await tester.pumpWidget(app(
        AskScreen(store: storeOf(), session: t.session, log: log),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Сколько на карте?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);
      expect(find.text('На карте 8241,25 MDL'), findsOneWidget);

      // Человек ушёл с экрана и вернулся: разговор продолжается, а не
      // начинается с чистого листа.
      await tester.pumpWidget(app(const SizedBox()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(app(
        AskScreen(store: storeOf(), session: t.session, log: log),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Сколько на карте?'), findsOneWidget);
      expect(find.text('На карте 8241,25 MDL'), findsOneWidget);
    });

    testWidgets('второй вопрос уходит вместе с прошлыми репликами',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final home = Directory.systemTemp.createTempSync('money-ask-');
      addTearDown(() => home.deleteSync(recursive: true));
      final log = ChatLog();
      // Настоящий файл читается ТОЛЬКО в runAsync: в фейковом времени
      // виджет-теста дисковый Future не завершается никогда, и тест виснет.
      await tester.runAsync(() => log.load(home));

      final t = fakeSession(answer: 'На еду 4 210 MDL');
      await tester.pumpWidget(app(
        AskScreen(store: storeOf(), session: t.session, log: log),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Сколько мы тратим на еду?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'А в прошлом месяце?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);

      expect(t.asked.first['history'], isNull, reason: 'первый вопрос сам по себе');
      final history = (t.asked.last['history'] as List).cast<Map>();
      expect(history.length, 2);
      expect(history.first['text'], 'Сколько мы тратим на еду?');
      expect(history.last['role'], 'assistant');
      expect(t.asked.last['question'], 'А в прошлом месяце?');
    });

    testWidgets('личный и общий чат помнят каждый своё', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final home = Directory.systemTemp.createTempSync('money-ask-');
      addTearDown(() => home.deleteSync(recursive: true));
      final log = ChatLog();
      // Настоящий файл читается ТОЛЬКО в runAsync: в фейковом времени
      // виджет-теста дисковый Future не завершается никогда, и тест виснет.
      await tester.runAsync(() => log.load(home));

      final t = fakeSession();
      await tester.pumpWidget(app(
        AskScreen(store: storeOf(paired: true), session: t.session, log: log),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Что с моей картой?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);
      expect(find.text('Что с моей картой?'), findsOneWidget);

      await tester.tap(find.text(tr('askScopeShared')));
      await tester.pumpAndSettle();
      expect(find.text('Что с моей картой?'), findsNothing,
          reason: 'личное не всплывает в общем чате');

      await tester.tap(find.text(tr('askScopePersonal')));
      await tester.pumpAndSettle();
      expect(find.text('Что с моей картой?'), findsOneWidget);
    });

    testWidgets('«Забыть переписку» стирает разговор и память', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final home = Directory.systemTemp.createTempSync('money-ask-');
      addTearDown(() => home.deleteSync(recursive: true));
      final log = ChatLog();
      // Настоящий файл читается ТОЛЬКО в runAsync: в фейковом времени
      // виджет-теста дисковый Future не завершается никогда, и тест виснет.
      await tester.runAsync(() => log.load(home));

      final t = fakeSession();
      await tester.pumpWidget(app(
        AskScreen(store: storeOf(), session: t.session, log: log),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Сколько на карте?');
      await tester.pump();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await settle(tester);

      await tester.tap(find.byIcon(Myna.trash));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr('askClearDo')));
      await tester.pumpAndSettle();

      expect(find.text('Сколько на карте?'), findsNothing);
      expect(log.of('u_me', 'personal'), isEmpty);
      expect(find.text(tr('askExampleFood')), findsOneWidget,
          reason: 'экран снова зовёт спросить');
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('чат собирается на 320dp при шрифте 1.3, ${mode.name}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final t = fakeSession();
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(
            AskScreen(store: storeOf(paired: true), session: t.session),
            mode: mode,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.enterText(find.byType(TextField), 'Хватит ли до конца месяца?');
        await tester.pump();
        await tester.tap(find.byIcon(Myna.arrowUp));
        await settle(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('остаток вопросов виден ДО первого вопроса', (tester) async {
    // Число приезжает с талоном подписки при запуске приложения. Раньше чип
    // появлялся только после первого ответа, и человек, открывший чат,
    // своего потолка не видел вовсе (замечено человеком 17.09.2026).
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final t = fakeSession();
    final plus = PlusService()..asksLeft = 2;
    await tester.pumpWidget(app(AskScreen(
      store: storeOf(),
      session: t.session,
      plus: plus,
    )));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('/${PlusLimits.asksPerDay}'), findsOneWidget);
    expect(t.asked, isEmpty, reason: 'ни одного вопроса задано не было');
  });

  testWidgets('у подписчика счётчика нет', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final t = fakeSession();
    // Сервер отдаёт подписчику пустой остаток: потолка у него нет.
    final plus = PlusService()..asksLeft = null;
    await tester.pumpWidget(app(AskScreen(
      store: storeOf(),
      session: t.session,
      plus: plus,
    )));
    await tester.pumpAndSettle();

    expect(find.text('/${PlusLimits.asksPerDay}'), findsNothing);
  });

}
