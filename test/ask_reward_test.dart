import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/ask_screen.dart';
import 'package:togetherly_money/services/ads.dart';
import 'package:togetherly_money/services/plus.dart';
import 'package:togetherly_money/services/session.dart';

import 'tm_fonts.dart';

/// Ролик за вопрос.
///
/// В Togetherly это уже ломалось: человек смотрел рекламу, а монет не
/// получал. Поэтому здесь проверяется не «нарисовалась ли кнопка», а весь
/// путь: показ, поход на сервер за наградой и то, что после отказа сервера
/// приложение не выдаёт вопрос само.

/// Реклама, которой можно сказать, чем кончился показ.
class _FakeAds extends Ads {
  _FakeAds({required this.seen}) : super(plus: PlusService());

  /// Досмотрел ли человек ролик.
  final bool seen;
  int shown = 0;

  @override
  bool get show => true;

  @override
  Future<bool> showRewarded() async {
    shown++;
    return seen;
  }
}

Store storeOf() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Карта', currency: 'MDL')],
      categories: [Category(name: 'Продукты')],
    ));
  store.viewer = 'u_me';
  return store;
}

/// Сервер, у которого вопросы кончились. Награду отдаёт по [rewardOk].
({Session session, List<String> calls}) serverOutOfQuestions({
  bool rewardOk = true,
  int rewardLeft = 5,
}) {
  final calls = <String>[];
  final client = MockClient((req) async {
    calls.add(req.url.path);
    if (req.url.path.endsWith('/ask/reward')) {
      return http.Response(
        jsonEncode(rewardOk
            ? {'ok': true, 'left': 1, 'reward_left': rewardLeft - 1}
            : {'ok': false, 'error': 'day_limit', 'left': 0, 'reward_left': 0}),
        rewardOk ? 200 : 429,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      jsonEncode({
        'ok': false,
        'need_plus': true,
        'reward_left': rewardLeft,
        'message': 'Вопросы на сегодня кончились',
      }),
      402,
      headers: {'content-type': 'application/json'},
    );
  });
  return (session: Session(client: client), calls: calls);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> askAndFail(WidgetTester tester, Session session, Ads? ads) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: AskScreen(store: storeOf(), session: session, ads: ads),
  ));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).first, 'Сколько ушло на еду?');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await settle(tester);
}

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Вопросы кончились — предлагаем ролик, а не только подписку',
      (tester) async {
    final t = serverOutOfQuestions();
    await askAndFail(tester, t.session, _FakeAds(seen: true));

    expect(find.text(tr('askWatch')), findsOneWidget);
    expect(find.text(trf('askWatchLeft', ['5'])), findsOneWidget);
  });

  testWidgets('Досмотрел — приложение идёт за наградой на сервер',
      (tester) async {
    final t = serverOutOfQuestions();
    final ads = _FakeAds(seen: true);
    await askAndFail(tester, t.session, ads);

    await tester.tap(find.text(tr('askWatch')));
    await settle(tester);

    expect(ads.shown, 1);
    expect(t.calls.where((p) => p.endsWith('/ask/reward')).length, 1,
        reason: 'награду выдаёт сервер, а не телефон себе сам');
    // Вопрос открылся — кнопка ролика больше не нужна.
    expect(find.text(tr('askWatch')), findsNothing);
  });

  testWidgets('Ролик не досмотрен — на сервер не идём и вопрос не открываем',
      (tester) async {
    final t = serverOutOfQuestions();
    final ads = _FakeAds(seen: false);
    await askAndFail(tester, t.session, ads);

    await tester.tap(find.text(tr('askWatch')));
    await settle(tester);

    expect(ads.shown, 1);
    expect(t.calls.any((p) => p.endsWith('/ask/reward')), isFalse);
    expect(find.text(tr('askWatchFailed')), findsOneWidget);
  });

  testWidgets('Сервер сказал «хватит» — говорим это словами, а не молчим',
      (tester) async {
    final t = serverOutOfQuestions(rewardOk: false);
    await askAndFail(tester, t.session, _FakeAds(seen: true));

    await tester.tap(find.text(tr('askWatch')));
    await settle(tester);

    expect(find.text(tr('askWatchOut')), findsOneWidget);
    expect(find.text(tr('askWatch')), findsNothing,
        reason: 'роликов на сегодня нет, кнопка обязана исчезнуть');
  });

  testWidgets('Без рекламы кнопки нет вовсе', (tester) async {
    final t = serverOutOfQuestions();
    await askAndFail(tester, t.session, null);

    expect(find.text(tr('askNoMore')), findsOneWidget);
    expect(find.text(tr('askWatch')), findsNothing);
  });
}
