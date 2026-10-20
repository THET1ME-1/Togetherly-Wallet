import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Wallet объявлен только для iPhone, как Togetherly.
///
/// Сборка «для iPhone и iPad» обязывает к снимкам iPad 13" в App Store, а
/// верстать под планшет нечего: на iPad приложение идёт окном iPhone. Решение
/// владельца 20.10.2026.
void main() {
  test('Все настройки проекта iOS собирают приложение только для iPhone', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = "?([0-9,]+)"?;')
        .allMatches(project)
        .map((m) => m.group(1))
        .toList();
    expect(families, isNotEmpty, reason: 'в проекте не нашлось семейства устройств');
    expect(families, everyElement('1'), reason: '1 — iPhone, 2 — iPad');
  });
}
