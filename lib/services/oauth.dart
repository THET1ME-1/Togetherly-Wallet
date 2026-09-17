import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import 'session.dart';

/// Вход через Google, Яндекс и Apple — в ТОТ ЖЕ аккаунт, что в Togetherly.
///
/// Коллекция `users` одна на экосистему, провайдеры настроены там же, поэтому
/// человек, входивший в Togetherly через Google, здесь попадает в свою запись,
/// а не заводит вторую. Пара, Плюс и история остаются его.
///
/// Google и Яндекс идут веб-потоком PocketBase: страница провайдера
/// открывается во встроенном браузере, сервер ловит возврат и присылает сессию.
/// Apple на iPhone спрашивается системным окном, а токен меняет на сессию наш
/// серверный хук — так человек не видит браузера вовсе.
enum OAuthProvider { google, yandex, apple }

String oauthProviderKey(OAuthProvider p) => switch (p) {
      OAuthProvider.google => 'google',
      OAuthProvider.yandex => 'yandex',
      OAuthProvider.apple => 'apple',
    };

String oauthProviderTitle(OAuthProvider p) => switch (p) {
      OAuthProvider.google => 'Google',
      OAuthProvider.yandex => 'Яндекс',
      OAuthProvider.apple => 'Apple',
    };

/// Что вернул сервер: токен и запись человека. Дальше это применяет [Session] —
/// хранилищем сессии остаётся оно, а не SDK.
class OAuthSession {
  const OAuthSession({
    required this.token,
    required this.record,
    this.name,
    this.avatarUrl,
  });

  final String token;
  final Map<String, dynamic> record;

  /// Имя и картинка из профиля провайдера. PocketBase их в запись НЕ
  /// переносит, поэтому без этого партнёр видел бы заглушку вместо имени.
  final String? name;
  final String? avatarUrl;
}

class OAuthCancelled implements Exception {
  const OAuthCancelled();
}

String? _text(Object? raw) {
  final value = '${raw ?? ''}'.trim();
  return value.isEmpty ? null : value;
}

class OAuthService {
  OAuthService({PocketBase? pb}) : _pb = pb ?? PocketBase(kApiBase);

  final PocketBase _pb;

  /// Системное окно Apple есть только на устройствах Apple. Кнопка при этом
  /// стоит везде: на Android тот же вход идёт через браузер.
  static bool get appleNative => Platform.isIOS || Platform.isMacOS;

  Future<OAuthSession> signIn(OAuthProvider provider) async {
    if (provider == OAuthProvider.apple && appleNative) {
      try {
        return await _appleNative();
      } on SignInWithAppleAuthorizationException catch (e) {
        // Человек закрыл окно — это не сбой.
        if (e.code == AuthorizationErrorCode.canceled) {
          throw const OAuthCancelled();
        }
        debugPrint('Apple: системное окно не сработало (${e.code}), идём в браузер');
      } catch (e) {
        debugPrint('Apple: системное окно не сработало — $e, идём в браузер');
      }
    }
    return _webFlow(oauthProviderKey(provider));
  }

  /// Веб-поток PocketBase. Встроенный браузер важен: системный уводит
  /// приложение в фон, сокет обрывается, и сессия не возвращается.
  Future<OAuthSession> _webFlow(String provider) async {
    try {
      final auth = await _pb.collection('users').authWithOAuth2(
        provider,
        (url) async {
          final opened = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
          if (opened) return;
          await launchUrl(url, mode: LaunchMode.externalApplication);
        },
      );
      try {
        await closeInAppWebView();
      } catch (_) {}
      final meta = auth.meta;
      return OAuthSession(
        token: auth.token,
        record: Map<String, dynamic>.from(auth.record.toJson()),
        name: _text(meta['name']),
        // Google пишет `avatarURL`, часть провайдеров — `avatarUrl`.
        avatarUrl: _text(meta['avatarUrl']) ?? _text(meta['avatarURL']),
      );
    } on ClientException catch (e) {
      // Отмену в браузере PocketBase отдаёт обычной ошибкой запроса.
      if (e.statusCode == 0) throw const OAuthCancelled();
      rethrow;
    }
  }

  /// Системный вход Apple: identityToken меняем на сессию PocketBase через
  /// серверный хук. Человека там находят по `sub`, поэтому вошедший когда-то
  /// через браузер попадает в свою прежнюю запись.
  Future<OAuthSession> _appleNative() async {
    // Nonce привязывает токен к этой попытке: Apple кладёт его внутрь, сервер
    // сверяет. Внутрь идёт уже свёрнутое значение — так требует Apple.
    final raw = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final nonce = sha256.convert(raw).toString();

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final identityToken = credential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      throw StateError('Apple не отдал токен входа');
    }

    // Имя Apple присылает ОДИН раз, при первом входе: не передать его сразу
    // значит оставить профиль безымянным навсегда.
    final name = [credential.givenName, credential.familyName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');

    final res = await _pb.send(
      '/api/apple/native',
      method: 'POST',
      body: {
        'identityToken': identityToken,
        'nonce': nonce,
        if (name.isNotEmpty) 'name': name,
      },
    ).timeout(const Duration(seconds: 25));

    if (res is! Map || res['token'] == null || res['record'] == null) {
      throw StateError('Сервер не отдал сессию');
    }
    return OAuthSession(
      token: '${res['token']}',
      record: Map<String, dynamic>.from(res['record'] as Map),
      // Apple отдаёт имя ровно один раз — при первом входе.
      name: name.isEmpty ? null : name,
    );
  }
}
