import 'package:flutter/material.dart';

import 'tm_colors.dart';

/// Роли поверхностей и текста печатной палитры.
///
/// Экраны обязаны брать цвет отсюда (`context.tm.card`), а не из [TmColors]
/// напрямую: константа работает ровно в одной теме, и чёрный текст на чёрном
/// фоне — ровно то, что из этого выходит.
///
/// Цвет остался только на деньгах (`income`, `expense`). Всё остальное — пять
/// ступеней светлоты: лист, карточка, поле, линия, текст.
@immutable
class TmPalette extends ThemeExtension<TmPalette> {
  const TmPalette({
    required this.dark,
    required this.bg,
    required this.card,
    required this.field,
    required this.row,
    required this.text,
    required this.muted,
    required this.line,
    required this.lineSoft,
    required this.track,
    required this.income,
    required this.expense,
    required this.accent,
    required this.onAccent,
  });

  final bool dark;

  /// Фон экрана: ровно белый или ровно чёрный.
  final Color bg;

  /// Карточка поверх фона.
  final Color card;

  /// Поле ввода, неактивный чип, вторая ступень поверхности.
  final Color field;

  /// Строка внутри карточки, приглушённый блок.
  final Color row;

  /// Основной текст.
  final Color text;

  /// Второстепенный текст: подписи, единицы, даты.
  final Color muted;

  final Color line;
  final Color lineSoft;

  /// Трек тумблера и полосы долей.
  final Color track;

  /// Приход и расход — единственный цвет в системе.
  final Color income;
  final Color expense;

  /// Заливка главной кнопки и выбранной пилюли: чёрное по белому и наоборот.
  final Color accent;
  final Color onAccent;

  Color textAlpha(double a) => text.withValues(alpha: a);

  /// Заливка общего и личного больше НЕ различается цветом: разницу говорят
  /// значок и подпись. Поля оставлены, чтобы не переписывать экраны разом.
  Color get sharedFill => field;
  Color get personalFill => field;
  Color get personalTint => card;
  Color get onDark => onAccent;

  static const light = TmPalette(
    dark: false,
    bg: TmColors.paper,
    card: TmColors.card,
    field: TmColors.field,
    row: TmColors.row,
    text: TmColors.ink,
    muted: TmColors.muted,
    line: TmColors.line,
    lineSoft: TmColors.lineSoft,
    track: TmColors.line,
    income: TmColors.income,
    expense: TmColors.expense,
    accent: TmColors.ink,
    onAccent: TmColors.paper,
  );

  static const night = TmPalette(
    dark: true,
    bg: TmColors.paperDark,
    card: TmColors.cardDark,
    field: TmColors.fieldDark,
    row: TmColors.rowDark,
    text: TmColors.inkDark,
    muted: TmColors.mutedDark,
    line: TmColors.lineDark,
    lineSoft: TmColors.lineSoftDark,
    track: TmColors.lineDark,
    income: TmColors.incomeDark,
    expense: TmColors.expenseDark,
    accent: TmColors.inkDark,
    onAccent: TmColors.paperDark,
  );

  @override
  TmPalette copyWith({bool? dark}) => this;

  @override
  TmPalette lerp(ThemeExtension<TmPalette>? other, double t) =>
      t < 0.5 ? this : (other as TmPalette? ?? this);
}

extension TmPaletteContext on BuildContext {
  /// Палитра текущей темы. Экраны берут цвета только так.
  TmPalette get tm =>
      Theme.of(this).extension<TmPalette>() ??
      (Theme.of(this).brightness == Brightness.dark ? TmPalette.night : TmPalette.light);
}
