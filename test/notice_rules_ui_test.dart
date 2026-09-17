import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/notice_rules.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/notice_rules_screen.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// Экран своих правил разбора.
///
/// Движок правил был написан и покрыт тестами ещё в июле, а завести правило
/// человек не мог ничем: экрана не существовало, и `store.plusActive` никто не
/// выставлял. То есть функция, обещанная витриной платной, не работала и у
/// подписчика (17.09.2026).

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
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

Store storeWith(List<NoticeRule> rules) {
  final store = Store();
  for (final r in rules.reversed) {
    store.saveNoticeRule(r);
  }
  return store;
}

NoticeRule wolt() => const NoticeRule(
      id: 'wolt',
      when: NoticeWhen(merchant: 'wolt', weekdays: {1, 2, 3, 4, 5}),
      act: NoticeDo.record,
      category: 'Еда вне дома',
      split: SplitMode.equal,
    );

NoticeRule big() => const NoticeRule(
      id: 'big',
      when: NoticeWhen(min: 2000),
      act: NoticeDo.ask,
    );

void main() {
  setUpAll(loadTmFonts);

  testWidgets('правила видны списком и узнаются по условию', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(NoticeRulesScreen(
      store: storeWith([wolt(), big()]),
      plus: plusOf(active: true),
    )));
    await tester.pumpAndSettle();

    // Условие собрано словами: «wolt · пн, вт, ср, чт, пт».
    expect(find.textContaining('wolt'), findsOneWidget);
    expect(find.textContaining(tr('nruleFrom')), findsOneWidget);
    // И действие тоже: правило узнают взглядом, а не открывая его.
    expect(find.textContaining(tr('nruleDoRecord')), findsOneWidget);
    expect(find.textContaining(tr('nruleDoAsk')), findsOneWidget);
  });

  testWidgets('без подписки новое правило упирается в стену', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = Store();
    await tester.pumpWidget(
        app(NoticeRulesScreen(store: store, plus: plusOf())));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('nruleNew')).first);
    await tester.pumpAndSettle();

    expect(find.byType(PlusScreen), findsOneWidget);
    expect(store.noticeRules, isEmpty);
  });

  testWidgets('с подпиской правило заводится и доезжает до базы',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = Store();
    await tester.pumpWidget(
        app(NoticeRulesScreen(store: store, plus: plusOf(active: true))));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('nruleNew')).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Tucano');
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('nruleSave')));
    await tester.pumpAndSettle();

    expect(store.noticeRules, hasLength(1));
    expect(store.noticeRules.first.when.merchant, 'Tucano');
  });

  testWidgets('пустое условие не сохраняется', (tester) async {
    // Правило без условия подошло бы к ЛЮБОМУ уведомлению и молча съело бы
    // все остальные: `ruleFor` такие пропускает, и заводить их нельзя.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = Store();
    await tester.pumpWidget(
        app(NoticeRulesScreen(store: store, plus: plusOf(active: true))));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('nruleNew')).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr('nruleSave')));
    await tester.pumpAndSettle();

    expect(store.noticeRules, isEmpty);
    expect(find.text(tr('nruleNeedWhen')), findsOneWidget);
  });

  testWidgets('правило выключается, не исчезая из списка', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = storeWith([wolt()]);
    await tester.pumpWidget(
        app(NoticeRulesScreen(store: store, plus: plusOf(active: true))));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(store.noticeRules, hasLength(1));
    expect(store.noticeRules.first.on, isFalse);
  });

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('правила собираются на 320 dp при шрифте 1.3, ${mode.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(
          NoticeRulesScreen(
            store: storeWith([wolt(), big()]),
            plus: plusOf(active: true),
          ),
          mode: mode,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
