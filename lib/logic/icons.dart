import 'package:flutter/material.dart';
import '../design/myna.dart';
import 'icon_search.dart';

/// Значок по имени. Человек не выбирает картинку каждый раз: приложение
/// угадывает её по основе слова, а выбранный вручную значок хранится в базе и
/// перебивает догадку.
///
/// Словарь по основам, а не по целым словам: «продукты», «продуктовый» и
/// «продуктов» должны дать один значок.

const _categoryHints = <String, IconData>{
  'продукт': Myna.store,
  'еда': Myna.pizza,
  'магаз': Myna.store,
  'кафе': Myna.coffee,
  'ресторан': Myna.roomService,
  'кофе': Myna.coffee,
  'бар': Myna.cocktail,
  'доставк': Myna.motorbikePackage,
  'покупк': Myna.cart,
  'одежд': Myna.shoppingBag,
  'обув': Myna.package,
  'электрон': Myna.monitor,
  'техник': Myna.microchip,
  'дом': Myna.home,
  'аренд': Myna.key,
  'квартир': Myna.building,
  'ремонт': Myna.wrench,
  'мебел': Myna.sofa,
  'коммунал': Myna.droplets,
  'свет': Myna.lamp,
  'газ': Myna.flame,
  'связ': Myna.mobileSignalFour,
  'интернет': Myna.wifi,
  'телефон': Myna.mobile,
  'подписк': Myna.refresh,
  'транспорт': Myna.train,
  'такси': Myna.navigation,
  'метро': Myna.railSymbol,
  'бензин': Myna.droplet,
  'топлив': Myna.droplet,
  'машин': Myna.wheel,
  'авто': Myna.wheel,
  'парков': Myna.parking,
  'здоров': Myna.heart,
  'аптек': Myna.briefcaseMedical,
  'лекарств': Myna.thermometer,
  'врач': Myna.hospital,
  'спорт': Myna.activity,
  'зал': Myna.activity,
  'красот': Myna.flower,
  'парикмах': Myna.scissors,
  'развлеч': Myna.confetti,
  'кино': Myna.film,
  'игр': Myna.controller,
  'музык': Myna.headphones,
  'книг': Myna.bookOpen,
  'образован': Myna.graduationCap,
  'учеб': Myna.graduationCap,
  'курс': Myna.presentation,
  'путешеств': Myna.plane,
  'отпуск': Myna.umbrella,
  'отел': Myna.hotel,
  'подар': Myna.gift,
  'праздник': Myna.cake,
  'питом': Myna.bowl,
  'дет': Myna.baby,
  'налог': Myna.bank,
  'штраф': Myna.scale,
  'комисс': Myna.percentage,
  'кредит': Myna.creditCardCheck,
  'долг': Myna.hand,
  'благотвор': Myna.heartPlus,
  'работ': Myna.briefcase,
  'стипенд': Myna.graduationCap,
  'донат': Myna.heartPlus,
  'зарплат': Myna.dollarSquare,
  'аванс': Myna.dollarSquare,
  'фриланс': Myna.terminal,
  'подработ': Myna.briefcaseBusiness,
  'процент': Myna.trendingUp,
  'вклад': Myna.box,
  'инвест': Myna.chartLine,
  'реклам': Myna.speaker,
  'продаж': Myna.label,
  'возврат': Myna.cornerUpLeft,
  'разработ': Myna.code,
  'сервис': Myna.cloud,
  'хостинг': Myna.servers,
};

const _accountHints = <String, IconData>{
  'налич': Myna.dollarSquare,
  'карт': Myna.creditCard,
  'банк': Myna.bank,
  'счёт': Myna.bank,
  'счет': Myna.bank,
  'отлож': Myna.box,
  'копилк': Myna.box,
  'накоп': Myna.box,
  'вклад': Myna.box,
  'крипт': Myna.bitcoin,
  'binance': Myna.bitcoin,
  'кошел': Myna.pocket,
  'boosty': Myna.heartPlus,
  'цель': Myna.flag,
};

/// Все значки денег: расходы и доходы вместе, без повторов.
///
/// Из них собирается ассорти на фоне входа — человек видит, о чём приложение,
/// ещё не введя почту. Порядок постоянный (словарь у Dart упорядочен), поэтому
/// и рисунок фона одинаков от запуска к запуску.
List<IconData> moneyIconSet() {
  final out = <IconData>[];
  for (final icon in [..._categoryHints.values, ...iconChoices.values]) {
    if (!out.contains(icon)) out.add(icon);
  }
  return out;
}

