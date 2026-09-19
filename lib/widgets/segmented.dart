import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../logic/haptics.dart';

/// Выбор одного значения — РЯДОМ С ПРОКРУТКОЙ ВБОК.
///
/// Сеткой это было ровно полдня: «МЕНЯ ДОСТАЛО, ЧТО ТЫ ДЕЛАЕШЬ В СТОЛБИК, А НЕ
/// В СТРОКУ С ПРОЛИСТЫВАНИЕМ» (13.09.2026). Правило в проекте общее и старше
/// этого виджета: пилюли лежат одной строкой, а лишнее человек пролистывает
/// пальцем — десять счетов в `Wrap` занимали четыре строки и уносили кнопку
/// сохранения за экран.
class Segmented extends StatefulWidget {
  const Segmented({
    super.key,
    required this.titles,
    required this.index,
    required this.onPick,
    this.icons,
  });

  final List<String> titles;
  final int index;
  final ValueChanged<int> onPick;

  /// Значок перед словом — когда он есть, ряд читается с одного взгляда.
  final List<IconData>? icons;

  @override
  State<Segmented> createState() => _SegmentedState();
}

/// Выбранное отмечает подложка, которая ЕДЕТ к новой пилюле, а не прыгает.
///
/// Слоёв три: серые пилюли, цветная подложка выбранного, надписи. Надпись у
/// каждой пилюли одна (подложка без текста), поэтому поиск по слову в тестах и
/// чтение экрана не двоятся. Позиции пилюль меряются после раскладки: ширина у
/// них разная, а ряд прокручивается вбок. До первого замера пилюли красятся
/// сами — первый кадр выглядит так же, как раньше.
class _SegmentedState extends State<Segmented> {
  final _row = GlobalKey();
  List<GlobalKey> _keys = [];
  List<Rect>? _rects;

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.titles.length, (_) => GlobalKey());
  }

  @override
  void didUpdateWidget(covariant Segmented old) {
    super.didUpdateWidget(old);
    if (old.titles.length != widget.titles.length ||
        !_sameTitles(old.titles, widget.titles)) {
      _keys = List.generate(widget.titles.length, (_) => GlobalKey());
      _rects = null;
    }
  }

  static bool _sameTitles(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _measure() {
    if (!mounted) return;
    final box = _row.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final next = <Rect>[];
    for (final k in _keys) {
      final cell = k.currentContext?.findRenderObject() as RenderBox?;
      if (cell == null || !cell.hasSize) return;
      final at = cell.localToGlobal(Offset.zero, ancestor: box);
      next.add(at & cell.size);
    }
    final old = _rects;
    if (old != null && old.length == next.length) {
      var same = true;
      for (var i = 0; i < next.length; i++) {
        if ((old[i].left - next[i].left).abs() > 0.5 ||
            (old[i].width - next[i].width).abs() > 0.5) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    setState(() => _rects = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final rects = _rects;
    final measured = rects != null && rects.length == widget.titles.length;
    // Высота считается от шрифта: при системном увеличении пилюля вырастает,
    // и ряд обязан вырасти с ней, иначе текст обрежется (как в PickRow).
    final height =
        46 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final radius = BorderRadius.circular(16);
    final on = widget.index;

    final cells = Row(
      key: _row,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.titles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          SizedBox(
            height: height,
            child: _Cell(
              key: _keys[i],
              title: widget.titles[i],
              icon: widget.icons != null && i < widget.icons!.length
                  ? widget.icons![i]
                  : null,
              on: on == i,
              paintsFill: !measured,
              // Щелчок только на СМЕНЕ: отклик на повторное нажатие уже
              // выбранного обещает пальцу то, чего не произошло.
              onTap: () {
                if (widget.index != i) Tap.pick();
                widget.onPick(i);
              },
            ),
          ),
        ],
      ],
    );

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: !measured || on < 0 || on >= rects.length
            ? cells
            : TweenAnimationBuilder<Rect?>(
                tween: RectTween(end: rects[on]),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: AppTheme.emphasized,
                child: cells,
                builder: (context, r, child) {
                  final pill = r ?? rects[on];
                  return Stack(
                    children: [
                      for (final g in rects)
                        Positioned.fromRect(
                          rect: g,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: radius,
                            ),
                          ),
                        ),
                      Positioned.fromRect(
                        rect: pill,
                        child: DecoratedBox(
                          key: const ValueKey('segmented-pill'),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: radius,
                          ),
                        ),
                      ),
                      // Буквы красятся по месту: над подложкой — цветом
                      // выбранного, вне её — обычным. Пока подложка едет,
                      // граница цвета идёт вместе с ней, и соседнее слово не
                      // пропадает под ней (белое на белом в тёмной теме).
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          final w = bounds.width <= 0 ? 1.0 : bounds.width;
                          final a = (pill.left / w).clamp(0.0, 1.0);
                          final b = (pill.right / w).clamp(0.0, 1.0);
                          final off = scheme.onSurface;
                          final onInk = scheme.onSecondaryContainer;
                          return LinearGradient(
                            colors: [off, off, onInk, onInk, off, off],
                            stops: [0, a, a, b, b, 1],
                          ).createShader(bounds);
                        },
                        child: child,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.title,
    required this.on,
    required this.onTap,
    required this.paintsFill,
    this.icon,
  });

  final String title;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;

  /// До замера позиций пилюля красит себя сама; после — заливку рисуют слои
  /// под ней, а цвет букв задаёт маска над подложкой.
  final bool paintsFill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = on ? scheme.onSecondaryContainer : scheme.onSurface;
    return Material(
      color: paintsFill
          ? (on ? scheme.secondaryContainer : scheme.surfaceContainerHighest)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 17,
                    color: on ? ink : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14.5,
                    // Толщина одна у всех: смена w500 → w700 меняла ширину
                    // слова, и подложка приезжала к пилюле, которая тут же
                    // раздувалась.
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
