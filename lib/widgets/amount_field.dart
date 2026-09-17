import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../logic/currencies.dart';
import '../l10n/strings.dart';

/// Сумма крупно и по центру — главное число формы.
///
/// Раньше лимит и сумма регулярного вводились обычным полем в одну строку
/// среди прочих: число, ради которого человек зашёл, выглядело как «Название».
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.currency,
    this.hint,
    this.onChanged,
    this.onCurrency,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String currency;
  final String? hint;
  final ValueChanged<String>? onChanged;

  /// Сменить валюту. Пусто — валюта показана подписью и не нажимается: у
  /// операции она своя, у лимита и долга её раньше не выбирали вовсе.
  final VoidCallback? onCurrency;

  /// Клавиатура сразу: в листе вклада человек пришёл вводить сумму, и лишнее
  /// касание по полю тут ничего не решает.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: [
        if (onCurrency == null)
          Text(
            currency,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Material(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onCurrency,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(flagOf(currency), style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    currency,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Myna.chevronDown, size: 14, color: scheme.onSurfaceVariant),
                ]),
              ),
            ),
          ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
          decoration: InputDecoration(
            isDense: true,
            // Своя заливка у поля выключена: она рисовала коробку внутри
            // коробки, и сумма выглядела вставленной по ошибке.
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: hint ?? tr('amountZero'),
            hintStyle: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ]),
    );
  }
}
