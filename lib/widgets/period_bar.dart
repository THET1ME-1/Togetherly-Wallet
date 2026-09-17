import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../l10n/strings.dart';
import '../logic/period.dart';
import '../design/myna.dart';

/// Строка периода: календарь открывает выбор, стрелки двигают отрезок,
/// воронка справа — отбор. Стоит одинаково на всех экранах, чтобы взгляд не
/// искал её заново на каждой вкладке.
class PeriodBar extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChange;
  final VoidCallback? onFilter;
  final int filterCount;

  /// Порядок в списке. Пусто — экран сортировку не меняет, и кнопки нет.
  final VoidCallback? onSort;

  /// Порядок не по умолчанию помечается цветом: иначе человек не понимает,
  /// почему список выглядит не так, как вчера.
  final bool sorted;

  const PeriodBar({
    super.key,
    required this.period,
    required this.onChange,
    this.onFilter,
    this.filterCount = 0,
    this.onSort,
    this.sorted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => pickPeriod(context, period).then((p) {
              if (p != null) onChange(p);
            }),
            icon: Icon(Myna.calendar, size: 22),
            color: scheme.onSurfaceVariant,
            tooltip: tr('filterPickPeriod'),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => pickPeriod(context, period).then((p) {
                if (p != null) onChange(p);
              }),
              child: Text(
                period.label,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: period.shiftable ? () => onChange(period.shift(-1)) : null,
            icon: Icon(Myna.chevronLeft, size: 26),
            color: scheme.onSurfaceVariant,
            tooltip: tr('periodEarlier'),
          ),
          IconButton(
            onPressed: period.shiftable ? () => onChange(period.shift(1)) : null,
            icon: Icon(Myna.chevronRight, size: 26),
            color: scheme.onSurfaceVariant,
            tooltip: tr('periodLater'),
          ),
          if (onSort != null)
            IconButton(
              onPressed: onSort,
              icon: Icon(Myna.sort, size: 22),
              color: sorted ? scheme.primary : scheme.onSurfaceVariant,
              tooltip: tr('filterKind'),
            ),
          if (onFilter != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  onPressed: onFilter,
                  icon: Icon(Myna.filter, size: 22),
                  color: filterCount > 0 ? scheme.primary : scheme.onSurfaceVariant,
                  tooltip: tr('filterTitle'),
                ),
                if (filterCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Лист выбора отрезка. Под каждым видом стоят его настоящие даты — так видно,
/// что именно выберется, до нажатия.
Future<Period?> pickPeriod(BuildContext context, Period current) {
  final now = DateTime.now();
  final options = <Period>[
    Period(PeriodKind.day, now),
    Period(PeriodKind.week, now),
    Period.month(now),
    Period(PeriodKind.year, now),
    Period(PeriodKind.all, now),
  ];

  return showModalBottomSheet<Period>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in options)
              ListTile(
                title: Text(
                  p.kindName,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                subtitle: p.kind == PeriodKind.all
                    ? null
                    : Text(
                        p.label,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                trailing: p.kind == current.kind
                    ? Icon(Myna.checkCircle, color: scheme.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(p),
              ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Myna.calendar, color: scheme.onSurfaceVariant),
              title: Text(
                tr('periodOwn'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              subtitle: current.kind == PeriodKind.custom
                  ? Text(
                      current.label,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : null,
              trailing: current.kind == PeriodKind.custom
                  ? Icon(Myna.checkCircle, color: scheme.primary)
                  : null,
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2015, 1, 1),
                  lastDate: DateTime(now.year + 2, 12, 31),
                  initialDateRange: DateTimeRange(
                    start: current.from,
                    end: current.to.isAfter(now) ? now : current.to,
                  ),
                  helpText: tr('periodOwn'),
                  saveText: tr('done'),
                );
                if (picked != null && context.mounted) {
                  Navigator.of(context).pop(Period.custom(picked.start, picked.end));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
