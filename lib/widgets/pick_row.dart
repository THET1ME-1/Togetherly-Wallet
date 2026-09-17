import 'package:flutter/material.dart';

/// Ряд выбора с прокруткой вбок.
///
/// Раньше пилюли лежали в `Wrap`: десять счетов занимали четыре строки, экран
/// записи траты уезжал вниз, и до клавиатуры приходилось листать. Ряд держит
/// одну строку на любое число счетов, а остальное человек пролистывает пальцем.
///
/// Края подрезаны отступом, а не обрывом: видно, что справа есть продолжение.
class PickRow extends StatelessWidget {
  const PickRow({
    super.key,
    required this.children,
    this.height = 44,
    this.spacing = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 2),
  });

  final List<Widget> children;
  final double height;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    // Высота считается от шрифта: при системном увеличении пилюля вырастает,
    // и ряд обязан вырасти с ней, иначе текст обрежется.
    final scaled = height * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      height: scaled,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: children.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing),
        itemBuilder: (context, i) => Center(child: children[i]),
      ),
    );
  }
}
