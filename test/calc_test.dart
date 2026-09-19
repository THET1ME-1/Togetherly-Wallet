import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/calc.dart';

void main() {
  group('счётная клавиатура', () {
    test('цифры набираются целыми: «1» это рубль, а не копейка', () {
      // До 19.09.2026 набор шёл копейками, и «1» давало 0,01.
      final c = Calc()..digit('1');
      expect(c.value, 1.0);
      expect(c.display, '1,00');
      c..digit('5')..digit('0');
      expect(c.value, 150.0);
    });

    test('точка отделяет копейки: «58.12» это 58,12', () {
      final c = Calc()
        ..digit('5')
        ..digit('8')
        ..digit('.')
        ..digit('1')
        ..digit('2');
      expect(c.value, 58.12);
      expect(c.display, '58,12');
    });

    test('ненабранные копейки идут бледным хвостом', () {
      final c = Calc();
      expect(c.entry, (typed: '', ghost: '0,00'));
      c..digit('5')..digit('8');
      expect(c.entry, (typed: '58', ghost: ',00'));
      c.digit('.');
      expect(c.entry, (typed: '58,', ghost: '00'));
      c.digit('1');
      expect(c.entry, (typed: '58,1', ghost: '0'));
      expect(c.value, 58.1);
    });

    test('вторая точка и третья цифра копеек не принимаются', () {
      final c = Calc()
        ..digit('1')
        ..digit('.')
        ..digit('.')
        ..digit('9')
        ..digit('9')
        ..digit('9');
      expect(c.value, 1.99);
    });

    test('точка первой даёт «0,»', () {
      final c = Calc()..digit('.')..digit('5');
      expect(c.value, 0.5);
      expect(c.entry.typed, '0,5');
    });

    test('ноль в начале не копится', () {
      final c = Calc()..digit('0')..digit('0')..digit('7');
      expect(c.value, 7.0);
      expect(c.entry.typed, '7');
    });

    test('целая часть не длиннее семи цифр', () {
      final c = Calc();
      for (var i = 0; i < 9; i++) {
        c.digit('9');
      }
      expect(c.value, 9999999.0);
      c..digit('.')..digit('5');
      expect(c.value, 9999999.5);
    });

    test('тысячи разделены пробелом и пока набираются', () {
      final c = Calc();
      for (final d in '12345'.split('')) {
        c.digit(d);
      }
      expect(c.entry.typed, '12\u00A0345');
    });

    test('стирание убирает последний знак, точку тоже', () {
      final c = Calc()..digit('4')..digit('2')..digit('.')..digit('5');
      c.backspace();
      expect(c.entry.typed, '42,');
      expect(c.value, 42.0);
      c.backspace();
      expect(c.entry.typed, '42');
      c.backspace();
      expect(c.value, 4.0);
    });

    test('умножение показывает выражение и ждёт второе число', () {
      final c = Calc()..digit('4')..digit('2');
      c.operator(CalcOp.times);
      expect(c.hasExpression, isTrue);
      expect(c.display, '42,00 ×');
      c.digit('2');
      expect(c.display, '42,00 × 2,00');
    });

    test('равно считает произведение', () {
      final c = Calc()..digit('4')..digit('2');
      c.operator(CalcOp.times);
      c.digit('2');
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

      expect(run(CalcOp.plus, '10', '2.5'), 12.50);
      expect(run(CalcOp.minus, '10', '2.5'), 7.50);
      expect(run(CalcOp.divide, '10', '2'), 5.0);
      expect(run(CalcOp.divide, '10', '3'), 3.33);
    });

    test('деление на ноль не роняет и оставляет первое число', () {
      final c = Calc()..digit('1');
      c.operator(CalcOp.divide);
      c.digit('0');
      c.equals();
      expect(c.value, 1.0);
      expect(c.hasExpression, isFalse);
    });

    test('процент берёт долю от первого числа', () {
      // «1000 + 10%» — это 1000 плюс десять процентов от тысячи.
      final c = Calc()..digit('1')..digit('0')..digit('0')..digit('0');
      c.operator(CalcOp.plus);
      c..digit('1')..digit('0');
      c.percent();
      c.equals();
      expect(c.value, 1100.0);
    });

    test('второй знак действия подряд заменяет первый', () {
      final c = Calc()..digit('1');
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
      final c = Calc()..digit('5');
      c.operator(CalcOp.plus);
      c.backspace();
      expect(c.hasExpression, isFalse);
      expect(c.value, 5.0);
    });

    test('готовое значение продолжает считаться', () {
      final c = Calc()..digit('1');
      c.operator(CalcOp.plus);
      c.digit('1');
      c.equals();
      expect(c.value, 2.0);
      c.operator(CalcOp.times);
      c.digit('3');
      c.equals();
      expect(c.value, 6.0);
    });

    test('начальное значение берётся при правке операции', () {
      final c = Calc.of(84.0);
      expect(c.value, 84.0);
      expect(c.display, '84,00');
      c.backspace();
      expect(c.value, 8.0);
    });

    test('правка суммы с копейками стирает сотые, а не рубли', () {
      final c = Calc.of(58.12);
      expect(c.entry, (typed: '58,12', ghost: ''));
      c.backspace();
      expect(c.value, 58.1);
    });

    test('после «=» набор продолжается с результата', () {
      final c = Calc()..digit('1')..digit('0');
      c.operator(CalcOp.divide);
      c.digit('4');
      c.equals();
      expect(c.entry, (typed: '2,50', ghost: ''));
      c.backspace();
      expect(c.value, 2.5);
    });
  });
}
