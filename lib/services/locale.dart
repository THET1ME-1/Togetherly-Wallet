import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../l10n/language.dart';
import '../l10n/strings.dart';

/// Язык интерфейса: выбор человека, иначе догадка по языку телефона.
///
/// Хранится отдельным файлом рядом с базой, а не в настройках пары: язык — это
/// устройство. У партнёра на его телефоне свой, и синхронизировать тут нечего.
class AppLocale extends ChangeNotifier {
  AppLocale({ui.Locale? system}) : _system = system;

  ui.Locale? _system;

  /// Выбор человека. Пусто — идём за системой.
  MoneyLanguage? _chosen;

  File? _file;

  MoneyLanguage? get chosen => _chosen;

  /// Язык, которым сейчас говорит приложение.
  MoneyLanguage get language =>
      _chosen ??
      (_system == null ? MoneyLanguage.ru : MoneyLanguage.detect(_system!));

  ui.Locale get locale => ui.Locale(language.code);

  Future<void> load({ui.Locale? system}) async {
    if (system != null) _system = system;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/locale.json');
      if (await _file!.exists()) {
        final raw = jsonDecode(await _file!.readAsString());
        if (raw is Map) {
          _chosen = MoneyLanguage.byCode('${raw['language'] ?? ''}');
        }
      }
    } catch (_) {
      // Битый файл не должен запирать запуск: пойдём за системой.
      _chosen = null;
    }
    _apply();
  }

  /// Выбрать язык. `null` возвращает приложение к языку системы.
  Future<void> choose(MoneyLanguage? next) async {
    _chosen = next;
    _apply();
    try {
      await _file?.writeAsString(jsonEncode({'language': next?.code ?? ''}));
    } catch (_) {
      // Не записалось — язык останется до перезапуска. Лучше, чем отказ.
    }
  }

  /// Система сообщила новый язык (человек сменил его в настройках телефона).
  void systemChanged(ui.Locale? locale) {
    if (_chosen != null) return;
    _system = locale;
    _apply();
  }

  void _apply() {
    // Словарь остаётся константой, а текущий язык живёт переменной: так
    // строка берётся без контекста, из любой точки — включая изоляты.
    appLanguage = language;
    notifyListeners();
  }
}
