import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../l10n/strings.dart';
import '../logic/plus.dart';
import '../logic/plus_usage.dart';
import '../services/plus.dart';
import 'plus_dots.dart';
import 'plus_gate.dart';

/// Счёт до потолка рядом с заголовком раздела.
///
/// Правило человека 17.09.2026: где у платного есть число, человек видит счёт
/// ЗАРАНЕЕ, а не в момент отказа. Поэтому счётчик стоит у заголовка — там,
/// где глаз и так проходит, — а не на кнопке: кнопку читают уже с пальцем
/// над ней, и предупреждение в этот момент опаздывает.
///
/// У подписчика счётчика нет вовсе ([plusCount] отдаёт `null`): напоминать о
/// потолке, который человек снял деньгами, незачем.
class PlusMeter extends StatelessWidget {
  const PlusMeter({
    super.key,
    required this.gate,
    required this.count,
    this.plus,
  });

  final PlusGate gate;

  /// Счёт из [plusCount]. Пусто — не рисуем ничего.
  final PlusCount? count;

  final PlusService? plus;

  @override
  Widget build(BuildContext context) {
    final c = count;
    if (c == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // Заведено больше потолка — так живёт человек, у которого записи были до
    // появления подписки. Ряд остаётся длиной в потолок, лишнее говорится
    // числом: семь точек при потолке в пять читались бы как «потолка нет».
    final extra = c.have - c.limit;

    return Semantics(
      button: true,
      label: trf('plusMeterTaken', ['${c.have}', '${c.limit}']),
      child: InkWell(
        onTap: () => askPlus(context, plus: plus, gate: gate),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlusDots(have: c.have, limit: c.limit),
              if (extra > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '+$extra',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
