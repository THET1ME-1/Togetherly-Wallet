import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/plus.dart';

/// Сторож витрины: обещанное подпиской обязано быть закрыто кодом.
///
/// 17.09.2026 в приложении нашлось ровно обратное: витрина Wallet+ обещала
/// двенадцать пунктов, а из тринадцати калиток вызывались четыре. Девять
/// функций либо раздавались бесплатно, либо не существовали вовсе — человек
/// платил 799 ₽ и не находил половину купленного.
///
/// Тест проходит по `lib` статически и требует, чтобы у каждой калитки был
/// хотя бы один вызов из живого кода. Список `notYet` — то, что ещё не
/// подключено; он обязан ПУСТЕТЬ. Дописывать в него новую калитку нельзя:
/// это ровно та дорога, которой витрина и разошлась с приложением.

/// Калитки, у которых кода пока нет.
///
/// Список ПУСТ с 17.09.2026: все двенадцать обещаний витрины закрыты кодом.
/// Дописывать сюда новую калитку нельзя — это ровно та дорога, которой
/// витрина и разошлась с приложением. Завели обещание — закройте его тем же
/// днём.
const notYet = <PlusGate>{};

/// Где калитки только ОБЪЯВЛЕНЫ. Упоминание здесь вызовом не считается.
const declarations = {
  'lib/logic/plus.dart',
  'lib/logic/plus_usage.dart',
  'lib/widgets/plus_gate.dart',
};

void main() {
  final code = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (declarations.contains(f.path)) continue;
    code[f.path] = f.readAsStringSync();
  }

  test('у каждой калитки есть вызов из экрана', () {
    final missing = <PlusGate>[];
    for (final gate in PlusGate.values) {
      final needle = 'PlusGate.${gate.name}';
      final used = code.values.any((src) => src.contains(needle));
      if (!used) missing.add(gate);
    }
    final unexpected = missing.where((g) => !notYet.contains(g)).toList();
    expect(unexpected, isEmpty,
        reason: 'калитка обещана витриной, но не вызывается ниоткуда: '
            '${unexpected.map((g) => g.name).join(', ')}');
  });

  test('список долгов не врёт: закрытая калитка из него убрана', () {
    // Иначе долг живёт в списке вечно, и сторож перестаёт сторожить.
    final done = <PlusGate>[];
    for (final gate in notYet) {
      final needle = 'PlusGate.${gate.name}';
      if (code.values.any((src) => src.contains(needle))) done.add(gate);
    }
    expect(done, isEmpty,
        reason: 'калитка уже работает, уберите её из notYet: '
            '${done.map((g) => g.name).join(', ')}');
  });

  test('у каждой калитки есть своя причина словами', () {
    // «Оформите подписку» без причины злит; ключ строки обязан существовать у
    // каждой калитки, включая новые.
    for (final gate in PlusGate.values) {
      expect(plusGateKey(gate), isNotEmpty, reason: gate.name);
    }
  });
}
