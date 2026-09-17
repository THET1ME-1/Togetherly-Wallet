import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/goals_screen.dart';
import 'package:togetherly_money/widgets/goal_vessel.dart';

import 'tm_fonts.dart';

/// Целей бывает много. Сосуд красив на трёх и превращает экран в бесконечную
/// ленту на двенадцати, поэтому его высоту задаёт длина списка.

Database withGoals(int count) => Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      goals: [
        for (var i = 1; i <= count; i++)
          Goal(name: 'Цель $i', target: 1000.0 * i, currency: 'MDL'),
      ],
    );

Future<void> openGoals(
  WidgetTester tester,
  int count, {
  double width = 393,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final store = Store()..importBackupForTest(withGoals(count));
  await tester.pumpWidget(MaterialApp(
    theme: MoneyTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: GoalsScreen(store: store),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 1400));
}

double vesselHeight(WidgetTester tester) =>
    tester.widgetList<GoalVessel>(find.byType(GoalVessel)).first.height;

void main() {
  setUpAll(loadTmFonts);

  testWidgets('Три цели — сосуд во весь рост', (tester) async {
    await openGoals(tester, 3);

    expect(vesselHeight(tester), 84);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Шесть целей — сосуд ниже', (tester) async {
    await openGoals(tester, 6);

    expect(vesselHeight(tester), 66);
  });

  testWidgets('Двенадцать целей — самый тесный сосуд', (tester) async {
    await openGoals(tester, 12);

    expect(vesselHeight(tester), 54);
  });

  testWidgets('Тесный сосуд не переполняется на 320 dp при шрифте 1.3',
      (tester) async {
    await openGoals(tester, 12, width: 320, textScale: 1.3);

    expect(tester.takeException(), isNull,
        reason: 'подпись и процент обязаны помещаться в ужатый сосуд');
  });

  testWidgets('Список целей прокручивается целиком', (tester) async {
    await openGoals(tester, 12);

    await tester.scrollUntilVisible(
      find.text('Цель 12'),
      400,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Цель 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
