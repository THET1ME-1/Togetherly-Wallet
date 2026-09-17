/// Счёт до потолка: сколько бесплатного израсходовано и сколько осталось.
///
/// Правило человека 17.09.2026: где у платного есть число, человек видит счёт
/// ЗАРАНЕЕ, а стена встаёт в момент действия. Отсюда требование к устройству
/// этого файла: счёт на экране и решение калитки считаются ОДНИМ местом.
/// Разъедутся они на первой же правке потолка, и человек увидит «осталось 2»
/// на экране, где добавить уже нельзя.
library;

import '../data/models.dart';
import 'plus.dart';

/// Сколько занято у калитки с числом.
class PlusCount {
  const PlusCount({required this.have, required this.limit});

  /// Сколько уже заведено. Может быть БОЛЬШЕ потолка: у человека, который вёл
  /// семь конвертов до появления подписки, остаются все семь.
  final int have;

  /// Сколько даётся бесплатно.
  final int limit;

  /// Сколько ещё можно завести. Ниже нуля не опускается: «осталось −2»
  /// человеку не говорит ничего.
  int get left {
    final rest = limit - have;
    return rest < 0 ? 0 : rest;
  }

  /// Потолок выбран, дальше стена.
  bool get full => have >= limit;
}

/// Сколько занято из бесплатного у калитки.
///
/// `null` значит «счётчика нет», и таких случаев три, все намеренные:
///
/// * подписка открыта — напоминать о снятом деньгами потолке незачем;
/// * у калитки нет числа вовсе (замок, отчёт, прогноз);
/// * число ещё не приехало — база не передана или сервер не ответил. Врать
///   «осталось 3» нельзя: вопросы человек мог потратить с другого телефона.
PlusCount? plusCount(
  PlusGate gate, {
  required bool plus,
  Database? db,
  int? asked,
  int? files,
}) {
  if (plus) return null;
  final limit = plusLimitOf(gate);
  if (limit == null) return null;
  final have = switch (gate) {
    PlusGate.chat => asked,
    PlusGate.files => files,
    PlusGate.envelope => db?.budgets.length,
    PlusGate.goal => db?.goals.length,
    PlusGate.debt => db?.debts.length,
    PlusGate.recurring => db?.recurring.length,
    _ => null,
  };
  if (have == null) return null;
  return PlusCount(have: have, limit: limit);
}
