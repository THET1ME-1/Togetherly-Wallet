/// Счётная клавиатура записи: цифры и четыре действия.
///
/// В магазине сумма редко бывает готовой: «три по 42», «пополам», «плюс
/// десять процентов». Раньше человек считал это в уме или в другом
/// приложении, а сюда приносил результат.
///
/// Цифры набираются КОПЕЙКАМИ, как и прежде: «5000» это 50,00. Точки в наборе
/// нет и не нужно — она была источником половины опечаток.
library;

import 'money.dart';

enum CalcOp { plus, minus, times, divide }

String calcOpSign(CalcOp op) => switch (op) {
      CalcOp.plus => '+',
      CalcOp.minus => '−',
      CalcOp.times => '×',
      CalcOp.divide => '÷',
    };

class Calc {
  Calc();

  /// Продолжить с готового числа — правка записанной операции.
  factory Calc.of(double value) {
    final c = Calc();
    c._digits = (value * 100).round().abs().toString();
    if (c._digits == '0') c._digits = '';
    return c;
  }

  /// Набранное копейками. Пусто — ноль.
  String _digits = '';

  /// Первое число выражения и знак действия. Пусто — выражения нет.
  double? _left;
  CalcOp? _op;

  /// Доля вместо числа: «+ 10%» это плюс десять процентов от первого числа.
  bool _percent = false;

  double get _entered => _digits.isEmpty ? 0 : int.parse(_digits) / 100;

  /// Идёт ли выражение — от этого главная клавиша читается «=», а не галочкой.
  bool get hasExpression => _op != null;

  /// Значение для записи. Незакрытое выражение считается на лету, чтобы
  /// «Записать» не требовало лишнего нажатия равно.
  double get value => hasExpression ? _resolve() : _entered;

  /// Что показывать крупно. Выражение видно целиком: человек должен видеть,
  /// что именно он считает.
  String get display {
    if (!hasExpression) return formatAmount(_entered);
    final head = '${formatAmount(_left!)} ${calcOpSign(_op!)}';
    if (_digits.isEmpty) return head;
    return '$head ${formatAmount(_entered)}${_percent ? '%' : ''}';
  }

  void digit(String d) {
    if (d == '00') {
      if (_digits.isEmpty) return;
      _digits = '${_digits}00';
    } else {
      _digits += d;
    }
    // Ведущие нули не копятся, а длина ограничена: девять цифр это семь
    // миллионов лей, и дальше число перестаёт помещаться на экран.
    _digits = _digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (_digits.length > 9) _digits = _digits.substring(0, 9);
  }

  void backspace() {
    if (_digits.isNotEmpty) {
      _digits = _digits.substring(0, _digits.length - 1);
      return;
    }
    // Цифр нет — стирание снимает знак действия и возвращает первое число.
    // Иначе выражение «5 +» нельзя было бы разобрать обратно.
    if (hasExpression) {
      _digits = (_left! * 100).round().abs().toString();
      if (_digits == '0') _digits = '';
      _left = null;
      _op = null;
      _percent = false;
    }
  }

  void operator(CalcOp op) {
    if (hasExpression && _digits.isEmpty) {
      // Второй знак подряд заменяет первый: человек передумал, а не начал
      // новое действие.
      _op = op;
      return;
    }
    if (hasExpression) equals();
    if (_digits.isEmpty && _left == null) return;
    _left = _entered;
    _op = op;
    _digits = '';
    _percent = false;
  }

  /// Доля от первого числа. Без выражения процент считать не от чего.
  void percent() {
    if (!hasExpression || _digits.isEmpty) return;
    _percent = true;
  }

  void equals() {
    if (!hasExpression) return;
    final result = _resolve();
    _left = null;
    _op = null;
    _percent = false;
    _digits = (result * 100).round().abs().toString();
    if (_digits == '0') _digits = '';
  }

  void clear() {
    _digits = '';
    _left = null;
    _op = null;
    _percent = false;
  }

  double _resolve() {
    final left = _left ?? 0;
    if (_digits.isEmpty) return left;
    final right = _percent ? left * _entered / 100 : _entered;
    final out = switch (_op!) {
      CalcOp.plus => left + right,
      CalcOp.minus => left - right,
      CalcOp.times => left * right,
      // Делить на ноль нечего: оставляем первое число, а не бесконечность.
      CalcOp.divide => right == 0 ? left : left / right,
    };
    // Копейки: без округления «10 ÷ 3» даёт хвост в пятнадцать знаков.
    return (out * 100).round() / 100;
  }
}
