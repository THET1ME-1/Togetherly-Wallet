/// Поиск значка по слову — по всему набору MyNaUI.
///
/// Имена и метки в наборе английские, а спрашивают по-русски. Поэтому поверх
/// лежит свой слой: русское слово → имена знаков. Без него «еда» не находила
/// ничего, а список из 1310 английских имён человеку бесполезен.
library;

import 'package:flutter/widgets.dart';

import '../design/myna_search.dart';

/// Русские слова к знакам. Пишется руками и НАРОЧНО коротко: сюда попадает
/// только то, о чём люди просят, заводя категорию или счёт.
const Map<String, List<String>> _ru = {
  'еда': ['bowl', 'pizza', 'croissant', 'egg', 'cookie', 'cupcake'],
  'продукты': ['cart', 'store', 'shopping-bag'],
  'магазин': ['store', 'shopping-bag', 'cart'],
  'покупки': ['shopping-bag', 'cart', 'package'],
  'кафе': ['coffee', 'croissant', 'cupcake'],
  'кофе': ['coffee'],
  'ресторан': ['room-service', 'pizza', 'wine'],
  'бар': ['cocktail', 'wine'],
  'вино': ['wine'],
  'дом': ['home', 'home-smile', 'building', 'building-one'],
  'квартира': ['building', 'building-one'],
  'жильё': ['home', 'building'],
  'аренда': ['key', 'home'],
  'ремонт': ['wrench', 'tool', 'shovel'],
  'мебель': ['sofa', 'lamp'],
  'свет': ['lamp', 'lightning', 'brightness-high'],
  'вода': ['droplet', 'droplets'],
  'газ': ['flame', 'fire'],
  'связь': ['mobile-signal-four', 'telephone', 'mobile'],
  'телефон': ['mobile', 'telephone'],
  'интернет': ['wifi', 'globe'],
  'подписки': ['refresh', 'repeat'],
  'транспорт': ['train', 'bike', 'motorbike', 'truck', 'boat'],
  'машина': ['wheel', 'caravan'],
  'такси': ['navigation', 'wheel'],
  'автобус': ['train', 'truck'],
  'метро': ['rail-symbol', 'train'],
  'поезд': ['train'],
  'самолёт': ['plane'],
  'самолет': ['plane'],
  'бензин': ['droplet', 'flame'],
  'топливо': ['droplet'],
  'парковка': ['parking'],
  'велосипед': ['bike'],
  'здоровье': ['heart', 'activity', 'hospital'],
  'аптека': ['briefcase-medical', 'thermometer'],
  'лекарства': ['thermometer', 'briefcase-medical'],
  'врач': ['hospital', 'briefcase-medical'],
  'спорт': ['activity', 'baseball', 'bike'],
  'зал': ['activity'],
  'красота': ['flower', 'sparkles', 'scissors'],
  'парикмахерская': ['scissors'],
  'одежда': ['tag', 'shopping-bag'],
  'обувь': ['package', 'shopping-bag'],
  'развлечения': ['confetti', 'controller', 'film'],
  'кино': ['film', 'video', 'tv'],
  'игры': ['controller', 'dice-1', 'puzzle'],
  'музыка': ['music', 'headphones', 'speaker'],
  'книги': ['book-open', 'book'],
  'учёба': ['graduation-cap', 'backpack', 'book-open'],
  'учеба': ['graduation-cap', 'backpack'],
  'образование': ['graduation-cap', 'book-open'],
  'курсы': ['presentation', 'graduation-cap'],
  'путешествия': ['plane', 'luggage', 'map', 'compass'],
  'отпуск': ['umbrella', 'plane', 'tent'],
  'отель': ['hotel', 'bath'],
  'подарок': ['gift', 'ribbon'],
  'подарки': ['gift', 'ribbon'],
  'праздник': ['confetti', 'cake', 'balloon'],
  'день рождения': ['cake', 'confetti'],
  'питомцы': ['bowl', 'shell'],
  'кот': ['bowl'],
  'собака': ['bowl'],
  'дети': ['baby'],
  'ребёнок': ['baby'],
  'ребенок': ['baby'],
  'деньги': ['bank', 'credit-card', 'dollar-square', 'bitcoin', 'percentage'],
  'банк': ['bank', 'building'],
  'карта': ['credit-card', 'contactless'],
  'наличные': ['dollar-square', 'dollar-circle'],
  'кошелёк': ['pocket'],
  'кошелек': ['pocket'],
  'копилка': ['box', 'package', 'bank'],
  'накопления': ['box', 'trending-up'],
  'сбережения': ['box', 'bank'],
  'зарплата': ['dollar-square', 'briefcase'],
  'работа': ['briefcase', 'briefcase-business'],
  'подработка': ['briefcase-business', 'terminal'],
  'фриланс': ['terminal', 'code', 'monitor'],
  'инвестиции': ['trending-up', 'chart-line', 'chart-bar'],
  'проценты': ['percentage', 'trending-up'],
  'крипта': ['bitcoin'],
  'налоги': ['bank', 'scale'],
  'штраф': ['scale', 'danger-triangle'],
  'долг': ['hand', 'scale'],
  'кредит': ['credit-card-check', 'bank'],
  'возврат': ['corner-up-left', 'undo'],
  'продажа': ['label', 'store'],
  'реклама': ['speaker', 'megaphone'],
  'благотворительность': ['heart-plus', 'hand'],
  'цель': ['target', 'flag'],
  'план': ['list-check', 'clipboard'],
  'время': ['clock-circle', 'alarm-clock'],
  'календарь': ['calendar', 'calendar-check'],
  'прочее': ['label', 'dots', 'tag'],
  'разное': ['dots', 'label'],
  'звезда': ['star', 'shooting-star'],
  'сердце': ['heart', 'heart-plus'],
  'огонь': ['fire', 'flame'],
  'растение': ['sprout', 'leaf', 'tree', 'flower'],
  'природа': ['tree', 'mountain', 'sea-waves'],
  'погода': ['cloud', 'sun', 'snowflake', 'umbrella'],
  'компьютер': ['monitor', 'microchip', 'terminal'],
  'фото': ['camera', 'image'],
  'видео': ['video', 'film'],
  'почта': ['mail', 'mail-open'],
  'сообщение': ['message', 'chat'],
  'замок': ['lock', 'key'],
  'щит': ['shield', 'shield-check'],
};

