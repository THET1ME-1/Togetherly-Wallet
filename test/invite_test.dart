import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/screens/pair_screen.dart';
import 'package:togetherly_money/services/invite.dart';
import 'package:togetherly_money/services/invite_code.dart';
import 'package:togetherly_money/services/session.dart';

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
}
