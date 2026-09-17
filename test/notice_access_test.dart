import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/notices_screen.dart';
import 'package:togetherly_money/services/notices.dart';

import 'tm_fonts.dart';

/// Экран «Уведомления банков» обязан различать ТРИ причины тишины.
///
/// Человек видит их одинаково — трат нет, — а чинятся они по-разному: доступ
/// не выдан, доступ выдан и служба не поднялась, служба работает и до неё
/// ничего не доходит. Пока экран знал два состояния, разговор шёл вслепую:
/// «Я скачивал с нуля. Все включено, а не работает» (14.09.2026).

Store storeOf() => Store()
  ..importBackupForTest(const Database(
    baseCurrency: 'MDL',
    accounts: [Account(name: 'Карта Salut', currency: 'MDL', last4: '1234')],
  ));

Widget app(Store store, Notices notices) => MaterialApp(
      theme: MoneyTheme.light(),
      home: NoticesScreen(store: store, notices: notices),
    );

Notices serviceIn(NoticeState state, Store store) =>
    Notices(store)..setStateForTest(state);

Future<void> openScreen(WidgetTester tester, NoticeState state) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = storeOf();
  await tester.pumpWidget(app(store, serviceIn(state, store)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTmFonts);

  group('состояние службы', () {
    test('доступ без связи — это сон, а не отказ', () {
      const asleep = NoticeState(granted: true);
      expect(asleep.asleep, isTrue);
      expect(const NoticeState(granted: true, connected: true).asleep, isFalse);
      expect(const NoticeState().asleep, isFalse,
          reason: 'без разрешения будить нечего');
    });
  });

  group('экран', () {
    testWidgets('без доступа говорит, что тумблеры бездействуют',
        (tester) async {
      await openScreen(tester, const NoticeState());

      expect(find.text(tr('noticesPermissionOnce')), findsOneWidget);
      expect(find.text(tr('noticesSwitchesIdle')), findsOneWidget,
          reason: 'включённый источник без доступа читается как «настроено»');
    });

    // Android 13 и выше не даёт включить доступ приложению не из магазина, и
    // переключатель в настройках серый. Пока экран об этом молчал, человек
    // винил приложение: «это запрещённые настройки, сначала надо подтвердить»
    // (15.09.2026).
    testWidgets('запрет Android объясняется шагами, а не просьбой повторить',
        (tester) async {
      await openScreen(tester, const NoticeState(restricted: true));

      expect(find.text(tr('noticesRestricted')), findsOneWidget);
      expect(find.text(tr('noticesRestrictedSteps')), findsOneWidget);
      expect(find.text(tr('noticesOpenAppInfo')), findsOneWidget);
      expect(find.text(tr('noticesPermissionOnce')), findsNothing,
          reason: 'сперва снять запрет, доступ выдаётся вторым шагом');
    });

    testWidgets('шаги видны и без признанного запрета', (tester) async {
      await openScreen(tester, const NoticeState());

      expect(find.text(tr('noticesRestrictedSteps')), findsOneWidget,
          reason: 'серый переключатель бывает и там, где система молчит');
    });

    testWidgets('спящая служба предлагает поднять себя, а не настройки',
        (tester) async {
      await openScreen(tester, const NoticeState(granted: true, seen: 12));

      expect(find.text(tr('noticesServiceAsleep')), findsOneWidget);
      expect(find.text(tr('noticesWakeService')), findsOneWidget);
      expect(find.text(tr('noticesPermissionOnce')), findsNothing,
          reason: 'разрешение выдано — второй раз его не просят');
    });

    testWidgets('живая служба без единого прихода винит прошивку',
        (tester) async {
      await openScreen(
        tester,
        const NoticeState(granted: true, connected: true),
      );

      expect(find.text(tr('noticesNothingArrives')), findsOneWidget);
      expect(find.text(tr('noticesAccessGranted')), findsNothing,
          reason: '«работает» при нулевом счёте — это и есть обман');
    });

    testWidgets('работающая служба показывает обычное «доступ выдан»',
        (tester) async {
      await openScreen(
        tester,
        const NoticeState(granted: true, connected: true, seen: 40),
      );

      expect(find.text(tr('noticesAccessGranted')), findsOneWidget);
      expect(find.text(tr('noticesNothingArrives')), findsNothing);
      expect(find.text(tr('noticesSwitchesIdle')), findsNothing);
    });
  });
}
