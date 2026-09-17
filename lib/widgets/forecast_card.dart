import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/forecast.dart';
import 'money_text.dart';
import 'month_runway.dart';

/// Прогноз конца месяца на главной.
///
/// Показывается ТОЛЬКО подписчику. Закрытый вид — число под точками и лента
/// под ним — был сделан и выброшен в тот же день: «мне не нравится, как это
/// сделано» (17.09.2026). Заглушка на главной занимает место и не отвечает
/// ни на один вопрос, а про сам прогноз человек читает на витрине.
///
/// Считает `logic/forecast.dart` на устройстве: модель тут не нужна, а гонять
/// деньги пары на сервер ради арифметики незачем.
class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.forecast,
    required this.currency,
    this.now,
  });

  final Forecast forecast;
  final String currency;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = now ?? DateTime.now();
    final short = forecast.short;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                short ? tr('forecastShortTitle') : tr('forecastTitle'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              MoneyText(
                forecast.left,
                currency: currency,
                size: 27,
                weight: FontWeight.w800,
                color: short ? scheme.error : scheme.onSurface,
              ),
              const SizedBox(height: 2),
              Text(
                trf('forecastAtPace', [formatMoney(forecast.perDay, currency)]),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              MonthRunway(forecast: forecast, now: today),
              // Что именно не сойдётся. Две строки — потолок: третья
              // превращает карточку в список тревог, а их читают через одну.
              ...[
                for (final line in _troubles(currency).take(2)) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Myna.dangerCircle,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ]),
                ],
              ],
            ],
          ),
        ),
      );
  }

  /// Чего не хватит: сперва платежи, потом бюджеты. Платёж важнее — его
  /// пропуск стоит пени, а кончившийся бюджет стоит неудобства.
  List<String> _troubles(String currency) => [
        for (final d in forecast.due)
          trf('forecastDueOn',
              [d.name, '${d.day}', formatMoney(d.amount, currency)]),
        for (final d in forecast.drying)
          trf('forecastDrying', [d.category, '${d.day}']),
      ];
}
