/// С какого дня пара вместе — тем же правилом, что в Togetherly.
///
/// Дат у пары три, и все лежат в записи группы:
///  * `start_date` — день КОННЕКТА, когда пара сошлась в приложении;
///  * системный таймер «Дней вместе» в `timers` — начало отношений, его
///    человек правит на главной Togetherly;
///  * `anniversary_date` — годовщина, которую вводят в профиле пары.
///
/// Wallet показывал одну дату коннекта: «Пара с 12 августа 2026», а
/// Togetherly у той же пары — «с 22 июня» (жалоба 19.09.2026). Правило ниже —
/// копия `coupleStartDate` из `lib/utils/couple_days.dart` Togetherly; правя
/// одно, правь и другое, иначе два приложения снова разойдутся.
library;

import 'dart:convert';

/// Начало пары днём `ГГГГ-ММ-ДД`, пусто — ни одной даты нет.
///
/// Человек правил таймер (его день не совпадает с днём коннекта) — берётся
/// более ранняя из таймера и коннекта, годовщина не в счёт: свой срок он уже
/// выставил. Таймер нетронут — пустоту закрывает годовщина, если она раньше.
String pairSince({
  String timer = '',
  String connect = '',
  String anniversary = '',
}) {
  final edited = timer.isNotEmpty && timer != connect;
  final dates = edited ? [timer, connect] : [timer, connect, anniversary];
  var earliest = '';
  for (final d in dates) {
    if (d.isEmpty) continue;
    if (earliest.isEmpty || d.compareTo(earliest) < 0) earliest = d;
  }
  return earliest;
}

/// День системного таймера из `groups.timers`. PocketBase отдаёт поле
/// списком, но строку JSON тоже принимаем.
String systemTimerDay(Object? timers) {
  var list = timers;
  if (list is String) {
    try {
      list = jsonDecode(list);
    } catch (_) {
      return '';
    }
  }
  if (list is! List) return '';
  for (final t in list) {
    if (t is Map && t['isSystem'] == true) return dayOf(t['startDate']);
  }
  return '';
}

/// Календарный день из строки как написан: «2026-08-12 21:40:00.000Z» →
/// «2026-08-12». Пояс не пересчитывается — так же читает Togetherly, и одна
/// пара видит в двух приложениях один день.
///
/// Дата вне человеческого века — опечатка, и датой она не считается. В
/// таймере Togetherly вводят день руками, и промах по цифре даёт «Пара с 15
/// июня 1026» (22.09.2026): правило «берём самую раннюю» делало такую дату
/// вечным победителем. Отброшенная опечатка уступает место дню коннекта.
String dayOf(Object? raw) {
  final text = '${raw ?? ''}'.trim();
  final m = RegExp(r'^\d{4}-\d{2}-\d{2}').firstMatch(text);
  if (m == null) return '';
  final day = m.group(0)!;
  final year = int.parse(day.substring(0, 4));
  if (year < 1900 || year > DateTime.now().year + 1) return '';
  return day;
}
