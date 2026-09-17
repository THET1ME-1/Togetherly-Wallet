import 'package:flutter/material.dart';

import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/money.dart';

/// Сумма с кодом валюты: «MDL 139,76». Код стоит впереди — так суммы в разных
/// валютах выстраиваются в колонку по левому краю и их легко сравнивать
/// глазом.
String formatMoney(
  double v,
  String currency, {
  int decimals = 2,
  bool sign = false,
}) =>
    // Пустая валюта — не привязанная к стране сумма (так живут демо-карты на
    // приветствии). Ведущий пробел в этом случае лишний.
    currency.isEmpty
    ? formatAmount(v, decimals: decimals, sign: sign)
    // Пробел между валютой и суммой НЕРАЗРЫВНЫЙ. С обычным «MDL 1 000,00»
    // — два слова, и в строке на одну строчку перенос уносил само число
    // за её край: на экране записи с суммой от тысячи оставалось «MDL», а
    // цифры пропадали (поймано человеком 14.09.2026). Разделитель тысяч
    // внутри числа неразрывен с самого начала — рвалось именно здесь.
    : '$currency\u00A0${formatAmount(v, decimals: decimals, sign: sign)}';

class MoneyText extends StatelessWidget {
  final double value;
  final String currency;
  final double size;
  final FontWeight weight;

  /// Красить по знаку: доход зелёным, расход красным. Там, где строка и так
  /// говорит о расходе, цвет лишний.
  final bool colored;
  final Color? color;
  final int decimals;
  final bool sign;

  /// Ужимать число, когда оно не влезает по ширине, вместо переноса.
  ///
  /// Включается там, где ширина ЗАДАНА родителем (`Expanded`, `Flexible`,
  /// колонка карточки): миллион на главной иначе ломался пополам посреди
  /// цифр — «MDL −1 091 40» и «4,45» следующей строкой. В ряду без заданной
  /// ширины ужатие само просит всю строку и переполняет её на 320 dp,
  /// поэтому по умолчанию выключено.
  final bool squeeze;

  const MoneyText(
    this.value, {
    super.key,
    required this.currency,
    this.size = 15,
    this.weight = FontWeight.w600,
    this.colored = false,
    this.color,
    this.decimals = 2,
    this.sign = false,
    this.squeeze = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint =
        color ??
        (colored ? Money.forAmount(context, value) : null) ??
        scheme.onSurface;
    final text = Text(
      formatMoney(value, currency, decimals: decimals, sign: sign),
      maxLines: squeeze ? 1 : null,
      softWrap: !squeeze,
      style: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: size,
        fontWeight: weight,
        letterSpacing: -0.2,
        color: tint,
        // Цифры одной ширины: без этого колонка сумм пляшет при пересчёте.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    return squeeze
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: text,
          )
        : text;
  }
}

/// Круглая метка категории или счёта: цветной кружок со значком внутри.
class LabelDot extends StatelessWidget {
  final String name;
  final IconData icon;
  final double size;
  final Color? color;

  const LabelDot({
    super.key,
    required this.name,
    required this.icon,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? labelColorFor(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: inkOn(bg)),
    );
  }
}

/// Сумма, которая НАБЕГАЕТ от прежнего значения к новому.
///
/// Нужна ровно там, где число — главное на экране и меняется по воле
/// человека: общий баланс при смене месяца или отборе счетов. Подмена цифры
/// рывком читается как перерисовка, а набег — как пересчёт: глаз успевает
/// заметить, в какую сторону поехали деньги.
///
/// Первый кадр рисуется сразу, без анимации: экран не должен открываться
/// нулями. При системном «меньше движения» набега нет вовсе.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney(
    this.value, {
    super.key,
    required this.currency,
    this.size = 15,
    this.weight = FontWeight.w600,
    this.colored = false,
    this.color,
    this.decimals = 2,
    this.sign = false,
    this.squeeze = false,
    this.duration = const Duration(milliseconds: 520),
  });

  final double value;
  final String currency;
  final double size;
  final FontWeight weight;
  final bool colored;
  final Color? color;
  final int decimals;
  final bool sign;
  final bool squeeze;
  final Duration duration;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> {
  late double _from = widget.value;

  @override
  void didUpdateWidget(AnimatedMoney old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _from = old.value;
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value),
      duration: still ? Duration.zero : widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => MoneyText(
        value,
        currency: widget.currency,
        size: widget.size,
        weight: widget.weight,
        colored: widget.colored,
        color: widget.color,
        decimals: widget.decimals,
        sign: widget.sign,
        squeeze: widget.squeeze,
      ),
    );
  }
}
