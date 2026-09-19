import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'invite_code.dart';

/// Код партнёра из ссылки-приглашения.
///
/// Страница `togetherly.day/invite/CODE?app=money` ведёт кнопкой «Открыть в
/// Wallet» на `togetherlywallet://invite/CODE` (на Android — через intent://
/// с запасной страницей загрузки). До 18.09.2026 своей схемы у Wallet не было
/// вовсе, страница звала в Togetherly, и у человека с одним Wallet кнопка не
/// делала ничего. Веб-ссылка на togetherly.day тоже разбирается: её могут
/// открыть из переписки, если система отдаст её сюда.
String? inviteCodeFromUri(Uri uri) {
  String raw;
  if (uri.scheme == 'togetherlywallet' && uri.host == 'invite') {
    raw = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
  } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      (uri.host == 'togetherly.day' || uri.host.endsWith('.togetherly.day')) &&
      uri.pathSegments.length > 1 &&
      uri.pathSegments.first == 'invite') {
    raw = uri.pathSegments[1];
  } else {
    return null;
  }
  final code = normalizeInviteCode(raw);
  return code.length >= 4 && code.length <= 12 ? code : null;
}

/// Приходящие ссылки-приглашения. Код ждёт в [pending], пока его не заберёт
/// оболочка приложения: на холодном старте ссылка приходит раньше, чем
/// построен экран, и без буфера терялась бы (та же грабля была в Togetherly).
abstract final class InviteLinks {
  static final ValueNotifier<String?> pending = ValueNotifier(null);

  static StreamSubscription<Uri>? _sub;
  static String? _last;
  static DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  static Future<void> start() async {
    if (_sub != null) return;
    final links = AppLinks();
    try {
      _sub = links.uriLinkStream.listen(take, onError: (_) {});
      final first = await links.getInitialLink();
      if (first != null) take(first);
    } catch (e) {
      debugPrint('InviteLinks: $e');
    }
  }

  /// Одна ссылка приходит дважды — начальной и потоком. Тот же код второй раз
  /// за пять секунд не открывает второй экран поверх первого.
  static void take(Uri uri, {DateTime? now}) {
    final code = inviteCodeFromUri(uri);
    if (code == null) return;
    final at = now ?? DateTime.now();
    if (code == _last && at.difference(_lastAt).inSeconds < 5) return;
    _last = code;
    _lastAt = at;
    pending.value = code;
  }

  /// Забрать код: оболочка открывает с ним экран приглашения.
  static String? consume() {
    final code = pending.value;
    pending.value = null;
    return code;
  }
}
