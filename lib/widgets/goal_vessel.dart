import 'package:flutter/material.dart';

import '../design/accents.dart';
import '../design/app_theme.dart';

import 'icon_scatter.dart';

/// Цель СОСУДОМ: форма наливается снизу вместе с накоплением.
///
/// Полоса прогресса отвечает числом, налитая форма — взглядом. Приём тот же,
/// что у кварталов категорий (площадь и есть сумма), только вертикальный, и
/// по налитой части идёт ассорти знаков самой цели — выбрано человеком
/// 16.09.2026.
///
/// Подписи рисуются ДВАЖДЫ: поверх пустой части — цветом поверхности, поверх
/// налитой — цветом по заливке, и вторая копия обрезана ровно по кромке воды.
/// Иначе на границе получалось «чёрное на чёрном»: заливка пастельная, и белая
/// подпись на ней пропадает ровно тогда, когда цель почти собрана.
class GoalVessel extends StatelessWidget {
  const GoalVessel({
    super.key,
    required this.name,
    this.showName = true,
    this.caption,
    required this.share,
    required this.color,
    required this.icons,
    this.badge,
    this.height = 112,
    this.onTap,
    this.onLongPress,
  });

  final String name;

  /// Показывать ли имя внутри сосуда. На экране целей оно уже стоит в шапке
  /// карточки, и вторая копия читалась бы заиканием.
  final bool showName;

  /// Вторая строка: сколько собрано и к какому сроку. Пусто — строки нет.
  final String? caption;

  /// Доля собранного, 0..1.
  final double share;

  /// Цвет цели: свой, заданный человеком, либо цвет по имени.
  final Color color;

  /// Знаки ассорти: знак самой цели и её соседи по смыслу.
  final List<IconData> icons;

  /// Правый угол: проценты или «Готово».
  final String? badge;

  final double height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final level = share.clamp(0.0, 1.0);
    final ink = inkOn(color);

    return Material(
      // Пустая часть — не серый блок, а стекло ЦВЕТА ЦЕЛИ: сосуд с девятью
      // процентами иначе читался пустым прямоугольником на полкарточки.
      color: Color.alphaBlend(
        color.withValues(alpha: 0.16),
        scheme.surfaceContainerHighest,
      ),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: still ? level : 0, end: level),
            duration: Duration(milliseconds: still ? 0 : 1100),
            curve: AppTheme.emphasizedDecelerate,
            builder: (context, water, _) => Stack(
              fit: StackFit.expand,
              children: [
                // Ассорти лежит по ВСЕЙ форме, а не только по воде: рисунок
                // один, и вода не переставляет знаки, а подкрашивает их,
                // поднимаясь. Обрезка по кромке делает это одним движением.
                _scatter(color.withValues(alpha: 0.34)),
                ClipRect(
                  clipper: _Waterline(water),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: color),
                      _scatter(ink.withValues(alpha: 0.16)),
                    ],
                  ),
                ),
                _text(context, scheme.onSurface, scheme.onSurfaceVariant),
                // Та же подпись цветом по заливке, обрезанная кромкой воды.
                ClipRect(
                  clipper: _Waterline(water),
                  child: _text(context, ink, ink.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Знаки цели по всей площади сосуда. Семя — имя цели: рисунок у каждой
  /// свой, но постоянный между кадрами.
  Widget _scatter(Color tint) => IgnorePointer(
        child: CustomPaint(
          painter: IconScatterPainter(
            icons: icons,
            color: tint,
            seed: name.hashCode,
            scale: _tight ? 0.44 : 0.62,
          ),
        ),
      );

  /// Тесный сосуд: когда целей много, они становятся ниже, и прежние отступы
  /// с крупным процентом в них просто не помещались.
  bool get _tight => height < 72;

  Widget _text(BuildContext context, Color head, Color sub) {
    return Padding(
      padding: EdgeInsets.fromLTRB(_tight ? 12 : 16, _tight ? 9 : 14,
          _tight ? 12 : 16, _tight ? 9 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.displayFont,
                          fontSize: _tight ? 13.5 : 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: head,
                        ),
                      ),
                    if (showName && caption != null) const SizedBox(height: 3),
                    if (caption != null)
                      Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: _tight ? 11.5 : 12.5,
                          color: sub,
                        ),
                      ),
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 10),
                Text(
                  badge!,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: _tight ? 15 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: head,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Кромка воды: всё, что ниже неё, принадлежит налитой части.
class _Waterline extends CustomClipper<Rect> {
  const _Waterline(this.level);

  final double level;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        0,
        size.height * (1 - level.clamp(0.0, 1.0)),
        size.width,
        size.height,
      );

  @override
  bool shouldReclip(_Waterline old) => old.level != level;
}
