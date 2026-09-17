import 'package:flutter/material.dart';

/// Тема приложения в духе Material 3 Expressive — общая «ДНК» для всех наших
/// приложений (ScoreMaster, Fern, Kadr, …).
///
/// Выразительная типографика (Unbounded для заголовков, Onest для текста),
/// скруглённые «таблеточные» кнопки и крупные формы. Единственное, что меняется
/// от приложения к приложению, — [defaultSeed] (фирменный акцент).
/// Всё остальное трогать НЕЛЬЗЯ: в этом и смысл общего кода — одинаковый вид.
class AppTheme {
  AppTheme._();

  /// Шрифт заголовков и крупных цифр.
  static const String displayFont = 'Unbounded';

  /// Шрифт основного текста.
  static const String bodyFont = 'Onest';

  /// Фирменный seed-цвет приложения, из которого строится ВСЯ схема, пока
  /// пользователь не выбрал свой в настройках. ← ЕДИНСТВЕННОЕ, что меняем под
  /// конкретное приложение. Примеры: ScoreMaster 0xFF00B5C7 (бирюза),
  /// Fern 0xFF2E7D5B (папоротник), Kadr 0xFF00B5C7.
  ///
  /// Орбита — индиго: бирюза и зелень уже заняты соседями, а деньгам нужен
  /// свободный зелёный и красный под доход и расход, поэтому акцент уходит в
  /// холодную часть круга и с ними не спорит.
  static const Color defaultSeed = Color(0xFF6E56F8);

  /// Кривые движения Material 3 «emphasized» — выразительный разгон/торможение
  /// для появлений и переходов (живее, чем стандартный easeOut).
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Вариант генерации схемы из seed-цвета.
  ///
  /// [vibrant] = «Сочно»: [DynamicSchemeVariant.vibrant] — максимальная
  /// насыщенность, темы резко различаются между собой, акцент — яркая версия
  /// выбранного оттенка. Иначе «Точь-в-точь»: [DynamicSchemeVariant.fidelity] —
  /// primary держится ровно у выбранного цвета (что выбрал, то и видишь).
  ///
  /// Дефолт Flutter — `tonalSpot` — специально «пастелит»: срезает насыщенность
  /// до фиксированного низкого уровня, из-за чего любой выбранный цвет выходит
  /// приглушённым, а разные пресеты выглядят похоже. Поэтому у нас «Сочно».
  static DynamicSchemeVariant variantFor(bool vibrant) =>
      vibrant ? DynamicSchemeVariant.vibrant : DynamicSchemeVariant.fidelity;

  static ThemeData light(Color seed, {bool vibrant = true}) =>
      fromScheme(ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
        dynamicSchemeVariant: variantFor(vibrant),
      ));

  /// Тёмная тема. При [amoled] фон становится чисто чёрным, а контейнеры —
  /// очень тёмными (но различимыми), чтобы блоки оставались видны.
  static ThemeData dark(Color seed, {bool amoled = false, bool vibrant = true}) {
    var scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      dynamicSchemeVariant: variantFor(vibrant),
    );
    if (amoled) {
      scheme = scheme.copyWith(
        surface: const Color(0xFF000000),
        surfaceContainerLowest: const Color(0xFF000000),
        surfaceContainerLow: const Color(0xFF0A0A0A),
        surfaceContainer: const Color(0xFF111111),
        surfaceContainerHigh: const Color(0xFF181818),
        surfaceContainerHighest: const Color(0xFF222222),
      );
    }
    return fromScheme(scheme);
  }

  /// Строит тему приложения (шрифты, кнопки, переходы) из готовой [colorScheme].
  /// Это позволяет использовать и seed-цвет, и динамический цвет Material You.
  static ThemeData fromScheme(ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    final textTheme = _expressiveTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontSize: 22,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      // «Таблеточные» крупные кнопки — фирменная черта expressive-стиля.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape: const StadiumBorder(),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 0,
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: TextStyle(
            fontFamily: bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: const StadiumBorder(),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        // Заливка и рамка вместе дают перечёркнутую подпись: Material уносит
        // плавающий labelText НА линию рамки и прорезает под него щель, а щели
        // у нас нет — сторона прозрачная. Человек увидел «Назв8ание» поверх
        // мятной рамки (13.09.2026). Подпись остаётся внутри поля, а где нужна
        // постоянная — она ставится строкой НАД полем, как в каркасе настроек.
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      // Плавающая кнопка — такая же «таблетка», как остальные кнопки ДНК.
      // Без явной формы M3 рисует прямоугольник с радиусом 16, и FAB выпадает
      // из общего языка форм.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        shape: const StadiumBorder(),
        extendedTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // В Money теней нет вовсе: панель отделяется цветом поверхности,
        // а не подъёмом. Правило стережёт test/design_rules_test.dart.
        elevation: 0,
        height: 72,
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: bodyFont,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dividerTheme: const DividerThemeData(thickness: 1),
      // Новые M3-индикаторы загрузки (волнистые, 2024) во всём приложении.
      // ignore: deprecated_member_use
      progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
      // Плавные M3-переходы между экранами (shared-axis: проявление + сдвиг)
      // вместо стандартного слайда — навигация ощущается дороже.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SharedAxisPageTransitionsBuilder(),
          TargetPlatform.iOS: _SharedAxisPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _expressiveTextTheme(TextTheme base) {
    TextStyle display(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        );
    TextStyle headline(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        );
    TextStyle title(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: displayFont,
          fontWeight: FontWeight.w600,
        );
    TextStyle body(TextStyle? s) => (s ?? const TextStyle()).copyWith(
          fontFamily: bodyFont,
        );

    return base.copyWith(
      displayLarge: display(base.displayLarge),
      displayMedium: display(base.displayMedium),
      displaySmall: display(base.displaySmall),
      headlineLarge: headline(base.headlineLarge),
      headlineMedium: headline(base.headlineMedium),
      headlineSmall: headline(base.headlineSmall),
      titleLarge: title(base.titleLarge),
      titleMedium: title(base.titleMedium),
      titleSmall: title(base.titleSmall),
      bodyLarge: body(base.bodyLarge),
      bodyMedium: body(base.bodyMedium),
      bodySmall: body(base.bodySmall),
      labelLarge: body(base.labelLarge),
      labelMedium: body(base.labelMedium),
      labelSmall: body(base.labelSmall),
    );
  }
}

/// Переход «shared-axis X» в духе Material 3: входящий экран чуть выезжает
/// справа и проявляется, уходящий — сдвигается влево и гаснет.
class _SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const shift = 0.05; // доля ширины

    final inSlide = Tween<Offset>(
      begin: const Offset(shift, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: animation, curve: AppTheme.emphasizedDecelerate));
    final inFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.15, 1, curve: Curves.easeOut),
    );

    final outSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-shift, 0),
    ).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInCubic));
    final outFade = Tween<double>(begin: 1, end: 0).animate(CurvedAnimation(
      parent: secondaryAnimation,
      curve: const Interval(0, 0.85, curve: Curves.easeIn),
    ));

    return SlideTransition(
      position: outSlide,
      child: FadeTransition(
        opacity: outFade,
        child: SlideTransition(
          position: inSlide,
          child: FadeTransition(opacity: inFade, child: child),
        ),
      ),
    );
  }
}
