import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/ui/theme/tm_scheme.dart';
import 'package:togetherly_money/widgets/settings_kit.dart';
import 'package:togetherly_money/ui/theme/tm_theme.dart';
import 'package:togetherly_money/design/myna.dart';

/// Правила системы, которые нельзя нарушить незаметно. Каждое здесь потому,
/// что уже ломалось: тени, конфликт shape и borderRadius, светлый цвет текста
/// в тёмной теме, тап меньше 44.
void main() {
  final lib = Directory('lib');
  final sources = lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('теней нет нигде', () {
    for (final f in sources) {
      final code = f.readAsStringSync();
      expect(code.contains('BoxShadow'), isFalse, reason: '${f.path}: BoxShadow');
      expect(RegExp(r'elevation:\s*[1-9]').hasMatch(code), isFalse,
          reason: '${f.path}: elevation > 0');
    }
  });

  test('Material не получает shape и borderRadius разом', () {
    // material.dart:209 валит такое ассертом, и экран встаёт красным
    // в отладке, а в релизе молчит. Так уже ломался экран виджетов Togetherly.
    final re = RegExp(r'Material\((?:[^()]|\([^()]*\))*\)', dotAll: true);
    for (final f in sources) {
      for (final m in re.allMatches(f.readAsStringSync())) {
        final body = m.group(0)!;
        final both = body.contains('shape:') && body.contains('borderRadius:');
        expect(both, isFalse, reason: '${f.path}: Material с shape и borderRadius');
      }
    }
  });

  test('экраны не красят текст светлыми константами палитры', () {
    // TmColors.ink на тёмной поверхности даёт 1.2:1. Цвет берётся из
    // context.tm, а прямая константа допустима только поверх пастели.
    final screens = sources.where((f) => f.path.contains('/screens/'));
    for (final f in screens) {
      final code = f.readAsStringSync();
      for (final bad in ['TmColors.cream', 'TmColors.inkPale', 'TmColors.lineSoft']) {
        expect(code.contains(bad), isFalse, reason: '${f.path}: $bad вместо роли темы');
      }
    }
  });

  testWidgets('тёмная тема даёт светлый текст, светлая — тёмный', (tester) async {
    late TmPalette night;
    late TmPalette day;
    await tester.pumpWidget(MaterialApp(
      theme: TmTheme.light(),
      home: Builder(builder: (c) {
        day = c.tm;
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MaterialApp(
      theme: TmTheme.dark(),
      home: Builder(builder: (c) {
        night = c.tm;
        return const SizedBox();
      }),
    ));

    expect(_contrast(day.text, day.bg), greaterThan(4.5));
    expect(_contrast(day.text, day.card), greaterThan(4.5));
    expect(_contrast(night.text, night.bg), greaterThan(4.5));
    expect(_contrast(night.text, night.card), greaterThan(4.5));
  });


  /// Буквы цвета заливки поверх заливки того же семейства — это и есть
  /// «чёрное на чёрном». Ловится статически: `onAccent` и его синонимы
  /// (`onSecondaryContainer`, `onPrimaryContainer`) законны ТОЛЬКО там, где
  /// рядом задан сам акцент. Экранов много, глазами это не пересмотреть —
  /// три места пережили обход 14.09.2026 и всплыли у человека на телефоне.
  test('буквы акцента не ложатся на серую заливку', () {
    // Цвет букв → семейство, к которому он принадлежит.
    const ink = {
      'onSecondaryContainer': 'accent',
      'onPrimaryContainer': 'accent',
      'onAccent': 'accent',
    };
    // Заливка → её семейство.
    const fill = {
      'secondaryContainer': 'accent',
      'primaryContainer': 'accent',
      'tm.accent': 'accent',
      'p.accent': 'accent',
      'accent,': 'accent',
      'surfaceContainerHighest': 'surface',
      'surfaceContainerHigh': 'surface',
      'surfaceContainer': 'surface',
      'tm.field': 'surface',
      'tm.card': 'surface',
      'p.field': 'surface',
      'p.card': 'surface',
    };

    final bad = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final lines = file.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (!line.toLowerCase().contains('color')) continue;
        final inkHit = ink.keys.where(line.contains);
        if (inkHit.isEmpty) continue;

        // Заливку ищем в том же виджете: двадцать строк выше.
        final window = lines.sublist(i - 20 < 0 ? 0 : i - 20, i).join('\n');
        final families = <String>{};
        for (final e in fill.entries) {
          final painted = RegExp(
            r'(color|fillColor|backgroundColor|indicatorColor|selectedColor)'
            r'\s*:\s*[^;]*' + RegExp.escape(e.key),
          );
          if (painted.hasMatch(window)) families.add(e.value);
        }
        // Акцента рядом нет, а серая заливка есть — буквы сольются с ней.
        if (families.length == 1 && families.first == 'surface') {
          bad.add('${file.path}:${i + 1}  ${line.trim()}');
        }
      }
    }

    expect(bad, isEmpty,
        reason: 'буквы акцента поверх серой заливки:\n${bad.join('\n')}');
  });

  test('тема обнуляет тень', () {
    expect(TmTheme.light().shadowColor.a, 0);
    expect(TmTheme.dark().shadowColor.a, 0);
  });

  testWidgets('блоки в группе настроек одной ширины', (tester) async {
    // Колонка по умолчанию центрирует детей, и блок с сегментами выходил уже
    // соседних строк. Замечено человеком дважды — теперь ловится тестом.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            SettingsGroup([
              const SettingsBlock(child: Text('Короткое')),
              const SettingsRow(icon: Myna.swatches, title: 'Строка'),
              SettingsBlock(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Раз')),
                    ButtonSegment(value: 2, label: Text('Два')),
                  ],
                  selected: const {1},
                  onSelectionChanged: (_) {},
                ),
              ),
            ]),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Меряем сами пункты, а не любой Material внутри: у сегментов есть свой,
    // и он законно меньше.
    final widths = <double>{
      for (final f in [find.byType(SettingsBlock), find.byType(SettingsRow)])
        for (final w in tester.widgetList<Widget>(f))
          tester.getSize(find.byWidget(w)).width,
    };

    expect(widths.length, 1, reason: 'блоки группы разъехались по ширине: $widths');
  });

  group('попапы снизу, а не по центру', () {
    test('в приложении нет ни одного showDialog', () {
      // Правило системы: спрашивают нижним листом. Диалог по центру мелкий,
      // кнопки в углу, и до них надо тянуться через полэкрана — заказчик
      // отверг это прямо 12.09.2026.
      final guilty = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final code = file.readAsStringSync();
        if (code.contains('showDialog') || code.contains('AlertDialog(')) {
          guilty.add(file.path);
        }
      }
      expect(guilty, isEmpty, reason: 'попапы по центру: ${guilty.join(', ')}');
    });

    test('подписи полей не прячутся в labelText', () {
      // Тема ставит `floatingLabelBehavior: never` — заливка с рамкой режет
      // под плавающую подпись щель, которой нет. Поэтому `labelText` в этом
      // приложении НЕ ВИДЕН НИКОГДА, и поле с ним выглядит безымянным. Так и
      // вышло с вкладом в цель: человек видел пустое поле с подсказкой «500»
      // и спрашивал, почему сумма только в системной валюте (17.09.2026).
      // Подпись ставится строкой над полем, валюта — в самом поле суммы.
      final guilty = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final code = file.readAsStringSync();
        for (final line in code.split('\n')) {
          // Свои темы задают `labelTextStyle` у навигации — это другое поле.
          if (line.contains('labelText:')) guilty.add('${file.path}: ${line.trim()}');
        }
      }
      expect(guilty, isEmpty, reason: 'подпись не увидят: ${guilty.join(' | ')}');
    });

    test('все листы открываются с useSafeArea', () {
      // Нижний край листа не должен уезжать под кнопочную панель навигации.
      final guilty = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final code = file.readAsStringSync();
        var at = code.indexOf('showModalBottomSheet');
        while (at >= 0) {
          final tail = code.substring(at, (at + 600).clamp(0, code.length));
          if (!tail.contains('useSafeArea')) guilty.add('${file.path}:$at');
          at = code.indexOf('showModalBottomSheet', at + 1);
        }
      }
      expect(guilty, isEmpty, reason: 'листы без safe area: ${guilty.join(', ')}');
    });
  });
}

double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final l1 = lum(a);
  final l2 = lum(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);

}
