import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/services/crash.dart';

/// Сбор падений.
///
/// Перед закрытым тестированием (18.09.2026): «сделай сбор багов и чтобы
/// понятно было, что это именно Wallet». Отсюда три требования, которые легко
/// нарушить молча.

void main() {
  test('без адреса приёма ничего не собирается', () async {
    // DSN приходит сборкой. Форк, собранный из открытых исходников, не должен
    // слать свои падения в нашу панель, а отладочные запуски — засорять её.
    expect(Crash.enabled, isFalse);

    var started = false;
    await Crash.run(() async => started = true);
    expect(started, isTrue, reason: 'приложение обязано стартовать и так');
  });

  group('сетевой шум не считается падением', () {
    test('обрыв сокета', () {
      expect(Crash.noiseForTest(const SocketException('reset by peer')), isTrue);
    });

    test('таймаут запроса', () {
      expect(Crash.noiseForTest(TimeoutException('ждали 20 с')), isTrue);
    });

    test('мёртвый DNS и отказ соединения', () {
      // У Togetherly такие записи тоннами забивали панель и топили настоящие
      // ошибки: это беда сети человека, а не приложения.
      expect(Crash.noiseForTest(Exception('Failed host lookup: togetherly.day')), isTrue);
      expect(Crash.noiseForTest(Exception('Connection refused')), isTrue);
      expect(Crash.noiseForTest(Exception('HandshakeException: сертификат')), isTrue);
    });

    test('настоящая ошибка проходит', () {
      expect(Crash.noiseForTest(StateError('Null check operator used on a null value')),
          isFalse);
      expect(Crash.noiseForTest(RangeError.index(5, [1, 2])), isFalse);
      expect(Crash.noiseForTest(null), isFalse);
    });
  });
}
