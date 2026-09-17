import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Настоящие Onest и Unbounded вместо тестовой заглушки Ahem.
///
/// Без этого каждый глиф в тесте — квадрат шириной в кегль, и проверка
/// переполнений меряет не тот текст, который увидит человек.
///
/// Myna и MynaSolid здесь по той же причине: знаки набора лежат в проекте, и
/// без загрузки на их месте в кадре пустота.
Future<void> loadTmFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final family in const ['Onest', 'Unbounded', 'Myna', 'MynaSolid']) {
    final bytes = File('assets/fonts/$family.ttf').readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }

  // Значки в тесте иначе рисуются пустыми квадратами: шрифт MaterialIcons
  // лежит в кэше SDK, а не в проекте. Для проверки раскладки это важно —
  // квадрат и настоящий глиф занимают разную ширину.
  final sdk = Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/snap/flutter/common/flutter';
  final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
}
