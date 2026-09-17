import 'package:flutter/material.dart';

import '../design/accents.dart';
import '../design/app_theme.dart';
import '../l10n/strings.dart';

/// Спросить решение НИЖНИМ ЛИСТОМ, а не диалогом по центру.
///
/// Правило системы: попапов по центру в приложении нет. Диалог по центру мелкий,
/// кнопки в нём стоят в углу, и до них надо тянуться большим пальцем через
/// полэкрана; лист выезжает снизу, под рукой, и места в нём хватает объяснить,
/// что именно случится.
///
/// Нижний край всегда выше системной панели навигации (`useSafeArea` плюс
/// отбивка на `padding.bottom` внутри [SheetScaffold]): на телефонах с
/// кнопочной навигацией последняя строка иначе уезжает под панель.
Future<T?> showMoneySheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      builder: builder,
    );

/// Каркас листа: знак, заголовок, объяснение, содержимое и кнопки.
///
/// Кнопка решения стоит ВО ВСЮ ШИРИНУ и первой снизу — палец попадает в неё не
/// глядя. «Отмена» под ней текстом: отменяют чаще, чем подтверждают опасное, но
/// целиться в отмену не нужно — она же и по свайпу вниз, и по касанию мимо.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.action,
    required this.onAction,
    this.icon,
    this.text,
    this.tone,
    this.child,
    this.cancel,
    this.actionEnabled = true,
  });

  final String title;

  /// Слово на главной кнопке: «Распустить», «Удалить», «Выйти».
  final String action;

  /// Что делать по нажатию. Лист закрывает вызывающий: он знает, что вернуть.
  final VoidCallback? onAction;

  final IconData? icon;

  /// Объяснение последствий. Человек решает по нему, а не по заголовку.
  final String? text;

  /// Цвет решения. Опасное — коралл, обычное — мята из темы.
  final Color? tone;

  /// Всё, что нужно между текстом и кнопками: поле, список, переключатель.
  final Widget? child;

  /// Слово отказа. Пусто — берётся из словаря.
  final String? cancel;
  final bool actionEnabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = tone ?? scheme.primary;
    // Клавиатура открыта — отбиваем её; закрыта — системную панель.
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 4, 24, 20 + (insets > 0 ? 8 : safe)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Подложка знака — тот же цвет решения, разбавленный до
                    // фактуры: теней в системе нет, глубину даёт поверхность.
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 28, color: accent),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.5,
                  color: scheme.onSurface,
                ),
              ),
              if (text != null) ...[
                const SizedBox(height: 10),
                Text(
                  text!,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (child != null) ...[
                const SizedBox(height: 18),
                child!,
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: actionEnabled ? onAction : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: inkOn(accent),
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    disabledForegroundColor: scheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    action,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    cancel ?? tr('cancel'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Текст на заливке кнопки — один расчёт на всё приложение.
  ///
  /// Свой держался здесь с прежней палитры и возвращал тёмно-МЯТНЫЙ `#1E3C35`
  /// (цвет, которого в печатной системе нет) на любой светлой кнопке, а порог
  /// 0.6 отправлял белые буквы на коралловое «Удалить» — 2,4:1. Общий
  /// [inkOn] считает яркость по спецификации и выбирает между чистым чёрным и
  /// чистым белым.
}
