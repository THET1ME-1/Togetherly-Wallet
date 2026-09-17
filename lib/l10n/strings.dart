import 'dict/accounts.dart';
import 'dict/core.dart';
import 'dict/auth.dart';
import 'dict/debts.dart';
import 'dict/goals.dart';
import 'dict/home.dart';
import 'dict/ledger.dart';
import 'dict/budgets.dart';
import 'dict/misc.dart';
import 'dict/notices.dart';
import 'dict/operation.dart';
import 'dict/plan.dart';
import 'dict/plus.dart';
import 'dict/presets.dart';
import 'dict/language.dart';
import 'dict/rest.dart';
import 'dict/rules.dart';
import 'dict/settings.dart';
import 'dict/sheets.dart';
import 'language.dart';

/// Все строки интерфейса: ключ → язык → текст.
///
/// Устройство то же, что в Togetherly: словарь вместо класса на язык. Новый
/// язык добавляется колонкой, а не семью файлами, и ключ без перевода не
/// оставляет пустое место — он откатывается на английский.
const Map<String, Map<String, String>> kMoneyStrings = {
  ...coreStrings,
  ...authStrings,
  ...homeStrings,
  ...ledgerStrings,
  ...operationStrings,
  ...budgetStrings,
  ...goalStrings,
  ...debtStrings,
  ...planStrings,
  ...plusStrings,
  ...ruleStrings,
  ...presetStrings,
  ...settingsStrings,
  ...noticeStrings,
  ...miscStrings,
  ...accountStrings,
  ...restStrings,
  ...sheetStrings,
  ...languageStrings,
};

/// Строка по ключу на заданном языке.
///
/// Порядок отката: выбранный язык → английский → русский → сам ключ. Ключ
/// виден на экране только если его забыли завести в словаре, и это заметно
/// сразу — молчаливой пустоты не бывает.
String trDict(String key, String code) {
  final entry = kMoneyStrings[key];
  if (entry == null) return key;
  return entry[code] ?? entry['en'] ?? entry['ru'] ?? key;
}

/// Текущий язык интерфейса. Ставится один раз при запуске и при выборе
/// человека; хранится отдельно от строк, чтобы словарь остался константой.
MoneyLanguage appLanguage = MoneyLanguage.ru;

/// Строка по ключу на текущем языке.
String tr(String key) => trDict(key, appLanguage.code);

/// Форма слова при числе: `ключ.one`, `ключ.few`, `ключ.many`, `ключ.other`.
///
/// У русского три формы («одно списание», «два списания», «пять списаний»), у
/// английского две. Правило выбирается по языку, поэтому словарь держит только
/// те формы, которые языку нужны.
String trn(String base, int n) {
  final code = appLanguage.code;
  final suffix = switch (code) {
    'ru' => _slavicForm(n),
    // Во французском ноль и один берут единственное число.
    'fr' => n <= 1 ? 'one' : 'other',
    _ => n == 1 ? 'one' : 'other',
  };
  final key = '$base.$suffix';
  return kMoneyStrings.containsKey(key) ? tr(key) : tr('$base.other');
}

String _slavicForm(int n) {
  final abs = n.abs();
  final tail = abs % 100;
  if (tail >= 11 && tail <= 14) return 'many';
  return switch (abs % 10) {
    1 => 'one',
    2 || 3 || 4 => 'few',
    _ => 'many',
  };
}

/// Строка с подстановкой: `%s` заменяется по порядку.
///
/// Своя вместо `intl`: у нас подстановка ровно такая, а `.arb` с генерацией
/// потребовал бы отдельного шага сборки на каждую правку слова.
String trf(String key, List<Object?> values) {
  var out = tr(key);
  for (final v in values) {
    out = out.replaceFirst('%s', '$v');
  }
  return out;
}
