import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../design/myna_search.dart';
import '../logic/currencies.dart';
import '../logic/icons.dart';
import '../logic/period.dart';
import '../screens/currency_pick_screen.dart';
import 'icon_search_sheet.dart';
import 'settings_kit.dart';

/// Общие блоки форм бюджета, цели и регулярного платежа.
///
/// Требование человека 17.09.2026: «Бюджеты, цели, регулярные платежи должны
/// иметь общий шаблон добавления и редактирования. Регулярные будут чуть
/// обширнее». До этого три формы жили каждая своей жизнью: бюджет — экраном с
/// поиском категории и выбором валюты, цель — листом с полями в столбик и
/// ползунком, предложение лимита в паре — выпадающим списком без поиска. Одна
/// и та же вещь выглядела тремя разными, и чинить их приходилось по очереди:
/// валюту в цели завели через месяц после бюджета, а в предложении лимита не
/// завели вовсе.
///
/// Здесь лежат ЧАСТИ, а не готовая форма: у трёх сущностей разный набор полей,
/// и общий каркас с двадцатью флагами читался бы хуже трёх копий.

/// Имя, значок и цвет — «лицо» записи.
///
/// Одинаково у цели, бюджета и регулярного: человек узнаёт запись значком и
/// цветом раньше, чем читает имя. Пусто — значок и цвет подбираются по имени,
/// как у счёта и категории.
class EntryIdentity extends StatelessWidget {
  const EntryIdentity({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.onIcon,
    required this.onColor,
    this.hint,
    this.enabled = true,
    this.onChanged,
  });

  final TextEditingController name;
  final String? icon;
  final Color? color;
  final ValueChanged<String?> onIcon;
  final ValueChanged<Color?> onColor;
  final String? hint;

  /// Имя цели — ключ: по нему живёт её счёт, и переименование пришлось бы
  /// переносить вместе со всеми вкладами.
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = color ?? labelColorFor(name.text);
    return Column(
      children: [
        Row(
          children: [
            // Значок крупным квадратом слева от имени: он же стоит в списке, и
            // человек сразу видит, как запись будет выглядеть.
            InkWell(
              onTap: () async {
                final picked = await showIconSearch(context);
                if (picked != null) onIcon(picked.isEmpty ? null : picked);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: shown,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon == null
                      ? categoryIcon(name.text)
                      : (mynaByName[icon!] ?? categoryIcon(name.text)),
                  size: 27,
                  color: inkOn(shown),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SettingsInput(
                controller: name,
                hint: hint,
                onChanged: onChanged,
                enabled: enabled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Цвет — ряд с прокруткой, а не сетка: правило системы про строку с
        // пролистыванием старше этого виджета.
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            children: [
              _Swatch(
                color: null,
                on: color == null,
                onTap: () => onColor(null),
                child: Icon(
                  Myna.sparkles,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              for (final c in labelColors)
                _Swatch(
                  color: c,
                  on: color?.toARGB32() == c.toARGB32(),
                  onTap: () => onColor(c),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.on,
    required this.onTap,
    this.child,
  });

  final Color? color;
  final bool on;
  final VoidCallback onTap;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color ?? scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: on ? Border.all(color: scheme.onSurface, width: 2.5) : null,
          ),
          child:
              child ??
              (on ? Icon(Myna.check, size: 20, color: inkOn(color!)) : null),
        ),
      ),
    );
  }
}

/// Сменить валюту поиском по справочнику.
///
/// Одна дверь на все формы: выпадающий список из курсов показывал две строки,
/// MDL и USD, и запись в евро завести было нечем. Своя валюта, базовая и те,
/// что уже встречались, стоят первыми, остальные 95 — за поиском.
Future<String?> askCurrency(
  BuildContext context, {
  required Store store,
  required String current,
}) => pickCurrency(
  context,
  current: current,
  mine: <String>{
    current,
    store.db.baseCurrency,
    ...store.db.rates.keys,
    for (final a in store.db.accounts) a.currency,
  }.toList()..sort(),
);

/// Подпись валюты с флагом — «🇲🇩 MDL». Стоит там, где валюта нажимается.
String currencyLabel(String code) => '${flagOf(code)} $code';

/// Строка выбора: значок, что выбрано, шеврон. Категория, счёт, цель, долг —
/// всё выбирается одинаково.
class EntryPickRow extends StatelessWidget {
  const EntryPickRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconBg,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    iconBg: iconBg,
    iconFg: iconBg == null ? null : inkOn(iconBg!),
    title: title,
    subtitle: subtitle,
    trailing: const SettingsChevron(),
    onTap: onTap,
  );
}

/// Число барабаном: «каждые N дней», «N месяцев расходов».
///
/// Ползунок, стоявший у месяцев подушки, задавал число мимо всех остальных
/// форм и не давал набрать точное значение пальцем.
class EntryNumberRow extends StatelessWidget {
  const EntryNumberRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    trailing: Text(
      value,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    onTap: onTap,
  );
}

/// Дата для человека: «1 сентября 2026», а не «2026-09-01».
String humanDate(String? iso) {
  final at = DateTime.tryParse(iso ?? '');
  if (at == null) return tr('categoryPickNone');
  final head = '${at.day} ${monthOf(at.month)}';
  return at.year == DateTime.now().year ? head : '$head ${at.year}';
}
