import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/language.dart';
import '../l10n/strings.dart';
import '../logic/currencies.dart';
import '../logic/money.dart';
import '../ui/theme/tm_scheme.dart';

/// Конвертер: сумма, знак равенства, результат — и две валюты под ними с
/// круглой кнопкой обмена между ними.
///
/// Референс человека, 13.09.2026. Экран валюты до этого был столбиком пилюль
/// и полей: он показывал курсы, но не отвечал на вопрос, ради которого его
/// открывают, — «сколько это в моих деньгах».
///
/// Цвет мятный, плоский: ни градиента, ни тени — правило системы.
class ConverterCard extends StatelessWidget {
  const ConverterCard({
    super.key,
    required this.controller,
    required this.from,
    required this.to,
    required this.result,
    required this.onFrom,
    required this.onTo,
    required this.onSwap,
    required this.onChanged,
    this.note,
  });

  final TextEditingController controller;
  final String from;
  final String to;

  /// Уже пересчитанная сумма: считает экран, карточка только рисует.
  final double? result;

  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback onSwap;
  final ValueChanged<String> onChanged;

  /// Подпись под карточкой: курс словами.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Карточка — обычная поверхность, а не заливка акцентом: на тёмной теме
    // акцент белый, и конвертер светил в пол-экрана прожектором, а поле ввода
    // (белое с прозрачностью) в нём растворялось совсем.
    final ink = context.tm.text;

    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        decoration: BoxDecoration(
          color: context.tm.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.tm.line),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: context.tm.field,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '1',
                    hintStyle: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: ink.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '=',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ink.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  result == null ? '—' : formatAmount(result!),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _Side(code: from, onTap: onFrom)),
            const SizedBox(width: 56),
            Expanded(child: _Side(code: to, onTap: onTo, right: true)),
          ]),
        ]),
      ),
      // Кнопка обмена сидит НА стыке карточки и подписи, как в референсе:
      // она главное действие экрана после ввода суммы.
      Transform.translate(
        offset: const Offset(0, -26),
        child: Material(
          color: scheme.surfaceContainerLowest,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onSwap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: scheme.surfaceContainerLowest, width: 4),
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(Myna.arrowLeftRight, size: 24, color: scheme.onSurface),
            ),
          ),
        ),
      ),
      if (note != null)
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 6),
          child: Text(
            note!,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
    ]);
  }
}

/// Валюта под суммой: флаг, код и стрелка выбора.
class _Side extends StatelessWidget {
  const _Side({required this.code, required this.onTap, this.right = false});

  final String code;
  final VoidCallback onTap;
  final bool right;

  @override
  Widget build(BuildContext context) {
    // Карточка больше не залита акцентом, поэтому и подписи сторон берут
    // обычный текст: `onAccent` на ней стал графитом по графиту.
    final ink = context.tm.text;
    final russian = appLanguage == MoneyLanguage.ru;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              right ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(flagOf(code), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: right
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  Text(
                    currencyName(code, russian: russian),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 11,
                      color: ink.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Myna.chevronDown, size: 16, color: ink.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
