import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/l10n/language.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/session.dart';

import 'tm_fonts.dart';

void main() {
  setUpAll(loadTmFonts);
  tearDown(() => appLanguage = MoneyLanguage.ru);

  group('словарь', () {
    test('у каждого ключа есть русский и английский', () {
      final noRu = <String>[];
      final noEn = <String>[];
      for (final entry in kMoneyStrings.entries) {
        if ((entry.value['ru'] ?? '').trim().isEmpty) noRu.add(entry.key);
        if ((entry.value['en'] ?? '').trim().isEmpty) noEn.add(entry.key);
      }
      expect(noRu, isEmpty, reason: 'без русского: ${noRu.join(', ')}');
      // Английский обязателен, потому что на него откатываются остальные пять
      // языков: без него человек увидел бы сам ключ.
      expect(noEn, isEmpty, reason: 'без английского: ${noEn.join(', ')}');
    });

    test('язык без перевода откатывается на английский, а не на ключ', () {
      for (final lang in MoneyLanguage.values) {
        appLanguage = lang;
        final line = tr('authSignIn');
        expect(line, isNot('authSignIn'), reason: lang.code);
        expect(line.trim(), isNotEmpty, reason: lang.code);
      }
    });

    test('неизвестный ключ виден сразу, а не превращается в пустоту', () {
      appLanguage = MoneyLanguage.en;
      expect(tr('ключа-нет'), 'ключа-нет');
    });

    test('подстановка ставит значения по порядку', () {
      appLanguage = MoneyLanguage.ru;
      expect(trf('typeWord', ['Удалить']), 'Введите слово «Удалить»');
      appLanguage = MoneyLanguage.en;
      expect(trf('typeWord', ['Delete']), 'Type the word “Delete”');
    });

    test('самостоятельные подписи начинаются с заглавной', () {
      // Правило заказчика: каждая подпись с заглавной буквы. Строчными
      // остаются только куски, которые вставляются В СЕРЕДИНУ фразы — формы
      // слов при числе, хвосты и предлоги. Такой кусок заводится сюда
      // осознанно, поэтому новый ключ по умолчанию требует заглавной.
      final fragments = {
        'authOr', 'anyCardShort', 'perMonth', 'ofAmount', 'monthsShort',
        'today', 'yesterday', 'goalOfTarget', 'goalPerDay', 'goalDueToday',
        'goalDueIn', 'goalOverdue', 'goalReserveDone', 'goalReserveLeft',
        'goalReservePerMonth', 'goalSavedAmount', 'goalLeft',
        'periodLastDay', 'periodLastWeek', 'periodLastMonth',
        'periodPerDay', 'periodPerWeek', 'periodPerMonth',
        'periodNextDay', 'periodNextWeek', 'periodNextMonth',
        'periodPerCustom', 'periodPerOnce', 'periodLastCustom', 'debtDueDayOn',
        'periodNextCustom', 'budgetDaysValue',
        'budgetOfPeriod', 'budgetLeft', 'budgetOver',
        'planLeftRow', 'planLeftToAdd', 'planUnmarked', 'planUnmarkedTail',
        'planPlannedInline', 'planOverRow', 'planMoreThanPlan',
        'recurringIntoSummary', 'accountsChosen', 'andMore', 'andMoreRows',
        'hiddenDetails', 'opensOn', 'opensLater', 'opRate', 'opMoreSubs',
        'opPaidOther', 'opPartnerDative', 'opPotLimitTail',
        'debtLeft', 'debtRateYear', 'debtTermAndInterest', 'debtDueDayShort',
        'debtNeverEndsTail', 'noticesCards', 'noticesMonthCount',
        'noticesPerMonth', 'noticesDaysAgo', 'noticesWaitingFor',
        'currencyConverted', 'agreementProposes', 'supportNote',
        'ratesMissing', 'ratesNone', 'ratesSet', 'authEmail',
        'categoryWordPlaceholder',
        // Месяц в дате идёт после числа: «12 сентября». Заголовок месяца —
        // отдельные ключи month1…month12, и они с заглавной.
        for (var m = 1; m <= 12; m++) 'monthOf$m',
        'settleTheyOwe', 'settlePartner', 'settlePartnerDative',
        // Подпись тарифа: «3 месяца» начинается с числа, а не с буквы.
        'plusQuarter',
        // Вторая строка заголовка приветствия: «Деньги вместе, / личное
        // отдельно». Это продолжение фразы, а не подпись.
        'welcomeTitleSecond',
        // Приписка к подписи поля: «ПАРОЛЬ · от 8 знаков».
        'authPasswordNote',
        // Куски описания правила разбора: они склеиваются в строку вида
        // «tucano · больше 2 000,00 · карта 0354 · расход», и заглавная
        // буква в середине такой фразы читается как новая мысль.
        'nruleFrom', 'nruleTo', 'nruleCardShort',
        'nruleIncomeShort', 'nruleExpenseShort',
        // Строка тревоги прогноза начинается с имени платежа: «Аренда
        // 28-го — 4 000,00».
        'forecastDueOn',
        // Формы слова при числе: «3 правила».
        'nrules.one', 'nrules.few', 'nrules.many', 'nrules.other',
      };
      final low = <String>[];
      for (final entry in kMoneyStrings.entries) {
        final key = entry.key;
        // Формы слова при числе — всегда куски: «два списания».
        if (key.contains('.')) continue;
        if (fragments.contains(key)) continue;
        for (final lang in ['ru', 'en']) {
          final v = (entry.value[lang] ?? '').trim();
          if (v.isEmpty) continue;
          // Начало с подстановки, числа или кавычки заглавной не требует.
          final head = v.replaceAll(RegExp(r'^[%s«“‘(≈·—\-\d ]+'), '');
          if (head.isEmpty) continue;
          final first = head[0];
          if (first.toLowerCase() == first && first.toUpperCase() != first) {
            low.add('$key.$lang');
          }
        }
      }
      expect(low, isEmpty, reason: 'со строчной: ${low.join(', ')}');
    });

    test('русский текст не затёк в английскую колонку', () {
      final cyrillic = RegExp(r'[А-Яа-яЁё]');
      final guilty = <String>[];
      for (final entry in kMoneyStrings.entries) {
        final en = entry.value['en'] ?? '';
        // «Togetherly Wallet» и подобные имена одинаковы во всех языках,
        // поэтому ищем именно кириллицу.
        if (cyrillic.hasMatch(en)) guilty.add(entry.key);
      }
      expect(guilty, isEmpty, reason: 'русский в английском: ${guilty.join(', ')}');
    });
  });

  group('язык устройства', () {
    test('русский узнаётся по языку, а не только по стране', () {
      expect(MoneyLanguage.detect(const ui.Locale('ru')), MoneyLanguage.ru);
      expect(MoneyLanguage.detect(const ui.Locale('ru', 'MD')), MoneyLanguage.ru);
    });

    test('английский телефон в Молдове говорит по-русски', () {
      // Телефон на английском — обычное дело, а обиходный язык другой.
      expect(
        MoneyLanguage.detect(const ui.Locale('en', 'MD')),
        MoneyLanguage.ru,
      );
      expect(
        MoneyLanguage.detect(const ui.Locale('en', 'BR')),
        MoneyLanguage.pt,
      );
    });

    test('незнакомый язык даёт английский', () {
      expect(MoneyLanguage.detect(const ui.Locale('ja')), MoneyLanguage.en);
    });
  });

  group('экран входа говорит на выбранном языке', () {
    testWidgets('английский', (tester) async {
      appLanguage = MoneyLanguage.en;
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      // Карты на приветствии качаются вечно: pumpAndSettle тут не годится.
      await tester.pump();

      expect(find.text('Sign in'), findsOne);
      expect(find.text('One account for every Togetherly app'), findsOne);
      expect(find.text('Войти'), findsNothing);
    });

    testWidgets('немецкий пока показывает английский, но не ключи',
        (tester) async {
      appLanguage = MoneyLanguage.de;
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      // Карты на приветствии качаются вечно: pumpAndSettle тут не годится.
      await tester.pump();

      expect(find.text('Sign in'), findsOne);
      expect(find.text('authSignIn'), findsNothing);
    });
  });

  group('строки не остаются в коде', () {
    test('ни один экран и виджет не держит русскую строку', () {
      // Строка в коде значит, что на английском человек увидит русский текст.
      // Словари (lib/l10n) и витрина макетов (lib/ui) — исключение: первые и
      // есть перевод, вторая не попадает в приложение.
      final cyrillic = RegExp(r"'[^']*[А-Яа-яЁё][^']*'");
      final guilty = <String>[];
      // Разбор русского текста переводить нельзя: это данные, а не подписи —
      // уведомления банков приходят по-русски, и подсказки категорий по
      // русским корням ищут именно их.
      const dataFiles = {
        'lib/logic/icons.dart',
        // Русские слова к значкам — тоже данные: по ним ищут, а не читают.
        // Английские имена набора MyNaUI человеку бесполезны.
        'lib/logic/icon_search.dart',
        'lib/logic/buckets.dart',
        'lib/logic/notice_parse.dart',
        'lib/logic/notice_match.dart',
        'lib/logic/query.dart',
        'lib/logic/ask.dart',
        'lib/logic/split.dart',
        'lib/logic/recurring.dart',
        'lib/logic/currencies.dart',
        // Слова фразы восстановления — данные: человек их переписывает на
        // бумагу, а не читает с экрана как подпись. Перевести их нельзя
        // вовсе: фраза, набранная на одном языке, обязана открывать снимок
        // при любом другом.
        'lib/logic/snapshot_crypto.dart',
        'lib/data/store.dart',
        'lib/data/models.dart',
        'lib/services/invite_code.dart',
        'lib/services/invite.dart',
        'lib/services/session.dart',
        'lib/services/sync.dart',
        'lib/services/live.dart',
        'lib/services/oauth.dart',
        'lib/services/push.dart',
        'lib/services/push_bg.dart',
        'lib/logic/money.dart',
      };
      for (final dir in ['lib/screens', 'lib/widgets', 'lib/logic',
                         'lib/services', 'lib']) {
        for (final file in Directory(dir).listSync(recursive: dir != 'lib')) {
          if (file is! File || !file.path.endsWith('.dart')) continue;
          if (dataFiles.contains(file.path)) continue;
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final trimmed = lines[i].trimLeft();
            if (trimmed.startsWith('//')) continue;
            if (cyrillic.hasMatch(lines[i])) guilty.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(guilty, isEmpty, reason: 'строки в коде: ${guilty.join(', ')}');
    });

    test('экран входа и листы переведены целиком', () {
      // Эти два места переведены первыми: их видит каждый, кто открыл
      // приложение. Русская строка в коде здесь — забытый ключ.
      final cyrillic = RegExp(r"'[^']*[А-Яа-яЁё][^']*'");
      final guilty = <String>[];
      for (final path in [
        'lib/screens/welcome_screen.dart',
        'lib/widgets/app_sheet.dart',
      ]) {
        final code = File(path).readAsLinesSync();
        for (var i = 0; i < code.length; i++) {
          final line = code[i];
          // Комментарии не считаем: они для нас, а не для человека.
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (cyrillic.hasMatch(line)) guilty.add('$path:${i + 1}');
        }
      }
      expect(guilty, isEmpty, reason: 'строки в коде: ${guilty.join(', ')}');
    });
  });
}
