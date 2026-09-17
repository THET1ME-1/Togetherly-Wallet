import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../l10n/language.dart';
import '../l10n/strings.dart';
import '../services/locale.dart';
import 'app_sheet.dart';
import '../design/myna.dart';

/// Выбор языка приложения.
///
/// Первым пунктом стоит «Как в системе»: человек, сменивший язык телефона,
/// ждёт того же и здесь, а выбор руками нужен тем, у кого телефон говорит не
/// на их языке.
///
/// Языки без перевода показываются честно — с пометкой, что часть текста
/// останется английской. Молча отдавать английский там, где человек выбрал
/// немецкий, хуже, чем сказать это прямо.
Future<void> showLanguageSheet(BuildContext context, AppLocale locale) =>
    showMoneySheet<void>(
      context,
      builder: (context) => _LanguageSheet(locale: locale),
    );

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.locale});

  final AppLocale locale;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  late MoneyLanguage? _picked = widget.locale.chosen;

  /// Языки, у которых перевод есть целиком. Остальные пока откатываются на
  /// английский — это заготовки.
  static const _ready = {MoneyLanguage.ru, MoneyLanguage.en};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SheetScaffold(
      icon: Myna.globe,
      title: tr('languageSheetTitle'),
      text: tr('languageSheetText'),
      action: tr('languageChoose'),
      onAction: () {
        widget.locale.choose(_picked);
        Navigator.of(context).pop();
      },
      child: Column(children: [
        _Row(
          title: tr('languageSystem'),
          note: MoneyLanguage.detect(
            View.of(context).platformDispatcher.locale,
          ).label,
          on: _picked == null,
          onTap: () => setState(() => _picked = null),
        ),
        for (final lang in MoneyLanguage.values)
          _Row(
            title: lang.label,
            note: _ready.contains(lang) ? null : 'English where not translated',
            on: _picked == lang,
            onTap: () => setState(() => _picked = lang),
          ),
        const SizedBox(height: 4),
        Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.on,
    required this.onTap,
    this.note,
  });

  final String title;
  final String? note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: on ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                      color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note!,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        color: on
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.8)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (on)
              Icon(Myna.check, color: scheme.onPrimaryContainer),
          ]),
        ),
      ),
    );
  }
}
