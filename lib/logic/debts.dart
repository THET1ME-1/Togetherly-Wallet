import 'dart:math' as math;

import '../data/models.dart';
import 'money.dart';

/// Долги: сколько осталось, в каком порядке гасить и когда кончится.
///
/// Остаток не хранится числом — он считается из платежей, как накопленное у
/// цели. Платёж по долгу это перевод: деньги уходят с кошелька на счёт долга
/// `Долг: <имя>`, и «осталось» не может разойтись с историей.

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Порядок погашения.
///
/// «Лавина» дешевле по деньгам: сперва самая дорогая ставка. «Снежный ком»
/// дешевле по силе воли: сперва самый маленький остаток, и первый закрытый
/// долг придаёт разгон. Обе статьи называют оба способа, выбор за парой.
enum PayoffOrder { avalanche, snowball }

class DebtState {
  final Debt debt;

  /// Сколько уже выплачено.
  final double paid;

  /// Сколько осталось вернуть.
  final double left;

  /// Доля погашенного, 0..1.
  final double share;

  /// За сколько месяцев закроется при нынешнем платеже. Пусто — платёж не
  /// покрывает даже проценты, и долг не кончится никогда: это надо говорить
  /// прямо, а не рисовать успокаивающую полосу.
  final int? months;

  const DebtState({
    required this.debt,
    required this.paid,
    required this.left,
    required this.share,
    required this.months,
  });

  bool get closed => left <= 0.005;

  /// Проценты в месяц по нынешнему остатку: столько стоит этот долг, пока он
  /// висит. Число, которое заставляет гасить дорогое первым.
  double get monthlyInterest => _round2(left * debt.rate / 100 / 12);
}

/// Сколько по долгу заплачено и сколько осталось.
DebtState stateOf(Database db, Debt debt, {double? payment}) {
  final account = debtAccountOf(debt.name);
  var paid = 0.0;
  for (final t in db.transactions) {
    if (t.account != account) continue;
    // Платёж приходит плюсом на счёт долга, возврат (ошиблись суммой) минусом.
    paid += t.amount;
  }
  paid = _round2(paid);
  final left = _round2(math.max(0, debt.principal - paid));
  final share = debt.principal <= 0 ? 1.0 : (paid / debt.principal).clamp(0.0, 1.0);

  return DebtState(
    debt: debt,
    paid: paid,
    left: left,
    share: share,
    months: monthsToClose(left, debt.rate, payment ?? debt.minPayment),
  );
}

/// За сколько месяцев закроется долг [left] при ставке [rate] и платеже [pay].
///
/// Считается обычной амортизацией: проценты начисляются на остаток, платёж
/// гасит сперва их. Если платёж не перекрывает проценты, ответа нет — долг
/// растёт, и «никогда» честнее любого числа.
int? monthsToClose(double left, double rate, double pay) {
  if (left <= 0.005) return 0;
  if (pay <= 0) return null;
  final monthly = rate / 100 / 12;
  if (monthly <= 0) return (left / pay).ceil();
  if (pay <= left * monthly + 0.005) return null;

  var rest = left;
  var months = 0;
  // Потолок в шестьсот месяцев (пятьдесят лет) — предохранитель от вечного
  // цикла на кривых данных, а не продуктовое решение.
  while (rest > 0.005 && months < 600) {
    rest = rest * (1 + monthly) - pay;
    months++;
  }
  return rest > 0.005 ? null : months;
}

/// Долги в том порядке, в каком их стоит гасить.
///
/// Закрытые уходят в конец: они больше не требуют решений, но пропадать с
/// экрана не должны — по ним видно пройденный путь.
List<DebtState> payoffPlan(Database db, {PayoffOrder order = PayoffOrder.avalanche}) {
  final out = [for (final d in db.debts) stateOf(db, d)];
  out.sort((a, b) {
    if (a.closed != b.closed) return a.closed ? 1 : -1;
    if (order == PayoffOrder.avalanche) {
      final byRate = b.debt.rate.compareTo(a.debt.rate);
      if (byRate != 0) return byRate;
      return a.left.compareTo(b.left);
    }
    final byLeft = a.left.compareTo(b.left);
    if (byLeft != 0) return byLeft;
    return b.debt.rate.compareTo(a.debt.rate);
  });
  return out;
}

/// Сводка по всем долгам в базовой валюте.
class DebtTotals {
  final double left;
  final double minPayments;
  final double monthlyInterest;
  final int open;

  const DebtTotals({
    required this.left,
    required this.minPayments,
    required this.monthlyInterest,
    required this.open,
  });
}

DebtTotals debtTotals(Database db) {
  var left = 0.0, min = 0.0, interest = 0.0, open = 0;
  for (final d in db.debts) {
    final st = stateOf(db, d);
    if (st.closed) continue;
    open++;
    left += convert(db, st.left, d.currency);
    min += convert(db, d.minPayment, d.currency);
    interest += convert(db, st.monthlyInterest, d.currency);
  }
  return DebtTotals(
    left: _round2(left),
    minPayments: _round2(min),
    monthlyInterest: _round2(interest),
    open: open,
  );
}

/// Сколько сэкономит лишняя сумма поверх минимальных платежей, если гнать её
/// в первый долг выбранного порядка: месяцы и переплата.
///
/// Это главный довод в пользу «лавины» и единственный способ показать, что
/// дополнительная тысяча в месяц значит.
({int? months, int? monthsWithExtra}) payoffGain(
  Database db,
  double extra, {
  PayoffOrder order = PayoffOrder.avalanche,
}) {
  final plan = payoffPlan(db, order: order).where((s) => !s.closed).toList();
  if (plan.isEmpty) return (months: 0, monthsWithExtra: 0);
  final first = plan.first;
  return (
    months: first.months,
    monthsWithExtra:
        monthsToClose(first.left, first.debt.rate, first.debt.minPayment + extra),
  );
}
