import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/accents.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import 'money_text.dart';

/// Денежный поток ВЕСАМИ: две полосы от общего нуля по одной шкале.
///
/// Три числа в столбик отвечали на «сколько», но не на «сколько это по
/// сравнению друг с другом»: месяц, где расход почти догнал доход, выглядел
/// так же, как месяц с десятикратным перевесом. Полосы считаются от одного
/// максимума, поэтому длина сравнима глазом — тот же приём, что у кварталов,
/// где площадь и есть сумма (выбран человеком 16.09.2026 из трёх макетов).
class FlowScale extends StatelessWidget {
  const FlowScale({
    super.key,
    required this.income,
    required this.expense,
    required this.total,
    required this.currency,
    this.onDrill,
  });

  final double income;

  /// Расход приходит положительным: знак в этом блоке несут цвет и сторона.
  final double expense;
  final double total;
  final String currency;

  /// Куда ведёт полоса: в ленту с этим разрезом. Число без возможности
  /// посмотреть, из чего оно, — тупик.
  final void Function(bool income)? onDrill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = [income.abs(), expense.abs()].reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        _Bar(
          // Ключ для проверок, не текст интерфейса: слово «Доход» на экране
          // встречается трижды, и в тесте строки иначе не различить.
          key: const ValueKey('flow-income'),
          icon: Myna.arrowUp,
          color: Money.up(context),
          name: tr('income'),
          value: income,
          share: top == 0 ? 0 : income.abs() / top,
          currency: currency,
          // Полосы наливаются по очереди: сперва приход, за ним расход. Обе
          // разом читаются как одна картинка, и сравнивать нечего.
          slot: const Interval(0, 0.72, curve: AppTheme.emphasizedDecelerate),
          onTap: onDrill == null ? null : () => onDrill!(true),
        ),
        const SizedBox(height: 14),
        _Bar(
          key: const ValueKey('flow-spending'),
          icon: Myna.arrowDown,
          color: Money.down(context),
          name: tr('spendings'),
          value: expense,
          share: top == 0 ? 0 : expense.abs() / top,
          currency: currency,
          slot: const Interval(0.22, 1, curve: AppTheme.emphasizedDecelerate),
          onTap: onDrill == null ? null : () => onDrill!(false),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        Row(
          children: [
            Text(
              tr('net'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: MoneyText(
                  total,
                  currency: currency,
                  size: 17,
                  colored: true,
                  weight: FontWeight.w800,
                  squeeze: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Одна сторона весов: подпись со стрелкой, сумма справа и полоса под ними.
class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.icon,
    required this.color,
    required this.name,
    required this.value,
    required this.share,
    required this.currency,
    required this.slot,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String name;
  final double value;
  final double share;
  final String currency;
  final Interval slot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Прошивка умеет выключать анимации целиком — тогда полоса просто стоит
    // на своём месте, а не дёргается мгновенным кадром.
    final still = MediaQuery.disableAnimationsOf(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Круг под стрелкой цветной: «цвет важен» (13.09.2026).
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Text(
              name,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 15,
                color: scheme.onSurface,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 8),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: MoneyText(
                  value,
                  currency: currency,
                  size: 15,
                  color: color,
                  squeeze: true,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Myna.chevronRight, size: 18, color: scheme.onSurfaceVariant),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            // Ширина задаётся ЯВНО: без неё стопка ужимается по самой
            // короткой полосе, и трек с заливкой пропадают вместе с ней.
            width: double.infinity,
            height: 22,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Пустой трек берёт линию, а не ступень поверхности: ступень
                // отличается от карточки на полтона и пропадает.
                ColoredBox(color: scheme.outline),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: still ? share : 0, end: share),
                  duration: Duration(milliseconds: still ? 0 : 900),
                  curve: slot,
                  builder: (context, v, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      // Ноль у полосы всё равно виден узкой засечкой: пустая
                      // строка в блоке читается как «данных нет», а не «нуль».
                      widthFactor: v.clamp(0.0, 1.0) * 0.994 + 0.006,
                      heightFactor: 1,
                      child: ColoredBox(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return body;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: body,
      ),
    );
  }
}
