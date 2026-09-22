import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/pair_since.dart';

/// «Пара с» считается тем же правилом, что в Togetherly.
///
/// Жалоба 19.09.2026: Wallet писал «Пара с 12 августа 2026», а Togetherly —
/// «с 22 июня». Wallet брал `groups.start_date`, то есть день, когда пара
/// сошлась в приложении, а Togetherly считает от таймера «Дней вместе».
void main() {
  group('начало пары', () {
    test('правленый таймер раньше коннекта: берётся таймер', () {
      expect(
        pairSince(timer: '2026-06-22', connect: '2026-08-12'),
        '2026-06-22',
      );
    });

    test('правленый таймер позже коннекта: берётся коннект', () {
      expect(
        pairSince(timer: '2026-09-01', connect: '2026-08-12'),
        '2026-08-12',
      );
    });

    test('правленый таймер сильнее годовщины', () {
      // Свой срок человек выставил сам, годовщина его не отнимает.
      expect(
        pairSince(
          timer: '2026-06-22',
          connect: '2026-08-12',
          anniversary: '2025-02-17',
        ),
        '2026-06-22',
      );
    });

    test('нетронутый таймер: пустоту закрывает годовщина', () {
      expect(
        pairSince(
          timer: '2026-08-12',
          connect: '2026-08-12',
          anniversary: '2025-02-17',
        ),
        '2025-02-17',
      );
    });

    test('без таймера и годовщины остаётся коннект', () {
      expect(pairSince(connect: '2026-08-12'), '2026-08-12');
    });

    test('ни одной даты — пусто', () {
      expect(pairSince(), '');
    });
  });

  group('даты из записи группы', () {
    test('день системного таймера из groups.timers', () {
      final timers = [
        {
          'id': 'trip',
          'startDate': '2026-12-31T00:00:00.000',
          'isSystem': false,
          'isCountdown': true,
        },
        {
          'id': 'system',
          'startDate': '2026-06-22T14:05:00.000',
          'isSystem': true,
        },
      ];
      expect(systemTimerDay(timers), '2026-06-22');
    });

    test('таймеры строкой JSON тоже читаются', () {
      expect(
        systemTimerDay('[{"startDate":"2026-06-22T00:00:00.000","isSystem":true}]'),
        '2026-06-22',
      );
    });

    test('без системного таймера и с мусором — пусто', () {
      expect(systemTimerDay(null), '');
      expect(systemTimerDay('не json'), '');
      expect(systemTimerDay([
        {'startDate': '2026-06-22T00:00:00.000', 'isSystem': false},
      ]), '');
    });

    test('день берётся из строки как написан, без пересчёта пояса', () {
      expect(dayOf('2026-08-12 21:40:00.000Z'), '2026-08-12');
      expect(dayOf('2025-02-17'), '2025-02-17');
      expect(dayOf(''), '');
      expect(dayOf(null), '');
    });
  });

  /// «Пара с 15 июня 1026» на телефоне тестировщика 22.09.2026: в таймере
  /// Togetherly стоит опечатка в тысячелетии, а правило «берём самую раннюю»
  /// делает её победителем навсегда.
  group('опечатка в дате', () {
    test('год из прошлого тысячелетия не считается датой', () {
      expect(dayOf('1026-06-15'), '');
      expect(dayOf('0202-01-01'), '');
    });

    test('дата далёкого будущего тоже опечатка', () {
      expect(dayOf('9026-06-15'), '');
    });

    test('кривой таймер уступает коннекту, а не побеждает', () {
      expect(
        pairSince(
          timer: dayOf('1026-06-15'),
          connect: dayOf('2026-08-12'),
        ),
        '2026-08-12',
      );
    });

    test('кривой таймер в списке групп не доезжает до экрана', () {
      expect(
        systemTimerDay([
          {'startDate': '1026-06-15T00:00:00.000Z', 'isSystem': true},
        ]),
        '',
      );
    });

    test('обычные даты правило не задевает', () {
      expect(dayOf('2026-08-12'), '2026-08-12');
      expect(dayOf('1999-12-31'), '1999-12-31');
    });
  });
}
