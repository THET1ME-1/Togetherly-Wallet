import 'package:flutter/material.dart';

import '../theme/tm_colors.dart';
import '../theme/tm_scheme.dart';
import '../theme/tm_text.dart';
import '../theme/tm_tokens.dart';
import '../../design/accents.dart' show labelColors;

/// Плоская поверхность: заливка + граница 1px. Тени запрещены.
class TmSurface extends StatelessWidget {
  const TmSurface({
    super.key,
    required this.child,
    this.color,
    this.radius = TmRadius.card,
    this.padding = const EdgeInsets.all(TmSpace.l),
    this.border,
  });

  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsets padding;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tm.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(border ?? BorderSide(color: tm.line)),
      ),
      child: child,
    );
  }
}

/// Служебный заголовок группы («ОБЩИЕ», «СЕГОДНЯ · −3 260 ₽»).
class TmGroupLabel extends StatelessWidget {
  const TmGroupLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TmText.eyebrow(color ?? context.tm.textAlpha(0.5)));
}

/// Кнопка. variant задаёт смысл, а не просто цвет.
enum TmButtonVariant { shared, personal, ink, outline, quiet, danger }

enum TmButtonSize { small, medium, large }

class TmButton extends StatelessWidget {
  const TmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TmButtonVariant.shared,
    this.size = TmButtonSize.medium,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TmButtonVariant variant;
  final TmButtonSize size;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final (bg, fg, side) = switch (variant) {
      TmButtonVariant.shared => (context.tm.accent, context.tm.onAccent, null),
      TmButtonVariant.personal => (context.tm.accent, context.tm.onAccent, null),
      TmButtonVariant.ink => (tm.dark ? tm.field : TmColors.ink, tm.onDark, null),
      TmButtonVariant.outline => (
          const Color(0x00000000),
          tm.text,
          BorderSide(color: tm.textAlpha(0.22), width: 1.5),
        ),
      TmButtonVariant.quiet => (tm.field, tm.textAlpha(0.8), null),
      TmButtonVariant.danger => (
          const Color(0x00000000),
          tm.dark ? context.tm.expense : context.tm.expense,
          BorderSide(color: tm.dark ? context.tm.expense : context.tm.expense, width: 1.5),
        ),
    };

    final (h, fs, padH) = switch (size) {
      TmButtonSize.small => (44.0, 13.0, 18.0),
      TmButtonSize.medium => (48.0, 15.0, 26.0),
      TmButtonSize.large => (56.0, 16.0, 32.0),
    };

