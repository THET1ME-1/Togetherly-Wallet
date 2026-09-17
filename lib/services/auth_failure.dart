/// Почему не пустило. Причина разбирается по коду ответа и телу, а не по
/// тексту сообщения: текст PocketBase меняется от версии к версии, а строка
/// про дубль почты приходит кодом `validation_not_unique` внутри тела.
///
/// Чистая функция ради теста: экран входа обязан звать её, а не собирать свою
/// цепочку `contains`. В Togetherly такая цепочка доводила до человека сырой
/// `ClientException` с внутренностями TLS.
library;

import '../l10n/strings.dart';

enum AuthFailure {
  /// Почта или пароль не подошли.
  wrongCredentials,

  /// Такая почта уже занята.
  emailTaken,

  /// Почта введена с опечаткой или без собачки.
  badEmail,

  /// Пароль короче восьми знаков — предел самого PocketBase.
  weakPassword,

  /// Поле осталось пустым.
  emptyField,

  /// Сервер жив, но запросов слишком много.
  tooOften,

  /// Соединение ломают по дороге: DPI провайдера отдаёт не-TLS в ответ на
  /// приветствие. Сервер при этом отвечает всем остальным.
  connectionBlocked,

  /// Сети нет или сервер молчит.
  offline,

  /// Что-то, чего мы не знаем. Показываем как есть, но без внутренностей.
  unknown,
}

AuthFailure authFailureOf({int? status, String? body, Object? error}) {
  final text = '${body ?? ''} ${error ?? ''}'.toLowerCase();

  if (text.contains('wrong_version_number') ||
      text.contains('handshake') ||
      text.contains('certificate')) {
    return AuthFailure.connectionBlocked;
  }
  if (error != null && status == null) return AuthFailure.offline;

  switch (status) {
    case 400:
      if (text.contains('validation_not_unique')) return AuthFailure.emailTaken;
      if (text.contains('validation_is_email') || text.contains('validation_invalid_email')) {
        return AuthFailure.badEmail;
      }
      // PocketBase отвечает про короткий пароль ДВУМЯ кодами: старым
      // `validation_length_out_of_range` и нынешним
      // `validation_min_text_constraint` (поймано живой пробой 12.09.2026 —
      // человек видел «почта или пароль не подошли» вместо подсказки о длине).
      if (text.contains('password') &&
          (text.contains('validation_length_out_of_range') ||
              text.contains('validation_min_text_constraint'))) {
        return AuthFailure.weakPassword;
      }
      // «Обязательное поле» приходит именно так, и раньше это доезжало до
      // человека как «почта или пароль не подошли» — при пустой почте.
      if (text.contains('validation_required')) return AuthFailure.emptyField;
      if (text.contains('failed to authenticate') || text.contains('invalid login')) {
        return AuthFailure.wrongCredentials;
      }
      return AuthFailure.wrongCredentials;
    case 401:
    case 403:
      return AuthFailure.wrongCredentials;
    case 404:
      return AuthFailure.wrongCredentials;
    case 429:
      return AuthFailure.tooOften;
  }
  if (status != null && status >= 500) return AuthFailure.offline;
  return AuthFailure.unknown;
}

/// Текст для человека. Говорит, что случилось и что делать, без извинений.
String authFailureText(AuthFailure f) => switch (f) {
      AuthFailure.wrongCredentials => tr('authWrongPair'),
      AuthFailure.emailTaken => tr('authEmailTaken'),
      AuthFailure.badEmail => tr('authEmailTypo'),
      AuthFailure.weakPassword => tr('authWeakPassword'),
      AuthFailure.emptyField => tr('authEmptyFields'),
      AuthFailure.tooOften => tr('authTooMany'),
      AuthFailure.connectionBlocked => tr('authBlocked'),
      AuthFailure.offline => tr('authNoServer'),
      AuthFailure.unknown => tr('authUnknown'),
    };
