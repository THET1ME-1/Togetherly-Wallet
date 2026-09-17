import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/design/myna_search.dart';
import 'package:togetherly_money/logic/icon_search.dart';
import 'package:togetherly_money/logic/icons.dart';

void main() {
  group('поиск значка', () {
    test('в каталоге весь набор', () {
      // «Мало иконок, хоть бы поиск сделал по всей базе» — 13.09.2026.
      expect(mynaByName.length, 1310);
    });

    test('русское слово находит нужное', () {
      final food = searchIcons('еда').map((h) => h.name);
      expect(food, contains('bowl'));

      final home = searchIcons('дом').map((h) => h.name);
      expect(home.first, anyOf('home', 'home-smile', 'building'));

      final card = searchIcons('карта').map((h) => h.name);
      expect(card, contains('credit-card'));
    });

    test('английское имя и метка тоже ищутся', () {
      expect(searchIcons('cart').map((h) => h.name), contains('cart'));
      // Метка, а не имя: у `plane` в метках стоит travel.
      expect(searchIcons('travel').map((h) => h.name), contains('plane'));
    });

    test('пустой запрос показывает начало набора, а не пустоту', () {
      expect(searchIcons('').length, greaterThan(50));
    });

    test('мусорный запрос не роняет и отдаёт пусто', () {
      expect(searchIcons('щщщщ'), isEmpty);
    });

    test('имя из набора становится значком категории', () {
      // Ключ уезжает в базу строкой, и приложение обязано узнать его обратно.
      final icon = categoryIcon('Что угодно', stored: 'rocket');
      expect(icon, mynaByName['rocket']);
      // Старые короткие ключи продолжают работать.
      expect(categoryIcon('Что угодно', stored: 'food'), isNotNull);
      // Неизвестное имя не ломает: значок подберётся по слову.
      expect(categoryIcon('Продукты', stored: 'нет-такого'), isNotNull);
    });
  });
}
