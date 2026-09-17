import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/theme/tm_colors.dart';

/// Цвет, который несёт смысл, а не настроение: приход и расход.
///
/// В печатной палитре это единственное место, где цвет вообще появляется, и
/// живёт он только в сумме, знаке и графике. Оттенки разные для светлой и
/// тёмной темы: зелёный, различимый на белом, на чёрном выглядит грязным.
class Money {
  Money._();

  static const _upLight = TmColors.income;
  static const _upDark = TmColors.incomeDark;
  static const _downLight = TmColors.expense;
  static const _downDark = TmColors.expenseDark;

  static Color up(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _upDark : _upLight;

  static Color down(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _downDark : _downLight;

  /// Цвет по знаку суммы. Ноль — обычный текст: подсвечивать нечего.
  static Color? forAmount(BuildContext context, double v) {
    if (v > 0) return up(context);
    if (v < 0) return down(context);
    return null;
  }
}

/// Метки категорий, подкатегорий и счетов — ЦВЕТНЫЕ.
///
/// Поверхности в системе печатные (белый лист, чёрный текст), но метки цвет
/// сохранили: «счета сделать цветными, как и категории» (13.09.2026). По
/// цвету человек узнаёт свою категорию в ленте, в кольце и на карточке счёта
/// быстрее, чем по значку.
///
/// Пастели одной светлоты: буквы на них всегда тёмные, поэтому метка читается
/// в обеих темах без второго набора цветов. Двадцать три плюс «подберу сам» —
/// ровно четыре ряда по шесть в листе выбора.
const labelColors = <Color>[
  Color(0xFFADD5F2),     // небо
  Color(0xFFF2D68A),     // песок
  Color(0xFFC5CDB2),     // олива
  Color(0xFFF4A58C),     // персик
  Color(0xFFE08AA0),     // роза
  Color(0xFFD9D2EA),     // лаванда
  Color(0xFFA8D8C9),     // мята
  Color(0xFFE7C2E0),     // сирень
  Color(0xFFF2C6A0),     // абрикос
  Color(0xFFBFD0EE),     // барвинок
  Color(0xFFD8DEA8),     // фисташка
  Color(0xFFF0B9B4),     // терракота
  Color(0xFFC7E5F0),     // лёд
  Color(0xFFF3D9A4),     // мёд
  Color(0xFFB9E0B4),     // трава
  Color(0xFFF5BFD2),     // зефир
  Color(0xFFCFC7EE),     // ирис
  Color(0xFFEFD3B8),     // карамель
  Color(0xFF9FD4D8),     // бирюза
  Color(0xFFE3E0A6),     // лайм
  Color(0xFFDCC3AC),     // какао
  Color(0xFFC3DCC0),     // шалфей
  Color(0xFFB6C7DE),     // джинса
];

/// Цвет метки по имени: одно и то же имя всегда даёт одну и ту же ступень,
/// даже если список пересобрали. Считается по строке, а не по позиции.
Color labelColorFor(String name) {
  var h = 0;
  for (final unit in name.codeUnits) {
    h = (h * 31 + unit) & 0x7FFFFFFF;
  }
  return labelColors[h % labelColors.length];
}

/// Чёрные или светлые буквы поверх заливки. Порог по воспринимаемой яркости.
///
/// Две ошибки разом жили здесь до 14.09.2026, и обе давали БЕЛЫЕ буквы на
/// светлой пастели: канал возводился в квадрат вместо 2.4 (яркость средних
/// тонов завышалась), а порог стоял 0.45 вместо точки, где контраст чёрного и
/// белого сравнивается. Из-за этого значок счёта на розовом и подпись
/// квартала «Коррекция» читались через силу — 2,5:1 вместо 8:1.
///
/// Точка равенства: `sqrt(1.05 * 0.05) - 0.05 ≈ 0.179`. Выше — чёрные буквы,
/// ниже — белые. Все пастели набора оказываются выше, как и обещано в их
/// описании: «буквы на них всегда тёмные».
Color inkOn(Color bg) {
  double lin(double v) => v <= 0.03928
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final l = 0.2126 * lin(bg.r) + 0.7152 * lin(bg.g) + 0.0722 * lin(bg.b);
  return l > 0.179 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
}
