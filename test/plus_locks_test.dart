import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/design/myna.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/notices_screen.dart';
import 'package:togetherly_money/screens/plan_screen.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// Калитки на том, что уже было написано и раздавалось бесплатно.
///
/// Витрина обещала «планировать вперёд» и «записывать траты молча» платными, а
/// в приложении и то, и другое работало у всех (найдено 17.09.2026). Здесь
/// проверяется и обратное: закрывать лишнее нельзя. Прошлый месяц плана
/// остаётся открытым — это история человека, а не планирование; разбор
/// уведомлений с подтверждением тоже бесплатен, платит человек за молчаливую
/// запись.

Widget app(Widget home) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      home: home,
    );

PlusService plusOf({bool active = false}) => PlusService()
  ..setForTest(active
      ? PlusPass(
          until: DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
          source: PlusSource.play,
          checkedAt: DateTime.now().millisecondsSinceEpoch,
        )
      : null);

String monthLabel(int shift) {
  final now = DateTime.now();
  final at = DateTime(now.year, now.month + shift);
  return Period.month(at).label;
}

void main() {
  setUpAll(loadTmFonts);

  group('план вперёд', () {
    testWidgets('без подписки следующий месяц закрыт стеной', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(PlanScreen(store: Store(), plus: plusOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.chevronRight));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsOneWidget);

      // Витрину закрыли, не купив: месяц обязан остаться прежним. Калитка
      // стоит ПЕРЕД действием, а не после — человек не должен обнаружить,
      // что уехал в октябрь, которого ему не открывали.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(monthLabel(0)), findsOneWidget);
      expect(find.text(monthLabel(1)), findsNothing);
    });

    testWidgets('прошлый месяц открыт всем: это история', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(PlanScreen(store: Store(), plus: plusOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.chevronLeft));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing);
      expect(find.text(monthLabel(-1)), findsOneWidget);
    });

    testWidgets('с подпиской вперёд открывается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
          app(PlanScreen(store: Store(), plus: plusOf(active: true))));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Myna.chevronRight));
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing);
      expect(find.text(monthLabel(1)), findsOneWidget);
    });
  });

  group('записывать молча', () {
    Store storeWithSender() {
      final store = Store();
      store.setSenderMode('md.maib.mobile', NoticeMode.ask);
      return store;
    }

    testWidgets('без подписки авторежим не включается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeWithSender();
      await tester
          .pumpWidget(app(NoticesScreen(store: store, plus: plusOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('noticesModeAsk')).first);
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsOneWidget);
      expect(store.senders['md.maib.mobile'], NoticeMode.ask);
    });

    testWidgets('с подпиской включается', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = storeWithSender();
      await tester.pumpWidget(
          app(NoticesScreen(store: store, plus: plusOf(active: true))));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('noticesModeAsk')).first);
      await tester.pumpAndSettle();

      expect(store.senders['md.maib.mobile'], NoticeMode.auto);
    });

    testWidgets('обратно в «Спросить» пускают без подписки', (tester) async {
      // Платное — молчаливая запись, а не возврат к подтверждению. Запирать
      // выход из платного значит держать человека в нём силой.
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = Store();
      store.setSenderMode('md.maib.mobile', NoticeMode.auto);
      await tester
          .pumpWidget(app(NoticesScreen(store: store, plus: plusOf())));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tr('noticesModeAuto')).first);
      await tester.pumpAndSettle();

      expect(find.byType(PlusScreen), findsNothing);
      expect(store.senders['md.maib.mobile'], NoticeMode.ask);
    });
  });
}
