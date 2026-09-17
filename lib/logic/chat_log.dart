import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../l10n/strings.dart';

/// Память чата: переписка живёт на устройстве и переживает выход.
///
/// До этого чат забывал всё при закрытии экрана, а модель получала один
/// текущий вопрос — и «а в прошлом месяце?» вторым сообщением не работало.
/// Теперь реплики лежат рядом с базой в `chat.json`, а последние из них
/// уезжают к модели вместе с вопросом.
///
/// На сервер переписка НЕ отправляется и партнёру не видна: разговор о своих
/// деньгах остаётся между человеком и его телефоном. Уносить его в общее
/// хранилище пары значило бы показать партнёру вопросы, которых он не слышал.
///
/// Ветка у каждой пары и каждого чата своя: `<пространство>|<личный или
/// общий>`. Иначе вопрос про Аню всплыл бы в разговоре про Кирилла, а личная
/// трата — в общем чате.
const _keep = 200;

/// Сколько реплик уходит модели. Больше она не помнит лучше, а платим за
/// каждый знак мы.
const _sendTurns = 10;
const _sendChars = 6000;
const _turnChars = 1000;

/// Одна реплика: чья, о чём и что после неё сделалось.
class ChatTurn {
  const ChatTurn({
    required this.mine,
    required this.text,
    required this.at,
    this.done = const [],
    this.failed = const [],
    this.files = const [],
  });

  final bool mine;
  final String text;

  /// Время в миллисекундах: по нему реплики стоят в порядке.
  final int at;

  /// Что чат сделал по этой реплике и что не вышло.
  final List<String> done;
  final List<String> failed;

  /// Имена вложений. Сами файлы не хранятся: снимок чека весит больше всей
  /// переписки, а модель его уже прочитала.
  final List<String> files;

  Map<String, dynamic> toJson() => {
        'mine': mine,
        'text': text,
        'at': at,
        if (done.isNotEmpty) 'done': done,
        if (failed.isNotEmpty) 'failed': failed,
        if (files.isNotEmpty) 'files': files,
      };

  static ChatTurn fromJson(Map<String, dynamic> j) => ChatTurn(
        mine: j['mine'] == true,
        text: '${j['text'] ?? ''}',
        at: (j['at'] as num?)?.toInt() ?? 0,
        done: [for (final e in (j['done'] as List?) ?? const []) '$e'],
        failed: [for (final e in (j['failed'] as List?) ?? const []) '$e'],
        files: [for (final e in (j['files'] as List?) ?? const []) '$e'],
      );

  /// Как реплика выглядит для модели: слова, имена вложений и сделанное.
  ///
  /// Сделанное уходит нарочно: без него чат не помнит, что уже записал трату,
  /// и на «поправь её» переспрашивает, какую именно.
  String get forModel {
    final parts = <String>[
      if (text.trim().isNotEmpty) text.trim(),
      for (final name in files) trf('askAttachment', [name]),
      if (done.isNotEmpty) '${tr('agentApplied')}: ${done.join('; ')}',
    ];
    final whole = parts.join('\n');
    return whole.length > _turnChars ? whole.substring(0, _turnChars) : whole;
  }
}

class ChatLog {
  final Map<String, List<ChatTurn>> _branches = {};
  Directory? _home;
  Future<void> _queue = Future.value();

  static String _branch(String space, String scope) => '$space|$scope';

  /// Прочитать переписку. Битый файл не роняет запуск: чат откроется пустым,
  /// а деньги лежат в другом файле и целы.
  Future<void> load(Directory home) async {
    _home = home;
    final file = File('${home.path}/chat.json');
    if (!await file.exists()) return;
    try {
      final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _branches.clear();
      for (final e in j.entries) {
        _branches[e.key] = [
          for (final raw in (e.value as List?) ?? const [])
            ChatTurn.fromJson((raw as Map).cast<String, dynamic>()),
        ];
      }
    } catch (_) {
      _branches.clear();
    }
  }

  /// Переписка ветки от старой реплики к свежей.
  List<ChatTurn> of(String space, String scope) =>
      List.unmodifiable(_branches[_branch(space, scope)] ?? const []);

  void add(String space, String scope, ChatTurn turn) {
    final key = _branch(space, scope);
    final list = _branches.putIfAbsent(key, () => <ChatTurn>[])..add(turn);
    // Старое уходит первым: переписка за год никому не нужна, а файл рос бы
    // вечно.
    if (list.length > _keep) list.removeRange(0, list.length - _keep);
    _save();
  }

  void clear(String space, String scope) {
    _branches.remove(_branch(space, scope));
    _save();
  }

  /// Что уходит модели вместе с вопросом: последние реплики в её формате.
  ///
  /// Режется дважды — по числу реплик и по знакам: длинная простыня из одного
  /// сообщения иначе съела бы весь контекст.
  List<Map<String, String>> historyFor(String space, String scope) {
    final all = _branches[_branch(space, scope)] ?? const <ChatTurn>[];
    final tail = all.length > _sendTurns ? all.sublist(all.length - _sendTurns) : all;

    final out = <Map<String, String>>[];
    var chars = 0;
    for (final turn in tail.reversed) {
      final text = turn.forModel;
      if (text.isEmpty) continue;
      if (chars + text.length > _sendChars) break;
      chars += text.length;
      out.insert(0, {'role': turn.mine ? 'user' : 'assistant', 'text': text});
    }
    return out;
  }

  /// Стереть ВСЮ переписку с устройства.
  ///
  /// Зовётся вместе со стиранием базы: человек ушёл из аккаунта или удалил
  /// его, и оставлять на телефоне его разговоры о деньгах нельзя — телефоном
  /// пользуется не он один.
  static Future<void> forgetAll(Directory home) async {
    final file = File('${home.path}/chat.json');
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Файла нет или папка исчезла — цель и так достигнута.
    }
  }

  /// Дописать файл немедленно. Нужно там, где приложение вот-вот закроется.
  Future<void> flush() => _save();

  Future<void> _save() {
    final home = _home;
    if (home == null) return Future.value();
    // Записи выстраиваются в очередь: два сообщения подряд иначе пишут файл
    // одновременно и оставляют обрывок.
    _queue = _queue.then((_) async {
      try {
        await File('${home.path}/chat.json').writeAsString(
          jsonEncode({
            for (final e in _branches.entries)
              e.key: [for (final t in e.value) t.toJson()],
          }),
          flush: true,
        );
      } catch (_) {
        // Место кончилось или папка исчезла: переписка не деньги, потеря её
        // не повод ронять экран.
      }
    });
    return _queue;
  }
}
