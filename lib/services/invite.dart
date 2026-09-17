import 'dart:math';

import '../data/models.dart';
import 'auth_failure.dart';
import 'session.dart';

/// Приглашение в пару — та же механика, что в Togetherly, и те же коды.
///
/// Коллекция `invite_codes` одна на экосистему, роут приёма один
/// (`/api/invite/accept`), поэтому код, выпущенный в Money, принимается и в
/// Togetherly, и наоборот. Ради этого чистка кода и алфавит скопированы
/// дословно: расхождение означало бы «код не найден» на ровном месте.
class Invite {
  Invite(this.session);

  final Session session;

  /// Без I, O, 0 и 1: человек диктует код голосом и переписывает с экрана.
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String newCode() {
    final r = Random.secure();
    return List.generate(6, (_) => _chars[r.nextInt(_chars.length)]).join();
  }

  /// Выпустить свой код. Прежний сносится ТОЛЬКО после того, как новый лёг на
  /// сервер: обратный порядок оставлял человека вовсе без кода, когда сервер
  /// отвечал долго, и партнёру нечего было вводить.
  Future<String> issue({String? groupId, String? oldCode}) async {
    if (!session.signedIn) throw SessionError(AuthFailure.wrongCredentials);

    for (var attempt = 0; attempt < 6; attempt++) {
      final code = newCode();
      try {
        await session.post('/api/collections/invite_codes/records', {
          'code': code,
          'owner_uid': session.uid,
          if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        });
        if (oldCode != null && oldCode.isNotEmpty && oldCode != code) {
          await _dropOld(oldCode);
        }
        return code;
      } on SessionError {
        // Коллизия по уникальному индексу или отказ правила: пробуем следующий
        // код. Восемь попыток подряд означают, что дело не в коде.
        continue;
      }
    }
    throw SessionError(AuthFailure.unknown);
  }

  Future<void> _dropOld(String code) async {
    try {
      final found = await session.get(
        '/api/collections/invite_codes/records?perPage=1&filter='
        '${Uri.encodeQueryComponent('code = "$code"')}',
      );
      final items = (found['items'] as List?) ?? const [];
      if (items.isEmpty) return;
      final id = (items.first as Map)['id'] as String?;
      if (id != null) {
        await session.delete('/api/collections/invite_codes/records/$id');
      }
    } catch (_) {
      // Старый код, оставшийся жить, безвреден: приём привязывает его к
      // получившейся паре. Ронять из-за этого выпуск нового нельзя.
    }
  }

  /// Принять чужой код. Ответ сервера: {success, message, pairId, restored}.
  ///
  /// Приём идемпотентный: тот же код тем же человеком отвечает успехом с тем
  /// же pairId. Диплинк присылает код дважды, кнопку жмут второй раз, и раньше
  /// ошибка второго запроса ложилась поверх успеха первого.
  Future<InviteResult> accept(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) return const InviteResult(ok: false, message: 'Введите код');
    if (!session.signedIn) {
      return const InviteResult(ok: false, message: 'Сначала войдите в аккаунт');
    }

    try {
      final r = await session.post('/api/invite/accept', {'code': code});
      if (r['success'] != true) {
        return InviteResult(
          ok: false,
          message: (r['message'] ?? 'Не получилось принять код').toString(),
        );
      }
      final pairId = (r['pairId'] ?? '').toString();
      if (pairId.isEmpty) {
        return const InviteResult(ok: false, message: 'Сервер не вернул пару');
      }
      return InviteResult(ok: true, pairId: pairId, restored: r['restored'] == true);
    } on SessionError catch (e) {
      return InviteResult(ok: false, message: e.message);
    }
  }

  /// Ссылка для партнёра. Ведёт на страницу приглашения: там и кнопка
  /// установки, и сам код — человек без приложения увидит, что это не спам.
  static String linkFor(String code) => '$kApiBase/invite/$code?app=money';
}

class InviteResult {
  const InviteResult({
    required this.ok,
    this.message = '',
    this.pairId = '',
    this.restored = false,
  });

  final bool ok;
  final String message;
  final String pairId;

  /// Пара поднялась из распущенной: вся история на месте.
  final bool restored;
}

/// Пара, собранная приглашением, выглядит так же, как пришедшая из Togetherly.
Pair pairFromAccept(InviteResult r, Pair current) =>
    r.ok ? Pair(groupId: r.pairId, members: current.members, baseCurrency: current.baseCurrency) : current;
