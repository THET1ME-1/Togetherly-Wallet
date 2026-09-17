import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/haptics.dart';

/// Тактильные отклики.
///
/// Проверяется не «вибрирует ли телефон» — этого в тесте не увидеть, — а три
/// вещи, которые ломаются молча:
///
/// * разным событиям отвечает РАЗНАЯ сила. Одинаковый отклик на «записал» и
///   «удалил» хуже, чем его отсутствие: палец перестаёт их различать;
/// * отклик идёт СВОИМ мотором. Системный щелчок (`CLOCK_TICK`,
///   `VIRTUAL_KEY`) прошивки вроде Xiaomi глушат вместе с виброоткликом
///   касаний, и человек не чувствует ничего — так и вышло 17.09.2026;
/// * мотора нет — отклик достаётся системе, и канал больше не тревожим.

const _own = MethodChannel('money/haptics');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final motorCalls = <String>[];
  final systemCalls = <String>[];
  bool hasMotor = true;

  void wireMotor() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_own, (call) async {
      if (call.method != 'buzz') return null;
      motorCalls.add(call.arguments['kind'] as String);
      return hasMotor;
    });
  }

  setUp(() {
    motorCalls.clear();
    systemCalls.clear();
    hasMotor = true;
    Tap.resetForTest();
    wireMotor();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        systemCalls.add('${call.arguments}');
      }
      return null;
    });
  });

  test('у выбора, дела, отказа и праздника разная сила', () {
    Tap.pick();
    Tap.done();
    Tap.warn();
    Tap.cheer();
    expect(motorCalls, hasLength(4));
    expect(motorCalls.toSet(), hasLength(4), reason: 'отклики обязаны отличаться');
  });

  test('отклик играет свой мотор, а не системный щелчок', () async {
    Tap.pick();
    await pumpEventQueue();
    expect(motorCalls, ['pick']);
    expect(systemCalls, isEmpty, reason: 'системный щелчок глушат прошивки');
  });

  test('мотора нет — отклик достаётся системе', () async {
    hasMotor = false;
    Tap.pick();
    await pumpEventQueue();
    expect(systemCalls.single, contains('selectionClick'));
  });

  test('канала нет вовсе — отклик достаётся системе', () async {
    // iOS, десктоп, старая сборка: моста нет, и вызов бросает.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_own, null);
    Tap.done();
    await pumpEventQueue();
    expect(systemCalls.single, contains('lightImpact'));
  });

  test('после отказа мотора канал больше не тревожим', () async {
    hasMotor = false;
    Tap.pick();
    await pumpEventQueue();
    expect(motorCalls, hasLength(1));

    Tap.done();
    Tap.warn();
    await pumpEventQueue();
    expect(motorCalls, hasLength(1), reason: 'канал спросили один раз');
    expect(systemCalls, hasLength(3));
  });
}
