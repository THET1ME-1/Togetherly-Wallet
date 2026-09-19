/// Счётная клавиатура записи: цифры и четыре действия.
///
/// В магазине сумма редко бывает готовой: «три по 42», «пополам», «плюс
/// десять процентов». Раньше человек считал это в уме или в другом
/// приложении, а сюда приносил результат.
///
/// Цифры набираются ЦЕЛЫМИ, как на обычном калькуляторе: «1» это 1,00, а
/// «58.12» это 58,12. До 19.09.2026 набор шёл копейками («5000» было 50,00) с
/// клавишей «00», и человек, нажавший «1», получал 0,01 — «не удобно».
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
  factory Calc.of(double value) => Calc().._typed = _typedOf(value);

  /// Набранное как есть: цифры и не больше одной точки, после неё не больше
  /// двух цифр. Пусто — ноль.
  String _typed = '';

  /// Готовое число обратно в набор: «84» без хвоста, «8.40» с копейками.
  /// Иначе стирание после «=» сносило бы сотые, которых человек не набирал.
  static String _typedOf(double value) {
    final cents = (value * 100).round().abs();
    if (cents == 0) return '';
    final whole = cents ~/ 100;
    final part = cents % 100;
    return part == 0 ? '$whole' : '$whole.${'$part'.padLeft(2, '0')}';
  }

  /// Первое число выражения и знак действия. Пусто — выражения нет.
  double? _left;
  CalcOp? _op;

  /// Доля вместо числа: «+ 10%» это плюс десять процентов от первого числа.
  bool _percent = false;

  double get _entered {
    if (_typed.isEmpty || _typed == '.') return 0;
    return double.parse(_typed.endsWith('.') ? '${_typed}0' : _typed);
  }

  /// Идёт ли выражение — от этого главная клавиша читается «=», а не галочкой.
  bool get hasExpression => _op != null;

  /// Значение для записи. Незакрытое выражение считается на лету, чтобы
  /// «Записать» не требовало лишнего нажатия равно.
  double get value => hasExpression ? _resolve() : _entered;

  /// Начало выражения перед набираемым числом: «42,00 × ». Без выражения
  /// пусто.
  String get lead =>
      hasExpression ? '${formatAmount(_left!)} ${calcOpSign(_op!)} ' : '';

  /// Набираемое число: что нажато и серый хвост до копеек.
  ///
  /// Копейки на экране стоят всегда — правило заказчика, — но набирает их
  /// человек сам. Поэтому «58» показано как «58» и бледное «,00», а после
  /// точки «58,» и «00»: видно, что точка нажата и чего ещё ждут.
  ({String typed, String ghost}) get entry {
    if (_typed.isEmpty) {
      // Во втором числе выражения хвоста нет: «42,00 ×» ждёт числа, и
      // бледный ноль там читался бы как уже набранный.
      return hasExpression ? (typed: '', ghost: '') : (typed: '', ghost: '0,00');
    }
    final at = _typed.indexOf('.');
    final whole = at < 0 ? _typed : _typed.substring(0, at);
    final head = formatAmount(double.parse(whole.isEmpty ? '0' : whole), decimals: 0);
    if (at < 0) return (typed: head, ghost: ',00');
    final part = _typed.substring(at + 1);
    return (typed: '$head,$part', ghost: '0' * (2 - part.length));
  }

  /// Хвост процента после числа.
  String get trail => _percent ? '%' : '';

  /// Что показывать крупно. Выражение видно целиком: человек должен видеть,
  /// что именно он считает.
  String get display {
    final e = entry;
    return '$lead${e.typed}${e.ghost}$trail'.trimRight();
  }

  void digit(String d) {
    final dot = _typed.indexOf('.');
    if (d == '.') {
      if (dot >= 0) return;
      _typed = _typed.isEmpty ? '0.' : '$_typed.';
      return;
    }
    // После точки только сотые: третья цифра копеек — это опечатка, а не
    // сумма.
    if (dot >= 0 && _typed.length - dot > 2) return;
    // Длина целой части ограничена: семь цифр это десять миллионов лей, и
    // дальше число перестаёт помещаться на экран.
    if (dot < 0 && _typed.length >= 7) return;
    // Ведущий ноль не копится: «0» и «7» дают «7», а не «07».
    _typed = _typed == '0' ? d : '$_typed$d';
  }

  void backspace() {
    if (_typed.isNotEmpty) {
      _typed = _typed.substring(0, _typed.length - 1);
      if (_typed == '0') _typed = '';
      return;
    }
    // Цифр нет — стирание снимает знак действия и возвращает первое число.
    // Иначе выражение «5 +» нельзя было бы разобрать обратно.
    if (hasExpression) {
      _typed = _typedOf(_left!);
      _left = null;
      _op = null;
      _percent = false;
    }
  }

  void operator(CalcOp op) {
    if (hasExpression && _typed.isEmpty) {
      // Второй знак подряд заменяет первый: человек передумал, а не начал
      // новое действие.
      _op = op;
      return;
    }
    if (hasExpression) equals();
    if (_typed.isEmpty && _left == null) return;
    _left = _entered;
    _op = op;
    _typed = '';
    _percent = false;
  }

  /// Доля от первого числа. Без выражения процент считать не от чего.
  void percent() {
    if (!hasExpression || _typed.isEmpty) return;
    _percent = true;
  }

  void equals() {
    if (!hasExpression) return;
    final result = _resolve();
    _left = null;
    _op = null;
    _percent = false;
    _typed = _typedOf(result);
  }

  void clear() {
    _typed = '';
    _left = null;
    _op = null;
    _percent = false;
  }

  double _resolve() {
    final left = _left ?? 0;
    if (_typed.isEmpty) return left;
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
