import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models.dart';
import 'money.dart';
import 'query.dart';

enum Provider { deepseek, openrouter, gemini, claude }

/// Куда стучаться. Держим тех, кто пускает приложение напрямую: своего сервера
/// у Орбиты нет и заводить его незачем.
const _where = {
  Provider.deepseek: ('https://api.deepseek.com/chat/completions', 'deepseek-chat'),
  Provider.openrouter: ('https://openrouter.ai/api/v1/chat/completions', 'openai/gpt-4o-mini'),
  Provider.gemini: ('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent', 'gemini-2.0-flash'),
  Provider.claude: ('https://api.anthropic.com/v1/messages', 'claude-sonnet-4-5'),
};

Provider? pickProvider(Map<String, String> keys) {
  for (final p in Provider.values) {
    final key = keys[p.name]?.trim();
    if (key != null && key.isNotEmpty) return p;
  }
  return null;
}

/// Ответ модели: слова и, если она просила данные, что именно нашлось.
class Answer {
  final String text;
  final QueryResult? result;
  const Answer(this.text, [this.result]);
}

/// Реплика разговора: без неё «а в июне?» начинало бы с чистого листа.
class Turn {
  final String q;
  final String a;
  const Turn(this.q, this.a);
}

const _memory = 6;

const _rules = '''
Ты помощник в приложении личных финансов. Отвечай по данным человека, по-русски.
Сами операции тебе не показаны — их можно запросить, и приложение посчитает.
Ответ всегда строго JSON, без пояснений вокруг, одним из двух видов:
{"запрос": {"что":"операции|категории|месяцы|счета", "счёт":"", "категория":"", "подкатегория":"", "с":"YYYY-MM-DD", "по":"YYYY-MM-DD", "поиск":"", "вид":"расход|доход|все", "сколько":20}}
{"ответ": "две-три фразы по данным"}
Пустые поля запроса опускай. Без «с» и «по» берётся вся история.
«поиск» ищет слово в заметке, категории, подкатегории и счёте.
Спрашивают про срок или «когда» — запрашивай операции и смотри даты.
Спрашивают «на что уходит» — запрашивай категории.
Не выдумывай чисел: если запрос вернул пусто, так и скажи.
''';

/// Справка о базе: имена и границы. Числа модель просит сама.
String _shortcut(Database db, String today) {
  final real = db.transactions.where((t) => t.kind != TxKind.transfer && !t.hidden).toList();
  final dates = real.map((t) => t.date).toList()..sort();
  final accounts = db.accounts.map((a) => a.name).where((n) => !isVirtualAccount(n)).toList();
  final cats = {for (final t in real) if (t.category != null) t.category!}.toList();
  final subs = {for (final t in real) if (t.subcategory != null) t.subcategory!}.toList();
  return [
    'Сегодня $today. Валюта отчёта ${db.baseCurrency}.',
    'История: ${real.length} операций с ${dates.firstOrNull ?? '—'} по ${dates.lastOrNull ?? '—'}.',
    'Счета: ${accounts.join(', ')}.',
    'Категории: ${cats.join(', ')}.',
    'Подкатегории: ${subs.take(60).join(', ')}.',
  ].join('\n');
}

Map<String, dynamic>? _readJson(String? text) {
  if (text == null) return null;
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
  if (match == null) return null;
  try {
    return jsonDecode(match.group(0)!) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Ответить на вопрос о деньгах.
///
/// Разговор идёт в два хода: сперва модель говорит, какие данные ей нужны,
/// приложение считает их по базе, вторым ходом модель отвечает словами.
Future<Answer?> askAbout(
  Map<String, String> keys,
  String question,
  Database db,
  String today, {
  List<Turn> history = const [],
}) async {
  final who = pickProvider(keys);
  if (who == null) return null;
  final key = keys[who.name]!.trim();

  final talked = history.take(_memory).map((t) => 'Человек: ${t.q}\nТы: ${t.a}').join('\n');
  final first = [
    _rules,
    'Данные о базе:', _shortcut(db, today),
    if (talked.isNotEmpty) 'Разговор до этого:\n$talked',
    'Вопрос: $question',
  ].join('\n');

  var said = _readJson(await _talk(who, key, first));
  if (said == null) return null;
  if (said['ответ'] is String) return Answer(said['ответ'] as String);

  QueryResult? result;
  // Два захода за данными: больше — уже не разговор, а блуждание.
  for (var step = 0; step < 2; step++) {
    final raw = said?['запрос'];
    if (raw is! Map) break;
    final query = DataQuery.fromJson(raw.cast<String, dynamic>());
    result = runQuery(db, query);
    final next = [
      _rules,
      'Данные о базе:', _shortcut(db, today),
      if (talked.isNotEmpty) 'Разговор до этого:\n$talked',
      'Вопрос: $question',
      'Ты запросил: ${jsonEncode(query.toJson())}',
      'Приложение ответило:\n${result.text}',
      'Теперь ответь словами: {"ответ": "..."}. Ещё один запрос делай только если без него не ответить.',
    ].join('\n');
    said = _readJson(await _talk(who, key, next));
    if (said == null) return null;
    if (said['ответ'] is String) return Answer(said['ответ'] as String, result);
  }
  return result == null ? null : Answer(result.text, result);
}

Future<String?> _talk(Provider who, String key, String prompt) async {
  final (url, model) = _where[who]!;
  try {
    final headers = <String, String>{'content-type': 'application/json'};
    late final Object body;
    var target = url;

    switch (who) {
      case Provider.gemini:
        target = '$url?key=$key';
        body = {
          'contents': [
            {'parts': [{'text': prompt}]},
          ],
        };
      case Provider.claude:
        headers['x-api-key'] = key;
        headers['anthropic-version'] = '2023-06-01';
        body = {
          'model': model,
          'max_tokens': 600,
          'messages': [{'role': 'user', 'content': prompt}],
        };
      default:
        headers['authorization'] = 'Bearer $key';
        body = {
          'model': model,
          'temperature': 0,
          'messages': [{'role': 'user', 'content': prompt}],
        };
    }

    final res = await http
        .post(Uri.parse(target), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 40));
    if (res.statusCode >= 400) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

    return switch (who) {
      Provider.gemini =>
        (((data['candidates'] as List?)?.firstOrNull as Map?)?['content'] as Map?)
            ?['parts']?[0]?['text'] as String?,
      Provider.claude => ((data['content'] as List?)?.firstOrNull as Map?)?['text'] as String?,
      _ => (((data['choices'] as List?)?.firstOrNull as Map?)?['message'] as Map?)?['content'] as String?,
    };
  } catch (_) {
    // Нет сети или ключ не тот: чат скажет об этом словами, падать незачем.
    return null;
  }
}
