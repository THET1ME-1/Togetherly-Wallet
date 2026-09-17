import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/logic/snapshot_crypto.dart';

/// Шифрование снимков базы.
///
/// Обещание витрины — «зашифрованный снимок за каждый день», и оно обязано
/// быть правдой: ключа у сервера нет, а подменённый кусок не должен
/// расшифроваться в мусор и уехать в базу человека.

void main() {
  test('свой снимок открывается своей фразой', () async {
    final phrase = SnapshotCrypto.newPhrase();
    final salt = SnapshotCrypto.newSalt();
    final key = await SnapshotCrypto.keyOf(phrase, salt);

    const json = '{"accounts":[{"name":"Карта"}],"total":18082.40}';
    final sealed = await SnapshotCrypto.seal(key, json);
    expect(sealed, isNot(contains('Карта')));

    final same = await SnapshotCrypto.keyOf(phrase, salt);
    expect(await SnapshotCrypto.open(same, sealed), json);
  });

  test('чужая фраза не открывает', () async {
    final salt = SnapshotCrypto.newSalt();
    final mine = await SnapshotCrypto.keyOf(SnapshotCrypto.newPhrase(), salt);
    final other = await SnapshotCrypto.keyOf(
        ['якорь', 'берег', 'ветер', 'гнездо', 'дорога', 'ель'], salt);

    final sealed = await SnapshotCrypto.seal(mine, '{"a":1}');
    expect(await SnapshotCrypto.open(other, sealed), isEmpty);
  });

  test('подменённый кусок не расшифровывается', () async {
    // AES-GCM проверяет целостность сам: выдать испорченный снимок за данные
    // он не может, и в базу человека мусор не уедет.
    final phrase = SnapshotCrypto.newPhrase();
    final salt = SnapshotCrypto.newSalt();
    final key = await SnapshotCrypto.keyOf(phrase, salt);

    final sealed = await SnapshotCrypto.seal(key, '{"a":1}');
    final broken = '${sealed.substring(0, sealed.length - 6)}AAAAAA';
    expect(await SnapshotCrypto.open(key, broken), isEmpty);
  });

  test('фраза из шести разных слов набора', () {
    final phrase = SnapshotCrypto.newPhrase();
    expect(phrase, hasLength(SnapshotCrypto.phraseLength));
    for (final w in phrase) {
      expect(SnapshotCrypto.words, contains(w));
    }
  });

  test('в наборе слов нет повторов и латиницы', () {
    // Повтор крадёт биты у фразы, а латинская буква посреди русского слова —
    // верный способ не набрать её на телефоне.
    expect(SnapshotCrypto.words.toSet(), hasLength(SnapshotCrypto.words.length));
    final latin = RegExp(r'[A-Za-z]');
    for (final w in SnapshotCrypto.words) {
      expect(latin.hasMatch(w), isFalse, reason: w);
    }
  });
}
