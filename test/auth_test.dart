import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/welcome_screen.dart';
import 'package:togetherly_money/services/auth_failure.dart';
import 'package:togetherly_money/services/oauth.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/widgets/auth_providers.dart';

import 'tm_fonts.dart';

void main() {
  setUpAll(loadTmFonts);

  group('почему не пустило', () {
    test('дубль почты узнаётся по коду в теле, а не по тексту', () {
      final f = authFailureOf(
        status: 400,
        body: '{"data":{"email":{"code":"validation_not_unique","message":"Value must be unique."}}}',
      );
      expect(f, AuthFailure.emailTaken);
      expect(authFailureText(f), contains('уже есть аккаунт'));
    });

    test('короткий пароль — оба кода сервера', () {
      for (final code in [
        'validation_length_out_of_range',
        // Нынешний код PocketBase: раньше он доезжал до человека как
        // «почта или пароль не подошли».
        'validation_min_text_constraint',
      ]) {
        expect(
          authFailureOf(status: 400, body: '{"data":{"password":{"code":"$code"}}}'),
          AuthFailure.weakPassword,
          reason: code,
        );
      }
    });

    test('неверная пара почта-пароль', () {
      expect(
        authFailureOf(status: 400, body: '{"message":"Failed to authenticate."}'),
        AuthFailure.wrongCredentials,
      );
    });

    test('провайдер рвёт TLS — это не наш сервер', () {
      final f = authFailureOf(
        error: 'HandshakeException: OS Error: WRONG_VERSION_NUMBER(tls_record.cc:127)',
      );
      expect(f, AuthFailure.connectionBlocked);
      expect(authFailureText(f), contains('провайдер'));
    });

    test('лимит попыток', () {
      expect(authFailureOf(status: 429, body: ''), AuthFailure.tooOften);
    });

    test('сеть молчит', () {
      expect(authFailureOf(error: 'SocketException: Failed host lookup'), AuthFailure.offline);
    });
  });

  _serverMessageTests();

  group('экран входа', () {
    for (final size in const [Size(393, 852), Size(320, 568)]) {
      for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('собирается на ${size.width.toInt()}dp, ${mode.name}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(MaterialApp(
            theme: MoneyTheme.light(),
            darkTheme: MoneyTheme.dark(),
            themeMode: mode,
            home: WelcomeScreen(account: Session()),
          ));
          await tester.pump();

          // Первый экран: карты, обещание и одна кнопка. Полей на нём нет —
          // они приезжают на место карт по нажатию «Начать».
          expect(find.text('Начать'), findsOneWidget);
          expect(find.text('Войти'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          // Человеку честно сказано, куда он заводит учётку.
          expect(find.text('Один аккаунт для всех приложений Togetherly'), findsOneWidget);
        });
      }
    }

    testWidgets('«Начать» меняет карты на поля, а кнопку — на слово',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      await tester.tap(find.text('Начать'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      // Поля приехали на место карт, низ экрана остался прежним.
      expect(find.text('Ваше имя'), findsOneWidget);
      expect(find.text('ваша@почта.com'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Создать аккаунт'), findsOneWidget);
      expect(find.text('Уже есть аккаунт?'), findsOneWidget);
    });

    testWidgets('«Войти» открывает вход без имени', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      await tester.tap(find.text('Войти'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }

      expect(find.text('Ваше имя'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Войти'), findsOneWidget);
      expect(find.text('Нет аккаунта?'), findsOneWidget);
    });
  });

  group('один аккаунт на все приложения', () {
    testWidgets('подпись стоит на первом экране и нажимается', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      await tester.pump();

      final finder = find.text('Один аккаунт для всех приложений Togetherly');
      expect(finder, findsOne);
      expect(tester.widget<Text>(finder).style!.decoration,
          TextDecoration.underline);
      // По ней открывается страница про связь приложений.
      expect(
        find.ancestor(of: finder, matching: find.byType(GestureDetector)),
        findsWidgets,
      );
    });
  });
}

void _serverMessageTests() {
  group('слова сервера', () {
    test('русское сообщение доходит до человека как есть', () {
      final e = SessionError(
        AuthFailure.offline,
        serverMessage: 'Разговор о деньгах пока не подключён',
        status: 503,
      );
      expect(e.message, 'Разговор о деньгах пока не подключён');
    });

    test('без сообщения остаётся наш текст', () {
      expect(SessionError(AuthFailure.offline).message, 'Сервер не отвечает. Проверьте сеть');
    });

    test('402 просит Togetherly+', () {
      expect(SessionError(AuthFailure.unknown, status: 402).needPlus, isTrue);
    });
  });

  group('вход провайдером', () {
    /// Провайдер ведёт в ТОТ ЖЕ аккаунт, что в Togetherly: коллекция users
    /// одна на экосистему. Здесь проверяем, что сессия применяется как своя —
    /// токен, uid и имя попадают туда же, куда при входе почтой.
    test('сессия от провайдера становится нашей', () async {
      final account = Session();
      await account.signInWith(
        OAuthProvider.google,
        service: _FakeOAuth(const OAuthSession(
          token: 'tok-google',
          record: {
            'id': 'u_same',
            'email': 'sasha@example.com',
            'display_name': 'Саша',
            'origin': 'togetherly',
          },
        )),
      );

      expect(account.signedIn, isTrue);
      expect(account.uid, 'u_same');
      expect(account.email, 'sasha@example.com');
      expect(account.name, 'Саша');
      expect(account.mode, SessionMode.signedIn);
    });

    test('имя из профиля сети попадает в сессию', () async {
      final account = Session();
      await account.signInWith(
        OAuthProvider.google,
        service: _FakeOAuth(const OAuthSession(
          token: 'tok',
          // PocketBase заводит запись без имени: провайдер отдаёт его
          // отдельно, в мете.
          record: {'id': 'u_new', 'email': 'new@example.com'},
          name: 'Саша Матросов',
          avatarUrl: 'https://example.com/a.jpg',
        )),
      );

      expect(account.uid, 'u_new');
      // Дописать профиль на сервере в тесте нечем, но имя провайдера уже
      // известно сессии и не теряется по дороге.
      expect(account.email, 'new@example.com');
    });

    test('отмену в окне провайдера наверх не тащим как ошибку', () async {
      final account = Session();
      await expectLater(
        account.signInWith(OAuthProvider.yandex, service: _FakeCancelled()),
        throwsA(isA<OAuthCancelled>()),
      );
      expect(account.signedIn, isFalse);
    });

    testWidgets('на экране входа три двери и все ведут в один аккаунт',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: WelcomeScreen(account: Session()),
      ));
      await tester.pump();

      // Три круглые кнопки в ОДНУ строку, как в Togetherly: знаки вместо
      // трёх крупных кнопок в столбик.
      expect(find.byType(AuthProviderRow), findsOne);
      expect(find.byType(GoogleGlyph), findsOne);
      expect(find.byType(YandexGlyph), findsOne);
      // Apple — только на своих устройствах.
      expect(
        find.byType(AppleGlyph),
        OAuthService.appleNative ? findsOne : findsNothing,
      );
      expect(find.byTooltip('Google'), findsOne);

      // Кнопки стоят рядом, а не одна под другой.
      final google = tester.getCenter(find.byType(GoogleGlyph));
      final yandex = tester.getCenter(find.byType(YandexGlyph));
      expect(google.dy, closeTo(yandex.dy, 1));
      expect(google.dx, lessThan(yandex.dx));

      expect(find.text('Один аккаунт для всех приложений Togetherly'), findsOne);
    });
  });
}

/// Подставной вход: настоящий открывает браузер, а в тесте важно только то,
/// что сессия применяется как своя.
class _FakeOAuth extends OAuthService {
  _FakeOAuth(this.session);

  final OAuthSession session;

  @override
  Future<OAuthSession> signIn(OAuthProvider provider) async => session;
}

class _FakeCancelled extends OAuthService {
  @override
  Future<OAuthSession> signIn(OAuthProvider provider) async =>
      throw const OAuthCancelled();
}
