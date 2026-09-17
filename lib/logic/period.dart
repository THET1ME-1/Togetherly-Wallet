library;

import '../l10n/strings.dart';

/// Отрезок времени, за который считает весь экран. Один и тот же на главной,
/// в категориях, статистике и ленте: человек выбирает месяц один раз, и
/// приложение не спрашивает об этом заново на каждой вкладке.

enum PeriodKind { day, week, month, year, all, custom }

/// Месяц в дате: по-русски нужен родительный падеж («12 сентября»).
String monthOf(int month) => tr('monthOf$month');

/// Дата «ГГГГ-ММ-ДД» словами: «26 мая 2026». Пустая строка остаётся пустой.
String humanDay(String iso) {
  final at = DateTime.tryParse(iso);
  if (at == null) return '';
  return '${at.day} ${monthOf(at.month)} ${at.year}';
}

/// Месяц заголовком: по-русски именительный («Сентябрь»).
String monthName(int month) => tr('month$month');

/// День недели — подпись в ленте, а подпись начинается с заглавной.
String weekdayName(int weekday) => tr('weekday$weekday');

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

class Period {
  final PeriodKind kind;

  /// Опорная дата внутри отрезка: по ней считаются границы, и её же двигают
  /// стрелки. Для «всего времени» и своего отрезка не используется.
  final DateTime anchor;

  /// Границы своего отрезка. Заполнены только при [PeriodKind.custom].
  final DateTime? customFrom;
  final DateTime? customTo;

  const Period(this.kind, this.anchor, {this.customFrom, this.customTo});

  factory Period.month([DateTime? at]) {
    final now = at ?? DateTime.now();
    return Period(PeriodKind.month, DateTime(now.year, now.month, 1));
  }

  factory Period.custom(DateTime from, DateTime to) => Period(
        PeriodKind.custom,
        dayOf(from),
        customFrom: dayOf(from),
        customTo: dayOf(to),
      );

  DateTime get from => switch (kind) {
        PeriodKind.day => dayOf(anchor),
        PeriodKind.week => dayOf(anchor).subtract(Duration(days: anchor.weekday - 1)),
        PeriodKind.month => DateTime(anchor.year, anchor.month, 1),
        PeriodKind.year => DateTime(anchor.year, 1, 1),
        PeriodKind.all => DateTime(1970, 1, 1),
        PeriodKind.custom => customFrom ?? dayOf(anchor),
      };

  DateTime get to => switch (kind) {
        PeriodKind.day => dayOf(anchor),
        PeriodKind.week => from.add(const Duration(days: 6)),
        PeriodKind.month => DateTime(anchor.year, anchor.month + 1, 0),
        PeriodKind.year => DateTime(anchor.year, 12, 31),
        PeriodKind.all => DateTime(2999, 12, 31),
        PeriodKind.custom => customTo ?? dayOf(anchor),
      };

  String get fromIso => iso(from);
  String get toIso => iso(to);

  /// Стрелки двигают отрезок целиком. «Всё время» двигать некуда.
  bool get shiftable => kind != PeriodKind.all && kind != PeriodKind.custom;

  Period shift(int step) {
    if (!shiftable) return this;
    return switch (kind) {
      PeriodKind.day => Period(kind, anchor.add(Duration(days: step))),
      PeriodKind.week => Period(kind, anchor.add(Duration(days: 7 * step))),
      PeriodKind.month => Period(kind, DateTime(anchor.year, anchor.month + step, 1)),
      PeriodKind.year => Period(kind, DateTime(anchor.year + step, 1, 1)),
      _ => this,
    };
  }

  /// Предыдущий такой же отрезок — для строки «Сравнить».
  Period get previous => shift(-1);

  /// Подпись в строке периода. Год у текущего года не пишем: он и так ясен,
  /// а строка от него становится длиннее без пользы.
  String get label {
    final now = DateTime.now();
    switch (kind) {
      case PeriodKind.day:
        final d = from;
        return d.year == now.year
            ? '${d.day} ${monthOf(d.month)}'
            : '${d.day} ${monthOf(d.month)} ${d.year}';
      case PeriodKind.week:
      case PeriodKind.custom:
        return _range(from, to, now.year);
      case PeriodKind.month:
        final d = from;
        return d.year == now.year
            ? monthName(d.month)
            : '${monthName(d.month)} ${d.year}';
      case PeriodKind.year:
        return '${from.year}';
      case PeriodKind.all:
        return tr('periodKindAll');
    }
  }

  /// Название вида, которым отрезок подписан в листе выбора.
  String get kindName => switch (kind) {
        PeriodKind.day => tr('periodKindDay'),
        PeriodKind.week => tr('periodKindWeek'),
        PeriodKind.month => tr('periodKindMonth'),
        PeriodKind.year => tr('periodKindYear'),
        PeriodKind.all => tr('periodKindAll'),
        PeriodKind.custom => tr('periodKindCustom'),
      };

  bool contains(String dateIso) =>
      dateIso.compareTo(fromIso) >= 0 && dateIso.compareTo(toIso) <= 0;

  /// Сколько дней в отрезке. Для «всего времени» считать нечего, поэтому
  /// наружу уходит null, и средние по такому отрезку не показываются.
  int? get days => kind == PeriodKind.all ? null : to.difference(from).inDays + 1;

  @override
  bool operator ==(Object other) =>
      other is Period &&
      other.kind == kind &&
      other.fromIso == fromIso &&
      other.toIso == toIso;

  @override
  int get hashCode => Object.hash(kind, fromIso, toIso);
}

/// «24 – 30 августа» или «28 июля – 3 августа»: месяц пишется один раз, когда
/// отрезок в него укладывается.
String _range(DateTime a, DateTime b, int thisYear) {
  final yearTail = (a.year == thisYear && b.year == thisYear) ? '' : ' ${b.year}';
  if (a.year == b.year && a.month == b.month) {
    return '${a.day}–${b.day} ${monthOf(b.month)}$yearTail';
  }
  return '${a.day} ${monthOf(a.month)} – ${b.day} ${monthOf(b.month)}$yearTail';
}

/// Подпись дня в ленте: «Вторник» и «25 августа» под ним.
({String number, String weekday, String month}) dayCaption(String dateIso) {
  final d = DateTime.parse(dateIso);
  return (
    number: '${d.day}',
    weekday: weekdayName(d.weekday),
    month: '${monthOf(d.month)} ${d.year}',
  );
}