    final button = Material(
      color: bg,
      shape: StadiumBorder(side: side ?? BorderSide.none),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Container(
          height: h,
          padding: EdgeInsets.symmetric(horizontal: padH),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TmText.button(onPressed == null ? fg.withValues(alpha: 0.35) : fg)
                .copyWith(fontSize: fs),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Круглое действие с карты баланса (+, ↓, ₽, ⋯).
/// Размер никогда не опускается ниже [kTmMinTap].
class TmRoundAction extends StatelessWidget {
  const TmRoundAction({
    super.key,
    required this.icon,
    this.onTap,
    this.bg,
    this.fg,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? bg;
  final Color? fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final side = size < kTmMinTap ? kTmMinTap : size;
    return Material(
      color: bg ?? TmColors.card,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: side,
          height: side,
          child: Icon(icon, size: 20, color: fg ?? TmColors.ink),
        ),
      ),
    );
  }
}

/// Чип. scope окрашивает по смыслу: общее / личное / нейтральное.
enum TmChipScope { shared, personal, neutral, income, expense, hidden }

class TmChip extends StatelessWidget {
  const TmChip(
    this.label, {
    super.key,
    this.scope = TmChipScope.neutral,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final TmChipScope scope;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;

    final (bg, fg) = switch (scope) {
      TmChipScope.shared => (context.tm.accent, context.tm.onAccent),
      TmChipScope.personal => (context.tm.accent, context.tm.onAccent),
      TmChipScope.income => (context.tm.field, context.tm.onAccent),
      TmChipScope.expense => (context.tm.field, context.tm.expense),
      TmChipScope.hidden => (context.tm.field, context.tm.text),
      TmChipScope.neutral =>
        selected ? (context.tm.accent, context.tm.onAccent) : (tm.field, tm.textAlpha(0.72)),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TmRadius.chip),
        // Палец бьёт по 44, а не по 39: правило kTmMinTap распространяется
        // и на собственные компоненты системы.
        child: Container(
          constraints: const BoxConstraints(minHeight: kTmMinTap),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          alignment: Alignment.center,
          child: Text(label, style: TmText.label(fg), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// Сегменты «Неделя / Месяц / Год», «Расход / Доход / Перевод».
class TmSegmented extends StatelessWidget {
  const TmSegmented({
    super.key,
    required this.items,
    required this.index,
    this.onChanged,
    this.activeColor,
  });

  final List<String> items;
  final int index;
  final ValueChanged<int>? onChanged;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    final active = activeColor;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tm.field,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged?.call(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: kTmMinTap,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i == index ? (active ?? tm.card) : const Color(0x00000000),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    items[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: i == index
                        ? TmText.label(
                            active == context.tm.accent
                                ? context.tm.onAccent
                                : (active == context.tm.accent ? context.tm.onAccent : tm.text),
                          ).copyWith(fontWeight: FontWeight.w600)
                        : TmText.label(tm.textAlpha(0.55)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Тумблер: включён — мята, выключен — приглушённый трек. Без свечения.
class TmToggle extends StatelessWidget {
  const TmToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onChanged?.call(!value),
        behavior: HitTestBehavior.opaque,
        // Сам тумблер 31 точка высотой, зона нажатия — 44.
        child: SizedBox(
          height: kTmMinTap,
          width: 52,
          child: Center(
            child: AnimatedContainer(
              duration: TmDur.tap,
              width: 52,
              height: 31,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? context.tm.accent : context.tm.track,
                borderRadius: BorderRadius.circular(TmRadius.pill),
              ),
              child: Container(
                width: 25,
                height: 25,
                decoration: const BoxDecoration(color: TmColors.card, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      );
}

/// Аватары пары: наложение −12px, обводка цветом фона.
class TmAvatar extends StatelessWidget {
  const TmAvatar({
    super.key,
    required this.initial,
    required this.color,
    this.size = 34,
    this.ringColor,
  });

  final String initial;
  final Color color;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: ringColor == null ? null : Border.all(color: ringColor!, width: 2),
        ),
        // Инициал лежит на пастельном кружке, поэтому цвет здесь постоянный
        // в обеих темах: кружок не меняется вместе с фоном экрана.
        child: Text(initial, style: TmText.rowTitle(TmColors.ink).copyWith(fontSize: size * 0.38)),
      );
}

class TmAvatarPair extends StatelessWidget {
  const TmAvatarPair({
    super.key,
    this.a = 'А',
    this.b = 'Л',
    this.colorA = const Color(0xFF1C1C1C),
    this.colorB = const Color(0xFF565656),
    this.size = 34,
    this.ringColor,
  });

  final String a, b;
  final Color colorA, colorB;
  final double size;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final ring = ringColor ?? Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      width: size * 2 - 11,
      height: size,
      child: Stack(children: [
        TmAvatar(initial: a, color: colorA, size: size, ringColor: ring),
        Positioned(left: size - 11, child: TmAvatar(initial: b, color: colorB, size: size, ringColor: ring)),
      ]),
    );
  }
}

/// Полоса долей: два цвета участников на нейтральном треке.
class TmShareBar extends StatelessWidget {
  const TmShareBar({super.key, required this.fractionA, required this.fractionB, this.height = 12});

  final double fractionA, fractionB;
  final double height;

  @override
  Widget build(BuildContext context) {
    final rest = (1 - fractionA - fractionB).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TmRadius.pill),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: context.tm.track,
          child: Row(children: [
            Expanded(flex: (fractionA * 1000).round(), child: ColoredBox(color: labelColors[0])),
            Expanded(flex: (fractionB * 1000).round(), child: ColoredBox(color: labelColors[4])),
            Expanded(flex: (rest * 1000).round(), child: const SizedBox.shrink()),
          ]),
        ),
      ),
    );
  }
}
