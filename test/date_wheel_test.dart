import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/date_wheel.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/logic/stats.dart';
import 'package:togetherly_money/widgets/date_wheel_sheet.dart';

import 'tm_fonts.dart';

Transaction tx(String id, String date, {String? time}) => Transaction(
      id: id,
      date: date,
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -100,
      amountBase: -100,
      time: time,
    );

void main() {
  setUpAll(loadTmFonts);

  group('счёт дней', () {
    test('февраль знает про високосный год', () {
      expect(DateWheel.daysInMonth(2026, 2), 28);
      expect(DateWheel.daysInMonth(2028, 2), 29);
      expect(DateWheel.daysInMonth(2000, 2), 29);
      expect(DateWheel.daysInMonth(1900, 2), 28);
    });

    test('31-е не уезжает в следующий месяц', () {
      // `DateTime(2026, 2, 31)` даёт 3 марта — ровно та ошибка, ради которой
      // счёт вынесен отдельно.
      expect(DateWheel.build(year: 2026, month: 2, day: 31).day, 28);
      expect(DateWheel.build(year: 2026, month: 4, day: 31).month, 4);
      expect(DateWheel.build(year: 2026, month: 4, day: 31).day, 30);
    });

    test('день прижимается к границам месяца', () {
      expect(DateWheel.clampDay(0, 2026, 9), 1);
      expect(DateWheel.clampDay(45, 2026, 9), 30);
      expect(DateWheel.clampDay(15, 2026, 9), 15);
    });
  });

  group('время операции', () {
    test('без времени операция стоит в начале дня', () {
      final t = tx('a', '2026-09-13');
      expect(t.at, DateTime(2026, 9, 13));
    });

    test('время читается и складывается с датой', () {
      final t = tx('a', '2026-09-13', time: '14:35');
      expect(t.at, DateTime(2026, 9, 13, 14, 35));
    });

    test('внутри дня лента строится по времени', () {
      final db = Database(
        baseCurrency: 'MDL',
        accounts: const [Account(name: 'Карта', currency: 'MDL')],
        transactions: [
          tx('вечер', '2026-09-13', time: '21:00'),
          tx('утро', '2026-09-13', time: '08:15'),
          tx('без времени', '2026-09-13'),
        ],
      );

      final newestFirst = visible(db, Period.month(DateTime(2026, 9, 13)),
          sort: LedgerSort.dateDesc);
      expect(newestFirst.map((t) => t.id).toList(),
          ['вечер', 'утро', 'без времени']);

      final oldestFirst = visible(db, Period.month(DateTime(2026, 9, 13)),
          sort: LedgerSort.dateAsc);
      expect(oldestFirst.map((t) => t.id).toList(),
          ['без времени', 'утро', 'вечер']);
    });

    test('время переживает запись в файл и чтение обратно', () {
      final t = tx('a', '2026-09-13', time: '14:35');
      final back = Transaction.fromJson(t.toJson());
      expect(back.time, '14:35');
      // Пустое время не превращается в строку из пробела.
      expect(Transaction.fromJson(tx('b', '2026-09-13').toJson()).time, isNull);
    });
  });

  group('барабан вместо календаря', () {
    testWidgets('лист открывается и отдаёт выбранную дату', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showDateWheel(
                    context,
                    title: 'Когда',
                    initial: DateTime(2026, 9, 13),
                  );
                },
                child: const Text('открыть'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      // Барабан показывает месяц словом, а не клетками календаря.
      expect(find.text(monthName(9)), findsWidgets);
      expect(find.text(tr('wheelToday')), findsOneWidget);

      await tester.tap(find.text(tr('wheelDone')));
      await tester.pumpAndSettle();
      expect(picked, DateTime(2026, 9, 13));
    });
  });
}
