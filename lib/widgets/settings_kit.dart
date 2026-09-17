import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';

/// Каркас настроек — тот же, что в Togetherly.
///
/// Заголовок секции капсом, дальше группа, где КАЖДЫЙ пункт лежит своим
/// блоком с зазором 4: внешние углы группы скруглены сильнее внутренних, и
/// раздел читается цельным, а строки при этом нажимаются по отдельности.
/// Одной карточкой со строками через разделитель настройки были до того — и
/// вид разъезжался, стоило добавить блок другого рода.
///
/// Money и Togetherly — одна экосистема, и настройки в них не должны
/// выглядеть двумя разными приложениями. Здесь повторён именно каркас, а
/// палитра остаётся своя: мята — общее, лаванда — личное.
class SettingsSection extends StatelessWidget {
  const SettingsSection(this.title, {super.key, this.icon, this.color, this.trailing});

  final String title;

  /// Что стоит у правого края заголовка. Сюда садится счёт до потолка
  /// (`PlusMeter`): человек читает заголовок раздела раньше, чем тянется к
  /// кнопке, и предупреждение на кнопке опоздало бы.
  final Widget? trailing;

  /// Значок секции: кегль 18, без подложки, цвет идёт за надписью. Подложка
  /// есть только у строк — у заголовков её не заводить.
  final IconData? icon;

  /// Цвет заголовка. По умолчанию акцент; у «опасных» секций — `error`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      title.toUpperCase(),
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color ?? scheme.primary,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 24, 8, 10),
      child: icon == null && trailing == null
          ? label
          : Row(children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color ?? scheme.primary),
                const SizedBox(width: 10),
              ],
              Expanded(child: label),
              if (trailing != null) trailing!,
            ]),
    );
  }
}

/// Группа настроек: каждый пункт — свой блок, разделённый зазором.
///
/// Форму блока задаёт его место в группе: первому большой верх, последнему
/// большой низ, средним малый радиус со всех сторон. Единственный пункт
/// скругляется целиком.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup(this.children, {super.key});

  final List<Widget> children;

  /// Внешние углы группы.
  static const double outerRadius = 28;

  /// Углы внутри группы: блоки читаются одним разделом, а не россыпью.
  static const double innerRadius = 8;

  /// Зазор между блоками — он же вместо разделителя.
  static const double gap = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const outer = Radius.circular(outerRadius);
    const inner = Radius.circular(innerRadius);

    // Растягивать обязательно: по умолчанию колонка центрирует детей, и блок
    // с сегментами получал ширину по содержимому — в группе он оказывался
    // заметно уже соседних строк.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: gap),
        Material(
          color: scheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.vertical(
            top: i == 0 ? outer : inner,
            bottom: i == children.length - 1 ? outer : inner,
          ),
          child: children[i],
        ),
      ],
    ]);
  }
}

/// Круглый чип-иконка в строке настроек.
class SettingsIconChip extends StatelessWidget {
  const SettingsIconChip(this.icon, {super.key, this.bg, this.fg});

  final IconData icon;
  final Color? bg;
  final Color? fg;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: fg ?? scheme.onSurface),
    );
  }
}

/// Строка настроек: чип-иконка, заголовок с подписью и трейлинг.
///
/// Трейлинг — обычно стрелка перехода или тумблер. У тумблеров задавать и
/// `onTap`, и `onChanged`: тап по всей строке должен переключать.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBg,
    this.iconFg,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconBg;
  final Color? iconFg;

  /// Цвет заголовка; у «опасных» строк — `error`.
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          SettingsIconChip(icon, bg: iconBg, fg: iconFg),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: titleColor ?? scheme.onSurface,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ]),
      ),
    );
  }
}

/// Блок настроек со своим содержимым: сегменты, поля, всё, что не строка.
/// Форму и фон берёт у группы, поэтому внутри остаётся только содержимое.
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: padding, child: child);
}

/// Поле ввода внутри блока настроек.
///
/// Обычный `TextField` рисует свою заливку и рамку — внутри блока это коробка
/// в коробке, и поле выглядит вставленным по ошибке. Здесь заливки нет: её
/// даёт сам блок.
class SettingsInput extends StatelessWidget {
  const SettingsInput({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.maxLength,
    this.autofocus = false,
    this.capitalize = true,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final int? maxLength;
  final bool autofocus;
  final bool capitalize;

  /// Поле только для чтения. Имя цели — ключ: по нему живёт её счёт, и
  /// переименование пришлось бы переносить вместе со всеми вкладами.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLength: maxLength,
      autofocus: autofocus,
      readOnly: !enabled,
      textCapitalization:
          capitalize ? TextCapitalization.sentences : TextCapitalization.none,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        hintText: hint,
        filled: false,
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// Стрелка перехода — чтобы не повторять её у каждой строки.
class SettingsChevron extends StatelessWidget {
  const SettingsChevron({super.key});

  @override
  Widget build(BuildContext context) => Icon(
        Myna.chevronRight,
        color: Theme.of(context).colorScheme.outline,
      );
}
