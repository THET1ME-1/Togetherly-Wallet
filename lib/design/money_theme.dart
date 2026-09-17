import 'package:flutter/material.dart';

import '../ui/theme/tm_scheme.dart';
import '../ui/theme/tm_text.dart';
import '../ui/theme/tm_tokens.dart';
import 'app_theme.dart';

/// Тема Togetherly Money поверх каркаса Орбиты — ПЕЧАТЬ.
///
/// Схема собрана руками, а не из seed: ровно белый лист с чёрным текстом и
/// ровно чёрный с белым, нулевая температура. Цвет остался на приходе и
/// расходе, и дальше суммы, знака и графика он не идёт — на кнопки, плашки и
/// значки цвет не заходит (решение человека, 13.09.2026).
///
/// Экраны Орбиты берут цвета из `ColorScheme`, поэтому подмена схемы переодевает
/// их целиком; поверх снимаются тени и правятся радиусы — плоскость и ступень
/// поверхности вместо подъёма это правило системы, а не украшение.
abstract final class MoneyTheme {
  static ThemeData light() => _build(TmPalette.light);

  static ThemeData dark() => _build(TmPalette.night);

  static ColorScheme scheme(TmPalette p) => ColorScheme(
        brightness: p.dark ? Brightness.dark : Brightness.light,
        // Главный цвет системы — сам текст: чёрная кнопка на белом листе,
        // белая на чёрном. Ни мяты, ни лаванды в палитре больше нет.
        primary: p.accent,
        onPrimary: p.onAccent,
        // ВЫБРАННОЕ = ИНВЕРСИЯ. Обе пары контейнеров означают в экранах ровно
        // одно: «этот вариант выбран». Пока они равнялись `field`, выбранная
        // пилюля ничем не отличалась от соседних — тип счёта, платёжная
        // система, расход/доход, период бюджета и ещё полтора десятка мест
        // читались как список без выбора (поймано на живом эмуляторе
        // 14.09.2026). Заливка чёрным по белому и белым по чёрному — то же
        // правило, по которому живёт главная кнопка.
        primaryContainer: p.accent,
        onPrimaryContainer: p.onAccent,
        secondary: p.text,
        onSecondary: p.onAccent,
        secondaryContainer: p.accent,
        onSecondaryContainer: p.onAccent,
        tertiary: p.muted,
        onTertiary: p.onAccent,
        tertiaryContainer: p.field,
        onTertiaryContainer: p.text,
        // Ошибка красная только в тексте: заливка остаётся серой ступенью.
        error: p.expense,
        onError: p.onAccent,
        errorContainer: p.field,
        onErrorContainer: p.expense,
        surface: p.bg,
        onSurface: p.text,
        onSurfaceVariant: p.muted,
        surfaceContainerLowest: p.bg,
        surfaceContainerLow: p.card,
        surfaceContainer: p.card,
        surfaceContainerHigh: p.card,
        surfaceContainerHighest: p.field,
        surfaceTint: const Color(0x00000000),
        outline: p.line,
        outlineVariant: p.lineSoft,
        inverseSurface: p.text,
        onInverseSurface: p.bg,
        inversePrimary: p.bg,
        shadow: const Color(0x00000000),
        scrim: const Color(0x99000000),
      );

  /// Переход между экранами: проявление с лёгким подъёмом.
  ///
  /// Системный сдвиг справа налево на печатном листе выглядел рывком; здесь
  /// страница проступает, как переворот листа.
  static const _pages = PageTransitionsTheme(builders: {
    TargetPlatform.android: _FadeUpTransition(),
    TargetPlatform.iOS: _FadeUpTransition(),
    TargetPlatform.linux: _FadeUpTransition(),
    TargetPlatform.macOS: _FadeUpTransition(),
    TargetPlatform.windows: _FadeUpTransition(),
  });

  static ThemeData _build(TmPalette p) {
    final base = AppTheme.fromScheme(scheme(p));
    return base.copyWith(
      pageTransitionsTheme: _pages,
      extensions: [p],
      scaffoldBackgroundColor: p.bg,
      // Теней нет нигде: глубина — заливка, граница и ступень поверхности.
      shadowColor: const Color(0x00000000),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: p.bg,
        surfaceTintColor: const Color(0x00000000),
        scrolledUnderElevation: 0,
        titleTextStyle: TmText.navTitle(p.text).copyWith(fontSize: 20),
        iconTheme: IconThemeData(color: p.textAlpha(0.75), size: 22),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: p.card,
        elevation: 0,
        surfaceTintColor: const Color(0x00000000),
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
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          shape: const StadiumBorder(),
          textStyle: TmText.button(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 26),
          side: BorderSide(color: p.textAlpha(0.22), width: 1.5),
          shape: const StadiumBorder(),
          textStyle: TmText.button(p.text),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          textStyle: TmText.button(),
          minimumSize: const Size(0, kTmMinTap),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.field,
        selectedColor: p.accent,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TmRadius.chip)),
        labelStyle: TmText.label(p.text),
        // `ChoiceChip` берёт этот стиль, когда выбран. `FilterChip` — НЕ
        // берёт: у него один `labelStyle` на оба состояния, и цвет ему
        // задаётся в самом виджете (см. `filters_sheet`). Пробовал сделать
        // это здесь через `WidgetStateTextStyle` — чип применил его цвет ко
        // ВСЕМ состояниям разом, и невыбранные пилюли стали белыми по
        // светло-серому (видел на эмуляторе 14.09.2026).
        secondaryLabelStyle: TmText.label(p.onAccent),
        checkmarkColor: p.onAccent,
        elevation: 0,
        pressElevation: 0,
      ),
      // Выпадающее меню отрезка: по умолчанию Material красит его в
      // `surfaceContainer`, то есть в цвет карточки, а теней в системе нет —
      // и меню вставало поверх содержимого невидимой плашкой, сквозь которую
      // читались чужие строки. Лист приложения и граница 1px возвращают ему
      // край.
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        stopIndicatorColor: const Color(0x00000000),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: p.bg,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TmRadius.field),
          side: BorderSide(color: p.line),
        ),
        textStyle: TmText.body(p.text),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: p.card,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TmRadius.section)),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: p.card,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(TmRadius.sheet)),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: p.card,
        surfaceTintColor: const Color(0x00000000),
        elevation: 0,
        indicatorColor: p.field,
        // Значок выбранного пункта красится ЯВНО. По умолчанию Material
        // берёт onSecondaryContainer, а он у нас равен onAccent — и на
        // подложке `field` выходил белый значок по светло-серому в светлой
        // теме и чёрный по тёмно-серому в тёмной. Пункт «Главная» просто
        // пропадал (14.09.2026).
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? p.text
                  : p.textAlpha(0.7),
            )),
        labelTextStyle: WidgetStatePropertyAll(TmText.meta(p.textAlpha(0.7))),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: p.field,
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
        hintStyle: TmText.body(p.textAlpha(0.45)),
        labelStyle: TmText.label(p.textAlpha(0.6)),
      ),
      dividerTheme: DividerThemeData(color: p.lineSoft, thickness: 1, space: 1),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const StadiumBorder(),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: p.text,
        contentTextStyle: TmText.label(p.bg),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TmRadius.field)),
      ),
    );
  }
}

class _FadeUpTransition extends PageTransitionsBuilder {
  const _FadeUpTransition();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppTheme.emphasizedDecelerate,
      reverseCurve: AppTheme.emphasized,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
