import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/plus.dart';
import 'package:togetherly_money/logic/plus_usage.dart';

/// Счёт до потолка.
///
/// Правило человека 17.09.2026: у каждого платного, где есть число, человек
/// видит счёт ДО того, как упрётся, а стена встаёт в момент действия. Поэтому
/// счёт и решение калитки обязаны считаться одним местом: два счёта в двух
/// экранах разъедутся на первой же правке потолка.

Database dbOf({
  int budgets = 0,
  int goals = 0,
  int debts = 0,
  int recurring = 0,
}) =>
    Database(
      budgets: [
        for (var i = 0; i < budgets; i++)
          Budget(
            category: 'Категория $i',
            limit: 1000,
            currency: 'MDL',
            period: 'monthly',
          ),
      ],
      goals: [
        for (var i = 0; i < goals; i++)
          Goal(name: 'Цель $i', target: 5000, currency: 'MDL'),
      ],
      debts: [
        for (var i = 0; i < debts; i++)
          Debt(name: 'Долг $i', principal: 1000, currency: 'MDL'),
      ],
      recurring: [
        for (var i = 0; i < recurring; i++)
          Recurring(
            id: 'r$i',
            name: 'Платёж $i',
            amount: 100,
            currency: 'MDL',
            account: 'Карта',
            interval: 'monthly',
            nextDate: '2026-10-01',
            kind: 'payment',
            active: true,
          ),
      ],
    );

void main() {
  group('счёт до потолка', () {
    test('пустая база: занято ноль, осталось всё', () {
      final c = plusCount(PlusGate.envelope, plus: false, db: dbOf());
      expect(c, isNotNull);
      expect(c!.have, 0);
      expect(c.limit, PlusLimits.envelopes);
      expect(c.left, PlusLimits.envelopes);
      expect(c.full, isFalse);
    });

    test('потолок занят: осталось ноль и стена', () {
      final c = plusCount(PlusGate.envelope,
          plus: false, db: dbOf(budgets: PlusLimits.envelopes));
      expect(c!.left, 0);
      expect(c.full, isTrue);
    });

    test('заведено больше потолка: остаток не уходит в минус', () {
      // Так живёт человек, у которого конверты были до появления подписки:
      // отобрать выданное нельзя, но и «осталось −2» показывать бессмысленно.
      final c = plusCount(PlusGate.envelope, plus: false, db: dbOf(budgets: 7));
      expect(c!.have, 7);
      expect(c.left, 0);
      expect(c.full, isTrue);
    });

    test('у подписчика счётчика нет вовсе', () {
      // Напоминать о потолке, который человек снял деньгами, незачем.
      for (final gate in PlusGate.values) {
        expect(plusCount(gate, plus: true, db: dbOf(budgets: 3), asked: 1),
            isNull,
            reason: 'калитка $gate');
      }
    });

    test('каждая калитка с числом считает свой список', () {
      final db = dbOf(budgets: 1, goals: 2, debts: 1, recurring: 3);
      expect(plusCount(PlusGate.envelope, plus: false, db: db)!.have, 1);
      expect(plusCount(PlusGate.goal, plus: false, db: db)!.have, 2);
      expect(plusCount(PlusGate.debt, plus: false, db: db)!.have, 1);
      expect(plusCount(PlusGate.recurring, plus: false, db: db)!.have, 3);
    });

    test('вопросы и файлы считает сервер, а не база', () {
      // База о них не знает ничего: расход живёт в money_ai_usage, иначе
      // потолок снимался бы переустановкой приложения.
      final asked = plusCount(PlusGate.chat, plus: false, asked: 2);
      expect(asked!.have, 2);
      expect(asked.limit, PlusLimits.asksPerDay);
      expect(asked.left, 1);

      final files =
          plusCount(PlusGate.files, plus: false, files: PlusLimits.filesPerMonth);
      expect(files!.full, isTrue);
    });

    test('сервер ещё не ответил — счётчика нет, но и стены нет', () {
      // Пока число не приехало, врать «осталось 3» нельзя: человек мог
      // потратить их на другом телефоне.
      expect(plusCount(PlusGate.chat, plus: false), isNull);
      expect(plusCount(PlusGate.files, plus: false), isNull);
    });

    test('у калитки без числа счёта нет', () {
      for (final gate in [
        PlusGate.lock,
        PlusGate.report,
        PlusGate.monthReview,
        PlusGate.looks,
        PlusGate.cloudBackups,
        PlusGate.autoNotices,
        PlusGate.noticeRules,
        PlusGate.planAhead,
      ]) {
        expect(plusCount(gate, plus: false, db: dbOf(budgets: 9)), isNull,
            reason: 'калитка $gate');
      }
    });

    test('база не передана — счёта нет, падать нельзя', () {
      // Витрина и стена зовут счёт без базы: там она не нужна.
      expect(plusCount(PlusGate.envelope, plus: false), isNull);
    });
  });
}
