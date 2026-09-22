import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/ui/theme/tm_theme.dart';
import 'package:togetherly_money/widgets/app_sheet.dart';

/// «И две кнопки отмена» (22.09.2026). В листе выбора решения нет: человек
/// касается строки. Большая кнопка «Отмена» повторяла текстовую под ней, и
/// лист заканчивался двумя одинаковыми словами подряд.
void main() {
  testWidgets('лист без решения показывает одну «Отмена»', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TmTheme.dark(),
      home: Scaffold(
        body: SheetScaffold(
          title: 'С кем ведём деньги',
          text: 'У каждой пары свои счета и записи',
          child: const SizedBox(height: 40),
        ),
      ),
    ));

    expect(find.text(tr('cancel')), findsOneWidget);
  });

  testWidgets('лист с решением показывает кнопку и «Отмена»', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: TmTheme.dark(),
      home: Scaffold(
        body: SheetScaffold(
          title: 'Распустить пару',
          action: 'Распустить',
          onAction: () {},
        ),
      ),
    ));

    expect(find.text('Распустить'), findsOneWidget);
    expect(find.text(tr('cancel')), findsOneWidget);
  });

  test('«Отмена» не стоит на главной кнопке ни в одном листе', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final f in sources) {
      final code = f.readAsStringSync();
      expect(code.contains("action: tr('cancel')"), isFalse,
          reason: '${f.path}: главная кнопка листа названа «Отмена»');
    }
  });
}
