import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/calc.dart';

void main() {
  group('счётная клавиатура', () {
    test('цифры набираются копейками, как было раньше', () {
      final c = Calc()..digit('5')..digit('0')..digit('0')..digit('0');
      expect(c.value, 50.0);
      expect(c.display, '50,00');
    });

    test('ноль в начале не копится', () {
      final c = Calc()..digit('0')..digit('0')..digit('7');
      expect(c.value, 0.07);
    });

    test('стирание убирает последнюю цифру', () {
      final c = Calc()..digit('4')..digit('2')..digit('0')..digit('0');
      c.backspace();
      expect(c.value, 4.20);
      c.backspace();
      expect(c.value, 0.42);
    });

    test('умножение показывает выражение и ждёт второе число', () {
      final c = Calc()..digit('4')..digit('2')..digit('0')..digit('0');
      c.operator(CalcOp.times);
      expect(c.hasExpression, isTrue);
      expect(c.display, '42,00 ×');
      c..digit('2')..digit('0')..digit('0');
      expect(c.display, '42,00 × 2,00');
    });

    test('равно считает произведение', () {
      final c = Calc()..digit('4')..digit('2')..digit('0')..digit('0');
      c.operator(CalcOp.times);
      c..digit('2')..digit('0')..digit('0');
      c.equals();
      expect(c.value, 84.0);
      expect(c.hasExpression, isFalse);
      expect(c.display, '84,00');
    });

    test('сложение, вычитание и деление', () {
      double run(CalcOp op, String a, String b) {
        final c = Calc();
        for (final d in a.split('')) {
          c.digit(d);
        }
        c.operator(op);
        for (final d in b.split('')) {
          c.digit(d);
        }
        c.equals();
        return c.value;
      }

      expect(run(CalcOp.plus, '1000', '250'), 12.50);
      expect(run(CalcOp.minus, '1000', '250'), 7.50);
      expect(run(CalcOp.divide, '1000', '200'), 5.0);
    });

    test('деление на ноль не роняет и оставляет первое число', () {
      final c = Calc()..digit('1')..digit('0')..digit('0');
      c.operator(CalcOp.divide);
      c.digit('0');
      c.equals();
      expect(c.value, 1.0);
      expect(c.hasExpression, isFalse);
    });

    test('процент берёт долю от первого числа', () {
      // «1000 + 10%» — это 1000 плюс десять процентов от тысячи.
      final c = Calc()..digit('1')..digit('0')..digit('0')..digit('0')..digit('0')..digit('0');
      c.operator(CalcOp.plus);
      c..digit('1')..digit('0')..digit('0')..digit('0');
      c.percent();
      c.equals();
      expect(c.value, 1100.0);
    });

    test('второй знак действия подряд заменяет первый', () {
      final c = Calc()..digit('1')..digit('0')..digit('0');
      c.operator(CalcOp.plus);
      c.operator(CalcOp.times);
      expect(c.display, '1,00 ×');
    });

    test('знак действия без числа ничего не начинает', () {
      final c = Calc()..operator(CalcOp.times);
      expect(c.hasExpression, isFalse);
      expect(c.value, 0);
    });

    test('стирание закрывает выражение, а не портит его', () {
      final c = Calc()..digit('5')..digit('0')..digit('0');
      c.operator(CalcOp.plus);
      c.backspace();
      expect(c.hasExpression, isFalse);
      expect(c.value, 5.0);
    });

    test('готовое значение продолжает считаться', () {
      final c = Calc()..digit('1')..digit('0')..digit('0');
      c.operator(CalcOp.plus);
      c..digit('1')..digit('0')..digit('0');
      c.equals();
      expect(c.value, 2.0);
      c.operator(CalcOp.times);
      c..digit('3')..digit('0')..digit('0');
      c.equals();
      expect(c.value, 6.0);
    });

    test('начальное значение берётся при правке операции', () {
      final c = Calc.of(84.0);
      expect(c.value, 84.0);
      expect(c.display, '84,00');
      c.backspace();
      expect(c.value, 8.40);
    });
  });
}
