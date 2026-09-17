import 'package:flutter/material.dart';

import 'tm_scheme.dart';
import 'tm_text.dart';
import 'tm_tokens.dart';

/// Тема без единой тени. Глубина строится ступенью поверхности,
/// границей 1px и цветом — это жёсткое правило системы.
abstract final class TmTheme {
  static ThemeData light() => _base(TmPalette.light);

  static ThemeData dark() => _base(TmPalette.night);

  static ThemeData _base(TmPalette p) {
    final brightness = p.dark ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.onAccent,
      primaryContainer: p.field,
      onPrimaryContainer: p.onAccent,
      secondary: p.accent,
      onSecondary: p.onAccent,
      secondaryContainer: p.field,
      onSecondaryContainer: p.onAccent,
      error: p.expense,
      onError: const Color(0xFFFFFFFF),
      errorContainer: p.field,
      onErrorContainer: p.expense,
      surface: p.card,
      onSurface: p.text,
      surfaceContainerLowest: p.bg,
      surfaceContainerHighest: p.field,
      outline: p.line,
      outlineVariant: p.lineSoft,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.bg,
      shadowColor: const Color(0x00000000), // теней нет
      // InkSparkle требует фрагментный шейдер: на Android со Skia первый тап
      // ждёт его компиляции. Рябь дешевле и ведёт себя одинаково везде.
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: TmText.balanceXxl(p.text),
        headlineMedium: TmText.titleLg(p.text),
        titleLarge: TmText.titleMd(p.text),
        titleMedium: TmText.navTitle(p.text),
        bodyLarge: TmText.body(p.text),
        bodyMedium: TmText.rowTitle(p.text),
        labelLarge: TmText.label(p.textAlpha(0.6)),
        labelSmall: TmText.eyebrow(p.textAlpha(0.5)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TmText.navTitle(p.text),
        iconTheme: IconThemeData(color: p.textAlpha(0.7), size: 22),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TmRadius.card),
          side: BorderSide(color: p.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          textStyle: TmText.button(),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          textStyle: TmText.button(p.text),
          side: BorderSide(color: p.textAlpha(0.2), width: 1.5),
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.field,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TmRadius.field),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TmRadius.field),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TmRadius.field),
          borderSide: BorderSide(color: p.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TmRadius.field),
          borderSide: BorderSide(color: p.expense, width: 1.5),
        ),
        labelStyle: TmText.meta(p.textAlpha(0.6)),
        hintStyle: TmText.body(p.textAlpha(0.45)),
      ),
      dividerTheme: DividerThemeData(color: p.lineSoft, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(TmRadius.sheet)),
        ),
      ),
    );
  }
}
