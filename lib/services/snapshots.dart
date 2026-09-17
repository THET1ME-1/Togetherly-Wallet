import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../logic/snapshot_crypto.dart';
import 'session.dart';

/// Снимок базы за день.
class SnapshotDay {
  const SnapshotDay({required this.day, required this.size, required this.created});

  final String day;
  final int size;
  final int created;
}

/// Снимки базы за каждый день: «возврат к любому дню» с витрины.
///
/// Как устроено и почему именно так:
///
/// * снимок делает ТЕЛЕФОН раз в сутки, шифрует своим ключом и кладёт на
///   сервер непрозрачным куском. Ключа у сервера нет — это деньги пары;
/// * ключ выводится из фразы восстановления. Фраза лежит на устройстве, и
///   человеку её показывают ДО первого снимка: без неё снимки не открыть на
///   новом телефоне, и узнавать об этом после потери телефона поздно;
/// * соль лежит на сервере рядом со снимками. Без фразы она бесполезна, а
///   без неё человек, переставивший приложение, не открыл бы свои же снимки.
class SnapshotService extends ChangeNotifier {
  SnapshotService({required this.session, required this.store});

  final Session session;
  final Store store;

  File? _file;
  List<String> _phrase = const [];
  String _salt = '';
  String _lastDay = '';

  List<SnapshotDay> _days = const [];
  bool _busy = false;

  List<String> get phrase => _phrase;
  bool get ready => _phrase.isNotEmpty && _salt.isNotEmpty;
  List<SnapshotDay> get days => _days;
  bool get busy => _busy;

  Future<void> load() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/snapshots.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is Map) {
          _phrase = [for (final w in (raw['phrase'] as List?) ?? const []) '$w'];
          _salt = '${raw['salt'] ?? ''}';
          _lastDay = '${raw['lastDay'] ?? ''}';
        }
      }
    } catch (_) {
      // Битый файл не ломает запуск: снимков просто нет, пока человек не
      // заведёт фразу заново.
      _phrase = const [];
      _salt = '';
    }
    notifyListeners();
  }

  /// Завести фразу восстановления. Возвращает её словами — показать человеку.
  Future<List<String>> start() async {
    _phrase = SnapshotCrypto.newPhrase();
    _salt = SnapshotCrypto.newSalt();
    _lastDay = '';
    await _save();
    return _phrase;
  }

  /// Принять чужую фразу — на новом телефоне. Соль приезжает с сервера.
  Future<bool> usePhrase(List<String> words) async {
    final clean = [
      for (final w in words)
        if (w.trim().isNotEmpty) w.trim().toLowerCase(),
    ];
    if (clean.length != SnapshotCrypto.phraseLength) return false;
    await refresh();
    if (_salt.isEmpty) return false;
    _phrase = clean;
    await _save();
    return true;
  }

  /// Забыть фразу на этом устройстве. Снимки на сервере остаются.
  Future<void> forget() async {
    _phrase = const [];
    _lastDay = '';
    await _save();
  }

  /// Список дней и соль с сервера.
  Future<void> refresh() async {
    if (!session.signedIn) return;
    _busy = true;
    notifyListeners();
    try {
      final r = await session.get('/api/money/snapshots');
      final salt = '${r['salt'] ?? ''}';
      // Своя соль сильнее серверной ровно до первой отправки: пока снимков
      // нет, сервер о ней не знает.
      if (salt.isNotEmpty) _salt = salt;
      _days = [
        for (final item in (r['days'] as List?) ?? const [])
          if (item is Map)
            SnapshotDay(
              day: '${item['day'] ?? ''}',
              size: (item['size'] as num?)?.toInt() ?? 0,
              created: (item['created'] as num?)?.toInt() ?? 0,
            ),
      ];
      await _save();
    } catch (_) {
      // Молчим: экран покажет то, что уже знает.
    }
    _busy = false;
    notifyListeners();
  }

  /// Снять снимок за сегодня, если сегодня его ещё не было.
  ///
  /// Зовётся на запуске рядом с автокопией на устройстве. Одна попытка в
  /// сутки: база меняется весь день, и десять снимков за вечер не нужны
  /// никому, кроме нашего диска.
  Future<bool> daily({DateTime? now}) async {
    final today = (now ?? DateTime.now()).toIso8601String().substring(0, 10);
    if (!ready || _lastDay == today || !session.signedIn) return false;
    return push(day: today);
  }

  /// Отправить снимок за день.
  Future<bool> push({String? day}) async {
    if (!ready || !session.signedIn) return false;
    final target = day ?? DateTime.now().toIso8601String().substring(0, 10);
    try {
      final json = store.exportJson();
      final key = await SnapshotCrypto.keyOf(_phrase, _salt);
      final blob = await SnapshotCrypto.seal(key, json);
      final r = await session.post(
        '/api/money/snapshot',
        {'day': target, 'blob': blob, 'salt': _salt},
        timeout: const Duration(seconds: 90),
      );
      if (r['ok'] != true) return false;
      _lastDay = target;
      await _save();
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Вернуться к состоянию на день. Возвращает пусто при удаче и причину
  /// словом при отказе.
  Future<String> restore(String day) async {
    if (!ready) return tr('snapshotNoPhrase');
    try {
      final r = await session.get(
        '/api/money/snapshot?day=$day',
        timeout: const Duration(seconds: 90),
      );
      final blob = '${r['blob'] ?? ''}';
      final salt = '${r['salt'] ?? _salt}';
      final key = await SnapshotCrypto.keyOf(_phrase, salt);
      final json = await SnapshotCrypto.open(key, blob);
      if (json.isEmpty) return tr('snapshotWrongPhrase');

      final count = store.importBackup(json);
      // Ноль значит «файл не наш»: база остаётся нетронутой, и сказать об
      // этом надо словами, а не молча показать прежние цифры.
      if (count == 0) return tr('snapshotBroken');
      return '';
    } on SessionError catch (e) {
      return e.needPlus ? tr('snapshotNeedPlus') : e.message;
    } catch (_) {
      return tr('snapshotFailed');
    }
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode({
        'phrase': _phrase,
        'salt': _salt,
        'lastDay': _lastDay,
      }));
    } catch (_) {
      // Не записалось — снимок повторится завтра.
    }
    notifyListeners();
  }
}
