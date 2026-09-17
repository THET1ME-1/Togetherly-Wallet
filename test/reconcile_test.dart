import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/logic/reconcile.dart';

Transaction tx(String id, String date, double amount,
        {String? note, String? time, String currency = 'MDL'}) =>
    Transaction(
      id: id,
      date: date,
      kind: amount > 0 ? TxKind.income : TxKind.expense,
      account: 'Карта',
      currency: currency,
      amount: amount,
      amountBase: amount,
      note: note,
      time: time,
      author: 'u_me',
      payer: 'u_me',
    );

ImportedRow row(String date, double amount,
        {String note = '', String time = '', String currency = 'MDL',
        bool income = false}) =>
    ImportedRow(
      date: date,
      time: time,
      amount: amount,
      currency: currency,
      note: note,
      income: income,
    );

void main() {
  group('сверка с выпиской', () {
    test('совпавшую запись дополняет, а не создаёт вторую', () {
      final mine = [tx('a', '2026-09-12', -417.60)];
      final theirs = [
        row('2026-09-12', 417.60, note: 'Linella', time: '20:18'),
      ];
      final r = reconcile(mine, theirs);

      expect(r.matched.length, 1);
      expect(r.onlyFile, isEmpty);
      final fixed = r.matched.single.fixed;
      expect(fixed.note, 'Linella');
      expect(fixed.time, '20:18');
      expect(fixed.id, 'a', reason: 'та же запись, а не новая');
    });

    test('сдвиг даты на день не мешает: банк проводит позже', () {
      final mine = [tx('a', '2026-09-11', -100)];
      final theirs = [row('2026-09-12', 100, note: 'Кофе')];
      final r = reconcile(mine, theirs);

      expect(r.matched.length, 1);
      // Дата из выписки: она и есть настоящая.
      expect(r.matched.single.fixed.date, '2026-09-12');
    });

    test('разные суммы не склеиваются', () {
      final mine = [tx('a', '2026-09-12', -100)];
      final theirs = [row('2026-09-12', 250, note: 'Другое')];
      final r = reconcile(mine, theirs);

      expect(r.matched, isEmpty);
      expect(r.onlyFile.length, 1);
      expect(r.onlyApp.length, 1);
    });

    test('две одинаковые траты в один день сопоставляются по одной', () {
      final mine = [
        tx('a', '2026-09-12', -50),
        tx('b', '2026-09-12', -50),
      ];
      final theirs = [
        row('2026-09-12', 50, note: 'Кофе'),
        row('2026-09-12', 50, note: 'Кофе'),
      ];
      final r = reconcile(mine, theirs);
      expect(r.matched.length, 2);
      expect(r.onlyFile, isEmpty);
      expect(r.onlyApp, isEmpty);
    });

    test('чего нет в приложении — к записи, чего нет в файле — не трогаем', () {
      final mine = [tx('a', '2026-09-10', -30, note: 'Своя')];
      final theirs = [row('2026-09-12', 90, note: 'Новая')];
      final r = reconcile(mine, theirs);

      expect(r.onlyFile.single.note, 'Новая');
      expect(r.onlyApp.single.id, 'a');
    });

    test('доход не путается с тратой на ту же сумму', () {
      final mine = [tx('a', '2026-09-12', 500)];
      final theirs = [row('2026-09-12', 500, income: false)];
      final r = reconcile(mine, theirs);
      expect(r.matched, isEmpty);
    });

    test('своё описание не затирается пустым из файла', () {
      final mine = [tx('a', '2026-09-12', -70, note: 'Кофе с собой')];
      final theirs = [row('2026-09-12', 70)];
      final r = reconcile(mine, theirs);
      expect(r.matched.single.fixed.note, 'Кофе с собой');
    });

    test('запись без изменений в отчёт не попадает', () {
      final mine = [tx('a', '2026-09-12', -70, note: 'Кофе', time: '10:00')];
      final theirs = [row('2026-09-12', 70, note: 'Кофе', time: '10:00')];
      final r = reconcile(mine, theirs);
      expect(r.matched.single.changed, isFalse);
    });

    test('десять тысяч записей и тысяча строк — доли секунды', () {
      // Перебор дал бы сорок миллионов сравнений; указатель по сумме делает
      // это мгновенно, и телефон не задыхается.
      String day(int n) => n.toString().padLeft(2, '0');
      final mine = [
        for (var i = 0; i < 10000; i++)
          tx('t$i', '2026-${day(1 + i % 12)}-${day(1 + i % 28)}',
              -(1 + i % 900).toDouble()),
      ];
      final theirs = [
        for (var i = 0; i < 1000; i++)
          row('2026-09-${day(1 + i % 28)}', (1 + i % 900).toDouble(),
              note: 'Строка $i'),
      ];

      final watch = Stopwatch()..start();
      final r = reconcile(mine, theirs);
      watch.stop();

      expect(watch.elapsedMilliseconds, lessThan(1500),
          reason: 'сверка не должна вешать экран');
      expect(r.matched.length + r.onlyFile.length, 1000);
    });

    test('записи вне периода выписки лишними не считаются', () {
      final mine = [
        tx('старая', '2025-03-04', -100),
        tx('своя', '2026-09-12', -70),
      ];
      final theirs = [row('2026-09-12', 70)];
      final r = reconcile(mine, theirs);

      expect(r.matched.single.was.id, 'своя');
      expect(r.onlyApp, isEmpty,
          reason: 'прошлогодняя трата к сентябрьской выписке отношения не имеет');
    });
  });
}