/// Найденные знаки: имя набора и сам знак. Имя уезжает в базу строкой.
typedef IconHit = ({String name, IconData icon});

/// Отобрать знаки по слову. Пустой запрос отдаёт начало набора — так человек
/// видит, что выбор есть, ещё ничего не набрав.
List<IconHit> searchIcons(String query, {int limit = 120}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return [
      for (final name in mynaByName.keys.take(limit))
        (name: name, icon: mynaByName[name]!),
    ];
  }

  // Русское слово сперва: «еда» обязана дать миску, а не `email`.
  final ranked = <String, int>{};
  void bump(String name, int weight) {
    final was = ranked[name];
    if (was == null || weight < was) ranked[name] = weight;
  }

  for (final entry in _ru.entries) {
    if (!entry.key.contains(q) && !q.contains(entry.key)) continue;
    for (var i = 0; i < entry.value.length; i++) {
      if (mynaByName.containsKey(entry.value[i])) bump(entry.value[i], i);
    }
  }
  for (final name in mynaByName.keys) {
    if (name == q) {
      bump(name, 10);
    } else if (name.startsWith(q)) {
      bump(name, 20);
    } else if (name.contains(q)) {
      bump(name, 30);
    } else if ((mynaTags[name] ?? '').contains(q)) {
      bump(name, 40);
    }
  }

  final names = ranked.keys.toList()
    ..sort((a, b) {
      final byRank = ranked[a]!.compareTo(ranked[b]!);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  return [
    for (final name in names.take(limit)) (name: name, icon: mynaByName[name]!),
  ];
}

/// Знак по сохранённому имени. Неизвестное имя — null, и тогда значок
/// подбирается по слову, как раньше.
IconData? iconByName(String? name) => name == null ? null : mynaByName[name];
