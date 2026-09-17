import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';
import '../logic/date_wheel.dart';
import '../logic/period.dart';

/// Выбор даты барабанами — нижним листом.
///
/// Системный календарь отвергнут заказчиком прямо: «вместо календаря сделать
/// барабаны как в Togetherly» (13.09.2026). Причина не в красоте — в попадании:
/// в календаре клетка дня меньше подушечки пальца, и промах стоит открытия
/// календаря заново. Барабан ловит движение целиком.
///
/// Лист, а не свой экран (как в Togetherly): в Money попапов по центру нет
/// вовсе, а всё решаемое живёт в нижнем листе.
///
/// Барабаны — родной [ListWheelScrollView]: он сам даёт снап, инерцию и
/// затухание к краям.
Future<DateTime?> showDateWheel(
  BuildContext context, {
  required String title,
  DateTime? initial,
  int? firstYear,
  int? lastYear,
  bool withTime = false,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _DateWheelSheet(
      title: title,
      initial: initial ?? now,
      firstYear: firstYear ?? now.year - 5,
      lastYear: lastYear ?? now.year + 5,
      withTime: withTime,
    ),
  );
}

/// Выбор МЕСЯЦА барабаном — два колеса, месяц и год.
///
/// Листать стрелками по одному месяцу — это двенадцать нажатий, чтобы уйти на
/// год назад. Заказчик попросил прямо: «надо при нажатии на слово месяца
/// открытие барабана с выбором месяца» (13.09.2026).
Future<DateTime?> showMonthWheel(
  BuildContext context, {
  required String title,
  DateTime? initial,
  int? firstYear,
  int? lastYear,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _DateWheelSheet(
      title: title,
      initial: initial ?? now,
      firstYear: firstYear ?? now.year - 5,
      lastYear: lastYear ?? now.year + 5,
      withTime: false,
      monthOnly: true,
    ),
  );
}

class _DateWheelSheet extends StatefulWidget {
  const _DateWheelSheet({
    required this.title,
    required this.initial,
    required this.firstYear,
    required this.lastYear,
    required this.withTime,
    this.monthOnly = false,
  });

  final String title;
  final DateTime initial;
  final int firstYear;
  final int lastYear;
  final bool withTime;

  /// Без дня: экран плана живёт месяцами, и число там лишнее.
  final bool monthOnly;

  @override
  State<_DateWheelSheet> createState() => _DateWheelSheetState();
}

class _DateWheelSheetState extends State<_DateWheelSheet> {
  late int _day = widget.initial.day;
  late int _month = widget.initial.month;
  late int _year = widget.initial.year.clamp(widget.firstYear, widget.lastYear);
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;

  late final _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
  late final _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
  late final _yearCtrl =
      FixedExtentScrollController(initialItem: _year - widget.firstYear);
  late final _hourCtrl = FixedExtentScrollController(initialItem: _hour);
  late final _minuteCtrl = FixedExtentScrollController(initialItem: _minute);

  static const double _extent = 52;

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  /// Дней в месяце стало меньше — прижимаем выбор к последнему числу.
  /// Без этого 31 марта при переходе в февраль уезжало в 3 марта.
  void _clampDay() {
    final last = DateWheel.daysInMonth(_year, _month);
    if (_day <= last) return;
    _day = last;
    _dayCtrl.jumpToItem(_day - 1);
  }

