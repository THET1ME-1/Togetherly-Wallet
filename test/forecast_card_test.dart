import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/logic/forecast.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/services/plus.dart';
import 'package:togetherly_money/widgets/forecast_card.dart';
import 'package:togetherly_money/widgets/money_text.dart';

import 'tm_fonts.dart';

/// Карточка прогноза на главной.
///
/// Решение: карточку видят ВСЕ, а закрыто только само число. Функция, о
/// которой человек не знает, не продаётся; но и показывать ответ бесплатно,
/// когда он обещан подпиской, нельзя.

Widget app(Widget home, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
      theme: MoneyTheme.light(),
      darkTheme: MoneyTheme.dark(),
      themeMode: mode,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(14), child: home)),
    );

PlusService plusOf({bool active = false}) => PlusService()
  ..setForTest(active
      ? PlusPass(
          until: DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
          source: PlusSource.play,
          checkedAt: DateTime.now().millisecondsSinceEpoch,
        )
      : null);

const forecast = Forecast(
  balance: 12000,
  perDay: 420,
  daysLeft: 13,
  spendAhead: 5460,
  due: [DuePayment(name: 'Аренда', amount: 4000, day: 28)],
  drying: [DryingBudget(category: 'Продукты', day: 24, left: 900)],
  ready: true,
);

void main() {
  setUpAll(loadTmFonts);

  testWidgets('видно число и чего не хватит', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(
        const ForecastCard(forecast: forecast, currency: 'MDL')));
    await tester.pumpAndSettle();

    // 12 000 − 5 460 − 4 000 = 2 540.
    expect(find.text(formatMoney(2540, 'MDL')), findsOneWidget);
    expect(find.textContaining('Аренда'), findsOneWidget);
  });

  for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('карточка собирается на 320 dp при шрифте 1.3, ${mode.name}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: app(
          const ForecastCard(forecast: forecast, currency: 'MDL'),
          mode: mode,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
