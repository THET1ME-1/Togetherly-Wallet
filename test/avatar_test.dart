import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/avatar.dart';

void main() {
  group('ссылка на аватар', () {
    test('своя схема разворачивается в файл медиа', () {
      final link = avatarLink('pb://media/ykred4igfj92hfa/profile_r7fsx.webp');
      expect(link, endsWith('/api/files/media/ykred4igfj92hfa/profile_r7fsx.webp'));
      expect(link, startsWith('https://'));
    });

    test('внешняя ссылка остаётся как есть', () {
      const url = 'https://lh3.googleusercontent.com/a/photo';
      expect(avatarLink(url), url);
    });

    test('мусор и пустота дают null, а не битую картинку', () {
      expect(avatarLink(null), isNull);
      expect(avatarLink(''), isNull);
      expect(avatarLink('pb://media/'), isNull);
      expect(avatarLink('pb://media/onlyid'), isNull);
      expect(avatarLink('pb://media/id/'), isNull);
      expect(avatarLink('какая-то строка'), isNull);
    });
  });
}