  DateTime get _value => DateWheel.build(
        year: _year,
        month: _month,
        day: widget.monthOnly ? 1 : _day,
        hour: widget.withTime ? _hour : 0,
        minute: widget.withTime ? _minute : 0,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = widget.lastYear - widget.firstYear + 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _extent * 5,
          child: Stack(children: [
            // Подложка выбранной строки. Она же говорит, где «сейчас»: без
            // неё барабан читается как список, и непонятно, что выбрано.
            Center(
              child: Container(
                height: _extent,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Row(children: [
              if (!widget.monthOnly)
                Expanded(
                  flex: 3,
                  child: _wheel(
                    controller: _dayCtrl,
                    count: DateWheel.daysInMonth(_year, _month),
                    selected: _day - 1,
                    label: (i) => '${i + 1}',
                    onChanged: (i) => setState(() => _day = i + 1),
                  ),
                ),
              Expanded(
                flex: 5,
                child: _wheel(
                  controller: _monthCtrl,
                  count: 12,
                  selected: _month - 1,
                  label: (i) => monthName(i + 1),
                  onChanged: (i) => setState(() {
                    _month = i + 1;
                    _clampDay();
                  }),
                ),
              ),
              Expanded(
                flex: 4,
                child: _wheel(
                  controller: _yearCtrl,
                  count: years,
                  selected: _year - widget.firstYear,
                  label: (i) => '${widget.firstYear + i}',
                  onChanged: (i) => setState(() {
                    _year = widget.firstYear + i;
                    _clampDay();
                  }),
                ),
              ),
              if (widget.withTime) ...[
                Expanded(
                  flex: 3,
                  child: _wheel(
                    controller: _hourCtrl,
                    count: 24,
                    selected: _hour,
                    loop: true,
                    label: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _hour = i),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: _wheel(
                    controller: _minuteCtrl,
                    count: 60,
                    selected: _minute,
                    loop: true,
                    label: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _minute = i),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          // «Сегодня» рядом с выбором: половина записей — сегодняшние, и
          // крутить к ним три барабана обратно незачем.
          TextButton.icon(
            onPressed: _today,
            icon: const Icon(Myna.calendarCheck, size: 18),
            label: Text(tr('wheelToday')),
          ),
          const Spacer(),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_value),
            child: Text(tr('wheelDone')),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
      ]),
    );
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      _year = now.year.clamp(widget.firstYear, widget.lastYear);
      _month = now.month;
      _day = now.day;
      _hour = now.hour;
      _minute = now.minute;
    });
    _yearCtrl.jumpToItem(_year - widget.firstYear);
    _monthCtrl.jumpToItem(_month - 1);
    _dayCtrl.jumpToItem(_day - 1);
    if (widget.withTime) {
      _hourCtrl.jumpToItem(_hour);
      _minuteCtrl.jumpToItem(_minute);
    }
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
    bool loop = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    Widget cell(int i) {
      final on = i == selected;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label(i),
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 21,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                // Подложка выбранной строки — surfaceContainerHighest, и
                // буквы к ней onSurface. onSecondaryContainer тут значил
                // onAccent: чёрным по тёмно-серому, барабан читался пустым.
                color: on ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _extent,
      physics: const FixedExtentScrollPhysics(),
      // Затухание к краям — тот самый силуэт песочных часов.
      overAndUnderCenterOpacity: 0.32,
      perspective: 0.0022,
      diameterRatio: 2.1,
      onSelectedItemChanged: (i) {
        Tap.pick();
        onChanged(loop ? i % count : i);
      },
      childDelegate: loop
          ? ListWheelChildLoopingListDelegate(
              children: List.generate(count, cell))
          : ListWheelChildBuilderDelegate(
              childCount: count, builder: (_, i) => cell(i)),
    );
  }
}

/// Барабан ЧИСЕЛ: длина отрезка бюджета, «каждые N дней» у регулярного.
///
/// Тот же приём, что с датой: поле ввода тут неуместно — человек выбирает из
/// ряда, а не печатает, и клавиатура ради двух цифр закрывает пол-экрана.
Future<int?> showNumberWheel(
  BuildContext context, {
  required String title,
  required int initial,
  required int first,
  required int last,
  required String Function(int) label,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _NumberWheelSheet(
        title: title,
        initial: initial.clamp(first, last),
        first: first,
        last: last,
        label: label,
      ),
    );

class _NumberWheelSheet extends StatefulWidget {
  const _NumberWheelSheet({
    required this.title,
    required this.initial,
    required this.first,
    required this.last,
    required this.label,
  });

  final String title;
  final int initial;
  final int first;
  final int last;
  final String Function(int) label;

  @override
  State<_NumberWheelSheet> createState() => _NumberWheelSheetState();
}

class _NumberWheelSheetState extends State<_NumberWheelSheet> {
  late int _value = widget.initial;
  late final _controller =
      FixedExtentScrollController(initialItem: _value - widget.first);

  static const double _extent = 52;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count = widget.last - widget.first + 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: _extent * 5,
          child: Stack(children: [
            Center(
              child: Container(
                height: _extent,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: _extent,
              perspective: 0.002,
              diameterRatio: 1.6,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) {
                Tap.pick();
                setState(() => _value = widget.first + i);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: count,
                builder: (context, i) {
                  final value = widget.first + i;
                  final on = value == _value;
                  return Center(
                    child: Text(
                      widget.label(value),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: on ? 19 : 17,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                        color: on
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(_value),
            child: Text(tr('wheelDone')),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('cancel')),
        ),
      ]),
    );
  }
}
