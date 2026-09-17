import 'package:flutter/material.dart';

import '../design/myna.dart';
import '../logic/plus.dart';
import '../screens/plus_screen.dart';
import '../services/plus.dart';

/// Калитка подписки.
///
/// Упёрся в потолок — сразу витрина Wallet+, без промежуточного листа с
/// объяснением (решение человека 17.09.2026). Лист «это платное, хотите
/// посмотреть?» — лишний вопрос между человеком и ответом: он уже нажал, он
/// уже хочет; показывать ему дверь, за которой ещё одна дверь, незачем.
///
/// Сколько осталось до потолка, человек видит ЗАРАНЕЕ — точками у заголовка
/// раздела (`PlusMeter`), а не в момент отказа.
///
/// Возвращает true, если подписка теперь есть: человек ушёл на витрину,
/// оформил и вернулся. Тогда вызвавший экран продолжает прерванное действие.
Future<bool> askPlus(
  BuildContext context, {
  required PlusService? plus,
  required PlusGate gate,
}) async {
  // Сервиса нет вовсе (одиночка без аккаунта, тесты) — не запираем.
  if (plus == null || plus.active) return true;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlusScreen(plus: plus)),
  );
  return plus.active;
}

/// Пускать ли дальше: считает потолок и, если он достигнут, ведёт на витрину.
/// `have` — сколько уже заведено.
Future<bool> allowMore(
  BuildContext context, {
  required PlusService? plus,
  required PlusGate gate,
  required int have,
}) async {
  final limit = plusLimitOf(gate);
  final ok = canAddMore(
    plus: plus?.active ?? true,
    have: have,
    limit: limit ?? 0,
  );
  if (ok) return true;
  return askPlus(context, plus: plus, gate: gate);
}

/// Знак калитки. Нужен там, где платное показано строкой: у каждой функции
/// свой, потому что один замок на пятнадцати строках говорит только
/// «закрыто», а человеку нужно понять, ЧТО закрыто.
IconData plusGateIcon(PlusGate gate) => switch (gate) {
      PlusGate.chat => Myna.message,
      PlusGate.files => Myna.paperclip,
      PlusGate.envelope => Myna.box,
      PlusGate.goal => Myna.flag,
      PlusGate.debt => Myna.percentage,
      PlusGate.recurring => Myna.refresh,
      PlusGate.planAhead => Myna.calendar,
      PlusGate.autoNotices => Myna.bellOn,
      PlusGate.noticeRules => Myna.filter,
      PlusGate.lock => Myna.lock,
      PlusGate.report => Myna.fileText,
      PlusGate.monthReview => Myna.sparkles,
      PlusGate.looks => Myna.creditCard,
      PlusGate.cloudBackups => Myna.archive,
    };
