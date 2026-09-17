import 'package:flutter/material.dart';

import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../l10n/strings.dart';
import '../logic/stats.dart';
import 'icon_scatter.dart';

/// Кварталы: площадь прямоугольника и есть сумма.
///
/// Кольцо отвечает на «сколько частей», а кварталы — на «сколько денег»:
/// продукты, съевшие половину месяца, занимают половину карточки и молчать об
/// этом не могут. Сумма внутри квартала стоит крупно — её читают первой, а
/// название уже вторым.
///
/// Раскладка режет прямоугольник попеременно вдоль и поперёк: точный squarified
/// treemap для четырёх-шести кварталов выигрыша не даёт, а кода просит втрое
/// больше.
class Quarters extends StatelessWidget {
  const Quarters({
    super.key,
    required this.slices,
    required this.currency,
    this.height = 188,
    this.onTapSlice,
    this.colorOf,
    this.iconsOf,
  });

  final List<CategorySlice> slices;
  final String currency;
  final double height;
  final ValueChanged<String>? onTapSlice;

  /// Цвет квартала. По умолчанию берётся по ПОРЯДКУ, а не по имени: цвет по
  /// хешу имени давал двум соседним кварталам один оттенок, и карточка
  /// выглядела поломанной.
  final Color Function(CategorySlice slice, int index)? colorOf;

  /// Знаки для ассорти на фоне квартала. Обычно это значки подкатегорий: у
  /// продуктов свои у кофе, аптеки и рынка, и ассорти из разных знаков живее
  /// одного повторённого.
  final List<IconData> Function(CategorySlice slice)? iconsOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = slices.where((s) => s.sum.abs() > 0).toList();
    if (shown.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            tr('nothingToStack'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final total = shown.fold<double>(0, (sum, s) => sum + s.sum.abs());

    return LayoutBuilder(
      builder: (context, box) {
        final rects = _layout(shown, total, box.maxWidth, height);
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (final r in rects)
                AnimatedPositioned(
                  key: ValueKey(r.slice.name),
                  duration: const Duration(milliseconds: 520),
                  curve: AppTheme.emphasizedDecelerate,
                  left: r.left,
                  top: r.top,
                  width: r.width,
                  height: r.height,
                  child: _Quarter(
                    slice: r.slice,
                    currency: currency,
                    width: r.width,
                    height: r.height,
                    color: (colorOf ?? _paletteColor)(r.slice, r.index),
                    icons: iconsOf?.call(r.slice) ?? [categoryIcon(r.slice.name)],
                    onTap: onTapSlice == null ? null : () => onTapSlice!(r.slice.name),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_Rect> _layout(List<CategorySlice> items, double total, double width, double height) {
    const gap = 4.0;
    final out = <_Rect>[];
    var x = 0.0, y = 0.0, w = width, h = height, rest = total;
    var horizontal = true;

    for (var i = 0; i < items.length; i++) {
      final slice = items[i];
      final last = i == items.length - 1;
      final part = last || rest <= 0 ? 1.0 : slice.sum.abs() / rest;

      if (horizontal) {
        final bw = w * part;
        out.add(_Rect(slice, i, x + gap / 2, y + gap / 2, bw - gap, h - gap));
        x += bw;
        w -= bw;
      } else {
        final bh = h * part;
        out.add(_Rect(slice, i, x + gap / 2, y + gap / 2, w - gap, bh - gap));
        y += bh;
        h -= bh;
      }
      rest -= slice.sum.abs();
      horizontal = !horizontal;
    }
    return out;
  }
}

/// Цвет по порядку: соседние кварталы всегда разные.
Color _paletteColor(CategorySlice slice, int index) =>
    labelColors[index % labelColors.length];

class _Rect {
  const _Rect(this.slice, this.index, this.left, this.top, this.width, this.height);

  final CategorySlice slice;
  final int index;
  final double left;
  final double top;
  final double width;
  final double height;
}

class _Quarter extends StatelessWidget {
  const _Quarter({
    required this.slice,
    required this.currency,
    required this.width,
    required this.height,
    required this.color,
    required this.icons,
    this.onTap,
  });

  final CategorySlice slice;
  final String currency;
  final double width;
  final double height;
  final Color color;
  final List<IconData> icons;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Тесный квартал получает только сумму: название в нём всё равно не
    // прочитать, а обрезанное слово выглядит поломкой.
    final tight = width < 92 || height < 56;
    final ink = inkOn(color);
    final money = formatAmount(slice.sum.abs(), decimals: 0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 420),
      curve: AppTheme.emphasizedDecelerate,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Ассорти из знаков категории и её подкатегорий: квартал узнаётся
        // раньше, чем прочитано название.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: IconScatterPainter(
                icons: icons,
                // Ассорти лежит по всей площади, включая низ под цифрой,
                // поэтому знаки бледные.
                color: ink.withValues(alpha: 0.13),
                seed: slice.name.hashCode,
              ),
            ),
          ),
        ),
        Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(tight ? 7 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!tight)
                  Text(
                    slice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: 0.75),
                    ),
                  ),
                // Сумма — главное в квартале, поэтому она крупная и тянется
                // под ширину: «2 480» читается раньше названия.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    money,
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: tight ? 15 : 22,
                      letterSpacing: -0.5,
                      height: 1.05,
                      color: ink,
                    ),
                  ),
                ),
                if (tight)
                  Text(
                    slice.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 10,
                      color: ink.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ]),
    );
  }
}

