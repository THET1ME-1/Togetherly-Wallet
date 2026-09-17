import '../services/session.dart' show kApiBase;

/// Ссылка на аватар из того, что лежит в профиле.
///
/// Togetherly хранит аватар двумя способами: внешней ссылкой (вход через
/// сервисы) и своей схемой `pb://media/<запись>/<файл>` — это файл коллекции
/// `media`, и отдаётся он без токена, потому что правило коллекции открывает
/// `kind = avatars` всем вошедшим.
///
/// Money принимал только http, поэтому у пары с настоящими фотографиями в
/// бейджах стояли буквы («а аватарка?», 13.09.2026).
String? avatarLink(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  if (s.startsWith('http')) return s;
  const scheme = 'pb://media/';
  if (!s.startsWith(scheme)) return null;
  final rest = s.substring(scheme.length);
  final slash = rest.indexOf('/');
  if (slash <= 0 || slash == rest.length - 1) return null;
  final id = rest.substring(0, slash);
  final file = rest.substring(slash + 1);
  return '$kApiBase/api/files/media/$id/$file';
}
