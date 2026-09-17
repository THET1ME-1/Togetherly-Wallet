import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/period.dart';
import '../design/myna.dart';

/// Кнопка отрезка в углу блока.
///
/// У каждого блока главной свой отрезок: баланс смотрят за месяц, категории за
/// неделю, поток за год. Один общий переключатель заставлял бы человека
/// перещёлкивать весь экран ради одной карточки.
///
/// Выбор помнится между запусками — вместе с пролистанным месяцем.
class BlockPeriodButton extends StatelessWidget {
  const BlockPeriodButton({
    super.key,
    required this.store,
    required this.block,
    this.fallback,
  });

  final Store store;

  /// Имя блока: под ним отрезок и лежит в настройках устройства.
  final String block;
  final Period? fallback;

  static List<(PeriodKind, String)> get _choices => [
    (PeriodKind.day, tr('periodToday')),
    (PeriodKind.week, tr('periodWeekly')),
    (PeriodKind.month, tr('periodMonthly')),
    (PeriodKind.year, tr('periodYear')),
    (PeriodKind.all, tr('periodAll')),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = store.periodOf(block, fallback: fallback);

    return PopupMenuButton<PeriodKind>(
      tooltip: tr('filterPeriod'),
      position: PopupMenuPosition.under,
      initialValue: period.kind,
      onSelected: (kind) => store.setPeriod(block, Period(kind, DateTime.now())),
      itemBuilder: (context) => [
        for (final choice in _choices)
          PopupMenuItem(
            value: choice.$1,
            child: Row(children: [
              Icon(
                period.kind == choice.$1
                    ? Myna.checkCircle
                    : Myna.circle,
                size: 18,
                color: period.kind == choice.$1
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Text(
                choice.$2,
                style: TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 14.5),
              ),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.only(left: 11, right: 7, top: 5, bottom: 5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            period.label,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          Icon(Myna.chevronDown, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// Стрелки перелистывания отрезка — рядом с кнопкой, где это нужно.
class BlockPeriodArrows extends StatelessWidget {
  const BlockPeriodArrows({
    super.key,
    required this.store,
    required this.block,
    this.fallback,
  });

  final Store store;
  final String block;
  final Period? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final period = store.periodOf(block, fallback: fallback);
    if (!period.shiftable) return SizedBox.shrink();

    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        onPressed: () => store.setPeriod(block, period.shift(-1)),
        visualDensity: VisualDensity.compact,
        icon: Icon(Myna.chevronLeft),
        color: scheme.onSurfaceVariant,
        tooltip: tr('periodEarlier'),
      ),
      IconButton(
        onPressed: () => store.setPeriod(block, period.shift(1)),
        visualDensity: VisualDensity.compact,
        icon: Icon(Myna.chevronRight),
        color: scheme.onSurfaceVariant,
        tooltip: tr('periodLater'),
      ),
    ]);
  }
}
