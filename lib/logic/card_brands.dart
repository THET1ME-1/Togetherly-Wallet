/// Какие платёжные системы показывать первыми.
///
/// Список был один на всех: молдаванину предлагали МИР, россиянину —
/// UnionPay и Amex. Ни у того, ни у другого такой карты нет, а нужная стояла
/// в конце ряда («отображает платёжные системы только те, что мне доступны по
/// регионам, или как?» — 13.09.2026).
///
/// Ничего не прячем: карту могли привезти откуда угодно, и человек с Amex в
/// Кишинёве не должен упираться в стену. Меняется только ПОРЯДОК — нужное
/// впереди.
library;

import 'dart:ui' as ui;

import '../data/models.dart';

/// Порядок систем для страны. Код страны — двухбуквенный, как в локали.
List<CardBrand> brandsFor(String? country) {
  final code = (country ?? '').toUpperCase();

  // Страны МИРа: там он первый, а UnionPay встречается чаще Amex.
  const mirLands = {'RU', 'BY', 'KZ', 'AM', 'KG', 'TJ', 'UZ', 'AB', 'OS'};
  if (mirLands.contains(code)) {
    return const [
      CardBrand.none,
      CardBrand.mir,
      CardBrand.visa,
      CardBrand.mastercard,
      CardBrand.maestro,
      CardBrand.unionpay,
      CardBrand.amex,
    ];
  }

  if (code == 'CN' || code == 'HK' || code == 'MO') {
    return const [
      CardBrand.none,
      CardBrand.unionpay,
      CardBrand.visa,
      CardBrand.mastercard,
      CardBrand.amex,
      CardBrand.maestro,
      CardBrand.mir,
    ];
  }

  if (code == 'US' || code == 'CA') {
    return const [
      CardBrand.none,
      CardBrand.visa,
      CardBrand.mastercard,
      CardBrand.amex,
      CardBrand.unionpay,
      CardBrand.maestro,
      CardBrand.mir,
    ];
  }

  // Молдова, Румыния и вся Европа: Visa с Mastercard, следом Maestro — он тут
  // ещё живёт на дебетовых.
  return const [
    CardBrand.none,
    CardBrand.visa,
    CardBrand.mastercard,
    CardBrand.maestro,
    CardBrand.amex,
    CardBrand.unionpay,
    CardBrand.mir,
  ];
}

/// Порядок по стране устройства. Страны в локали может не быть вовсе — тогда
/// работает европейский порядок.
List<CardBrand> brandsHere() =>
    brandsFor(ui.PlatformDispatcher.instance.locale.countryCode);
