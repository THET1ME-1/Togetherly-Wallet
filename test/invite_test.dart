import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/pair_screen.dart';
import 'package:togetherly_money/services/invite.dart';
import 'package:togetherly_money/services/invite_code.dart';
import 'package:togetherly_money/services/invite_links.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/widgets/animated_invite_code.dart';

import 'tm_fonts.dart';

void main() {
  setUpAll(loadTmFonts);

  group('код приглашения', () {
    test('алфавит без двойников: ни I, ни O, ни нуля, ни единицы', () {
      for (var i = 0; i < 200; i++) {
        final code = Invite.newCode();
        expect(code.length, 6);
        expect(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code), isTrue,
            reason: code);
      }
    });

    test('ссылка целиком превращается в код', () {
      expect(normalizeInviteCode('https://togetherly.day/invite/AB12CD?app=money'), 'AB12CD');
      expect(normalizeInviteCode('loveapp://invite/AB12CD'), 'AB12CD');
    });

    test('русская раскладка не ломает код', () {
      // А, В, С, Е набраны кириллицей: на глаз от латинских не отличить.
      expect(normalizeInviteCode('АВ12СD'), 'AB12CD');
    });

    test('лишнее вокруг кода отбрасывается', () {
      expect(normalizeInviteCode('  ab12cd  '), 'AB12CD');
      expect(normalizeInviteCode('«AB12CD»'), 'AB12CD');
      expect(normalizeInviteCode(null), '');
    });

    test('ссылка ведёт на страницу приглашения с пометкой приложения', () {
      expect(Invite.linkFor('AB12CD'), 'https://togetherly.day/invite/AB12CD?app=money');
    });
  });

  group('экран приглашения', () {
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
            home: PairScreen(session: Session(), store: Store()),
          ));
          await tester.pump();

          expect(find.text('Позвать партнёра'), findsOneWidget);
          // На узком экране кнопка приёма лежит ниже сгиба: ListView не строит
          // то, что за краем, поэтому до неё надо долистать.
          await tester.scrollUntilVisible(
            find.text('Принять код'),
            200,
            // Прокручиваемых на экране несколько (поле ввода тоже), поэтому
            // список указывается явно.
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Принять код'), findsOneWidget);
        });
      }
    }
  });

  // 18.09.2026: код из Wallet звал партнёра в полную пару из Togetherly
  // («Группа заполнена»), экран выпускал новый код на каждом открытии, а
  // кнопка «Открыть в приложении» на странице приглашения не открывала Wallet.
  group('к какой паре привязан код', () {
    const me = Member(uid: 'u_me', name: 'Я');
    const other = Member(uid: 'u_other', name: 'Он');

    test('полная пара — код зовёт в новую, а не третьим в эту', () {
      const full = Pair(groupId: 'g_full', members: [me, other]);
      expect(inviteGroupFor(full, 'u_me'), isNull);
    });

    test('хранилище одиночки лежит под его uid — такой группы нет', () {
      const solo = Pair(groupId: 'u_me', members: [me]);
      expect(inviteGroupFor(solo, 'u_me'), isNull);
    });

    test('пара со свободным местом — код зовёт в неё', () {
      const waiting = Pair(groupId: 'g_wait', members: [me]);
      expect(inviteGroupFor(waiting, 'u_me'), 'g_wait');
    });

    test('без пары — в новую', () {
      expect(inviteGroupFor(const Pair(), 'u_me'), isNull);
    });
  });

  group('ссылка-приглашение открывает Wallet', () {
    test('своя схема и страница togetherly.day дают код', () {
      expect(inviteCodeFromUri(Uri.parse('togetherlywallet://invite/EDR3MT')), 'EDR3MT');
      expect(inviteCodeFromUri(Uri.parse('togetherlywallet://invite/edr3mt')), 'EDR3MT');
      expect(
          inviteCodeFromUri(Uri.parse('https://togetherly.day/invite/EDR3MT?app=money')),
          'EDR3MT');
    });

    test('чужие ссылки и пустой код не дают ничего', () {
      expect(inviteCodeFromUri(Uri.parse('loveapp://invite/EDR3MT')), isNull);
      expect(inviteCodeFromUri(Uri.parse('https://evil.example/invite/EDR3MT')), isNull);
      expect(inviteCodeFromUri(Uri.parse('togetherlywallet://invite/')), isNull);
      expect(inviteCodeFromUri(Uri.parse('togetherlywallet://other/EDR3MT')), isNull);
    });

    test('одна ссылка дважды подряд открывает экран один раз', () {
      InviteLinks.consume();
      final t0 = DateTime(2026, 9, 18, 12);
      InviteLinks.take(Uri.parse('togetherlywallet://invite/AB12CD'), now: t0);
      expect(InviteLinks.consume(), 'AB12CD');
      InviteLinks.take(Uri.parse('togetherlywallet://invite/AB12CD'),
          now: t0.add(const Duration(seconds: 1)));
      expect(InviteLinks.consume(), isNull, reason: 'повтор той же ссылки');
      InviteLinks.take(Uri.parse('togetherlywallet://invite/AB12CD'),
          now: t0.add(const Duration(seconds: 30)));
      expect(InviteLinks.consume(), 'AB12CD', reason: 'позже — это новое нажатие');
    });
  });

  group('код на экране читается', () {
    double lum(Color c) {
      double ch(double v) =>
          v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }

    double contrast(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
    }

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('код и «Скопировать» видны, ${mode.name}', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: PairScreen(session: Session(), store: Store(), demoCode: 'KX7M4P'),
        ));
        await tester.pump();

        final code = tester.widget<AnimatedInviteCode>(find.byType(AnimatedInviteCode));
        final card = tester.widget<Container>(find
            .ancestor(of: find.byType(AnimatedInviteCode), matching: find.byType(Container))
            .first);
        final fill = (card.decoration! as BoxDecoration).color!;
        expect(contrast(code.style.color!, fill), greaterThan(4.5),
            reason: 'код сливается с карточкой');

        final copy = tester.widget<Text>(find.text('Скопировать'));
        final button = tester.widget<Material>(find
            .ancestor(of: find.text('Скопировать'), matching: find.byType(Material))
            .first);
        expect(contrast(copy.style!.color!, button.color!), greaterThan(4.5),
            reason: 'подпись кнопки сливается с кнопкой');
      });
    }
  });

  group('код появляется «дешифратором», как в Togetherly', () {
    Future<void> show(WidgetTester tester, {bool still = false}) async {
      await tester.pumpWidget(MaterialApp(
        theme: MoneyTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: PairScreen(session: Session(), store: Store(), demoCode: 'KX7M4P'),
        ),
      ));
    }

    String shown(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(
            of: find.byType(AnimatedInviteCode), matching: find.byType(Text)))
        .map((t) => t.data)
        .join();

    testWidgets('сперва бегут символы, потом садится настоящий код', (tester) async {
      await show(tester);
      await tester.pump();
      expect(shown(tester), isNot('KX7M4P'), reason: 'пробега не было');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 200));
      expect(shown(tester), 'KX7M4P');
    });

    testWidgets('при выключенных анимациях код стоит сразу', (tester) async {
      await show(tester, still: true);
      await tester.pump();
      expect(shown(tester), 'KX7M4P');
    });
  });
}
