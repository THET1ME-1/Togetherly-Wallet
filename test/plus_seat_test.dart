import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/screens/plus_screen.dart';
import 'package:togetherly_money/services/plus.dart';

import 'tm_fonts.dart';

/// Второе место и три тарифа.
///
/// Подписка открывает Плюс ДВОИМ, и второго человека выбирают руками: пар у
/// человека бывает несколько, а в группе бывает трое и больше, и правило «одна
/// подписка на пару» без выбора раздавало бы Плюс всем («это абуз какой-то»,
/// 16.09.2026).

class _Fake extends PlusService {
  _Fake(this.pairs);

  final List<PlusSeat> pairs;

  @override
  Future<List<PlusSeat>> seats() async => pairs;
}

const lena = PlusSeat(
  groupId: 'g1',
  uid: 'u_lena',
  name: 'Лена',
  avatarUrl: '',
  size: 2,
  can: true,
);

const dacha = PlusSeat(
  groupId: 'g2',
  uid: '',
  name: '',
  avatarUrl: '',
  size: 3,
  can: false,
);

Future<void> openPlus(
  WidgetTester tester,
  PlusService plus, {
  Future<Map<PlusPlan, String>> Function()? prices,
}) async {
  tester.view.physicalSize = const Size(393, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: PlusScreen(plus: plus, prices: prices),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadTmFonts);

  group('тарифы', () {
    test('Выгода считается из цен, а не пишется руками', () {
      expect(plusSaving(PlusPlan.month), 0);
      expect(plusSaving(PlusPlan.quarter), 17);
      expect(plusSaving(PlusPlan.year), 43);
    });

    test('Три тарифа знают свою длину и своё имя на сервере', () {
      expect(PlusPlan.quarter.months, 3);
      expect(PlusPlan.year.code, 'year');
      expect(PlusPlan.byCode('quarter'), PlusPlan.quarter);
      expect(PlusPlan.byCode('пятилетка'), isNull);
    });

    testWidgets('Витрина показывает все три тарифа', (tester) async {
      await openPlus(tester, _Fake(const []));

      expect(find.text(tr('plusMonth')), findsOneWidget);
      expect(find.text(tr('plusQuarter')), findsOneWidget);
      expect(find.text(tr('plusYear')), findsOneWidget);
      expect(find.text(PlusPrice.rub.quarter), findsOneWidget);
    });
  });

  group('цены', () {
    testWidgets('Магазин назвал цену — показываем ЕГО, а не нашу',
        (tester) async {
      // В Польше или Казахстане Google покажет свою цену в своей валюте, и
      // наши «799 ₽» на кнопке были бы неправдой. Apple за расхождение
      // витрины с магазином отправляет на доработку.
      await openPlus(tester, _Fake(const []),
          prices: () async => {
                PlusPlan.month: '39,99 zł',
                PlusPlan.quarter: '99,99 zł',
                PlusPlan.year: '269,99 zł',
              });

      expect(find.text('39,99 zł'), findsOneWidget);
      expect(find.text('269,99 zł'), findsOneWidget);
      expect(find.text(PlusPrice.rub.month), findsNothing);
    });

    testWidgets('Магазин молчит — стоят наши цены', (tester) async {
      await openPlus(tester, _Fake(const []));

      expect(find.text(PlusPrice.rub.month), findsOneWidget);
      expect(find.text(PlusPrice.rub.year), findsOneWidget);
    });
  });

  group('второе место', () {
    testWidgets('Без пар блока нет: выбирать не из чего', (tester) async {
      await openPlus(tester, _Fake(const []));

      expect(find.text(tr('plusSeatTitle').toUpperCase()), findsNothing);
    });

    testWidgets('Пока место не отдано, так и написано', (tester) async {
      await openPlus(tester, _Fake(const [lena]));

      expect(find.text(tr('plusSeatTitle').toUpperCase()), findsOneWidget);
      expect(find.text(tr('plusSeatFree')), findsOneWidget);
      expect(find.text(tr('plusSeatNone')), findsWidgets);
    });

    testWidgets('Лист называет пары и объясняет отказ группе втроём',
        (tester) async {
      await openPlus(tester, _Fake(const [lena, dacha]));

      await tester.tap(find.text(tr('plusSeatFree')));
      await tester.pumpAndSettle();

      expect(find.text(tr('plusSeatPick')), findsOneWidget);
      expect(find.text('Лена'), findsOneWidget);
      expect(find.text(trf('plusSeatGroup', ['3'])), findsOneWidget,
          reason: 'серый пункт без причины читается как поломка');
      expect(find.text(tr('plusSeatOnlyMe')), findsOneWidget);
    });

    testWidgets('Выбранная пара встаёт в строку места', (tester) async {
      await openPlus(tester, _Fake(const [lena, dacha]));

      await tester.tap(find.text(tr('plusSeatFree')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Лена'));
      await tester.pumpAndSettle();

      expect(find.text('Лена'), findsOneWidget);
      expect(find.text(tr('plusSeatWith')), findsOneWidget);
      expect(find.text(tr('plusSeatFree')), findsNothing);
    });
  });
}
