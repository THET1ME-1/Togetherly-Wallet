/// Стартовый набор категорий: расходы и доходы отдельно, с подкатегориями.
///
/// Пустое приложение после входа не показывало НИ ОДНОЙ категории: список
/// собирался из операций, а операций у нового человека нет. Первую трату было
/// некуда записать, и экран категорий стоял пустым («всё пусто» — 13.09.2026).
///
/// Набор держится в словаре, а не хардкодом по-русски: категории видит человек,
/// и на немецком «Продукты» читаться не должны.
///
/// Значков и цветов здесь нет НАРОЧНО. Значок подбирается по имени
/// (`categoryIcon`), цвет — по имени же (`labelColorFor`): один и тот же
/// список даёт один и тот же вид на обоих телефонах пары, и правка набора не
/// перекрашивает соседей.
library;

import '../data/models.dart';
import '../l10n/strings.dart';

/// Одна строка набора: имя-ключ, доля дохода и подкатегории.
class _Preset {
  const _Preset(this.key, this.bucket, [this.children = const []]);

  /// Ключ словаря: `catFood`, `catHome`. Человек видит перевод.
  final String key;

  /// Нужда, желание или сбережение — от этого считается правило дележа.
  final Bucket bucket;

  /// Ключи подкатегорий.
  final List<String> children;
}

const _expenses = <_Preset>[
  _Preset('catGroceries', Bucket.needs, ['subSupermarket', 'subMarket', 'subDelivery']),
  _Preset('catEatingOut', Bucket.wants, ['subCoffee', 'subLunch', 'subFoodDelivery']),
  _Preset('catTransport', Bucket.needs, ['subTaxi', 'subFuel', 'subTicket', 'subParking']),
  _Preset('catHousing', Bucket.needs, ['subRent', 'subUtilities', 'subInternet', 'subRepair']),
  _Preset('catConnection', Bucket.needs, ['subMobile', 'subSubscriptions']),
  _Preset('catHealth', Bucket.needs, ['subPharmacy', 'subDoctor', 'subTests']),
  _Preset('catBeauty', Bucket.wants, ['subHair', 'subCosmetics']),
  _Preset('catClothes', Bucket.wants, ['subClothes', 'subShoes']),
  _Preset('catFun', Bucket.wants, ['subCinema', 'subGames', 'subBooks']),
  _Preset('catSport', Bucket.wants, ['subGym', 'subGear']),
  _Preset('catEducation', Bucket.needs, ['subCourses', 'subTextbooks']),
  _Preset('catTravel', Bucket.wants, ['subTickets', 'subStay']),
  _Preset('catGifts', Bucket.wants),
  _Preset('catPets', Bucket.needs, ['subPetFood', 'subVet']),
  _Preset('catKids', Bucket.needs),
  _Preset('catSavings', Bucket.savings),
  _Preset('catOther', Bucket.none),
];

const _incomes = <_Preset>[
  _Preset('catSalary', Bucket.none),
  _Preset('catAdvance', Bucket.none),
  _Preset('catSideJob', Bucket.none),
  _Preset('catFreelance', Bucket.none),
  _Preset('catInterest', Bucket.none),
  _Preset('catRefund', Bucket.none),
  _Preset('catGiftIn', Bucket.none),
  _Preset('catSale', Bucket.none),
  _Preset('catOtherIn', Bucket.none),
];

/// Весь стартовый набор одним списком: сперва расходные, следом доходные.
/// Подкатегория идёт сразу за своим родителем — так её видно в правке рядом.
List<Category> presetCategories() {
  final out = <Category>[];
  void add(List<_Preset> group, CatKind kind) {
    for (final p in group) {
      final name = tr(p.key);
      out.add(Category(name: name, bucket: p.bucket, kind: kind));
      for (final child in p.children) {
        // У подкатегории своей доли НЕТ: она наследует родительскую, иначе
        // одна трата попала бы в две доли правила.
        out.add(Category(name: tr(child), parent: name, kind: kind));
      }
    }
  }

  add(_expenses, CatKind.expense);
  add(_incomes, CatKind.income);
  return out;
}

/// Сколько всего строк в наборе — для подписи кнопки в настройках.
int presetCount() => presetCategories().length;