/// Значки, из которых человек выбирает вручную. Ключ уезжает в базу строкой,
/// поэтому список можно дополнять, но переименовывать ключи нельзя.
const iconChoices = <String, IconData>{
  'shopping': Myna.cart,
  'grocery': Myna.store,
  'food': Myna.pizza,
  'cafe': Myna.coffee,
  'home': Myna.home,
  'car': Myna.wheel,
  'bus': Myna.train,
  'health': Myna.heart,
  'pill': Myna.thermometer,
  'sport': Myna.activity,
  'beauty': Myna.flower,
  'fun': Myna.confetti,
  'movie': Myna.film,
  'game': Myna.controller,
  'book': Myna.bookOpen,
  'school': Myna.graduationCap,
  'travel': Myna.plane,
  'gift': Myna.gift,
  'pet': Myna.bowl,
  'child': Myna.baby,
  'phone': Myna.mobile,
  'wifi': Myna.wifi,
  'device': Myna.monitor,
  'salary': Myna.dollarSquare,
  'work': Myna.briefcaseBusiness,
  'invest': Myna.chartLine,
  'savings': Myna.box,
  'bank': Myna.bank,
  'card': Myna.creditCard,
  'cash': Myna.dollarSquare,
  'crypto': Myna.bitcoin,
  'wallet': Myna.pocket,
  'tax': Myna.bank,
  'other': Myna.dots,
};

/// Значки, из которых человек выбирает СЧЁТУ. Набор категорий сюда не годится:
/// пицца и котёнок счёт не подписывают. Ключи взяты оттуда же — поле хранения
/// у категории и счёта одно, и знак, найденный поиском, ложится рядом.
const accountIconChoices = <String, IconData>{
  'card': Myna.creditCard,
  'cash': Myna.dollarSquare,
  'bank': Myna.bank,
  'wallet': Myna.pocket,
  'savings': Myna.box,
  'crypto': Myna.bitcoin,
  'invest': Myna.chartLine,
  'work': Myna.briefcaseBusiness,
  'gift': Myna.gift,
  'travel': Myna.plane,
  'phone': Myna.mobile,
  'home': Myna.home,
  'car': Myna.wheel,
  'child': Myna.baby,
  'health': Myna.heart,
  'fun': Myna.confetti,
  'shopping': Myna.cart,
  'other': Myna.dots,
};

IconData _guess(String name, Map<String, IconData> hints, IconData fallback) {
  final low = name.toLowerCase();
  // Длинные основы вперёд: «продуктовый магазин» должен стать продуктами, а не
  // магазином вообще.
  final keys = hints.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (low.contains(k)) return hints[k]!;
  }
  return fallback;
}

/// Выбранный человеком значок.
///
/// Ключей теперь ДВА рода: короткие из `iconChoices` (лежат в базе с первых
/// версий) и имена самого набора MyNaUI — их кладёт поиск по всем 1310
/// знакам. Сперва смотрим свои, потом набор: иначе имя `home` из набора
/// перебило бы старый ключ `home`.
IconData? _chosen(String? stored) {
  if (stored == null || stored.isEmpty) return null;
  return iconChoices[stored] ?? iconByName(stored);
}

IconData categoryIcon(String name, {String? stored}) =>
    _chosen(stored) ?? _guess(name, _categoryHints, Myna.tag);

IconData accountIcon(String name, {String? stored}) =>
    _chosen(stored) ?? _guess(name, _accountHints, Myna.pocket);

IconData goalIcon(String name, {String? stored}) =>
    _chosen(stored) ?? _guess(name, _categoryHints, Myna.flag);

/// Знаки для ассорти цели: свой знак цели и соседи по смыслу.
///
/// Одним знаком фактура не живёт — сорок одинаковых значков читаются обоями,
/// за этим у кварталов и собирают набор из подкатегорий. У цели подкатегорий
/// нет, поэтому к её знаку добавляются общие: мишень, флажок и звезда.
List<IconData> goalScatterIcons(String name,
    {String? stored, bool reserve = false}) {
  final out = <IconData>[reserve ? Myna.shield : goalIcon(name, stored: stored)];
  for (final extra in [Myna.target, Myna.flag, Myna.star, Myna.sparkles]) {
    if (!out.contains(extra)) out.add(extra);
    if (out.length == 4) break;
  }
  return out;
}
