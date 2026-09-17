import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Каркас формы-ЭКРАНА: шапка, прокрутка и главная кнопка, прибитая к низу.
///
/// Заведён после разбора 13.09.2026: формы бюджета, регулярного, валюты и
/// счёта жили нижними листами во весь экран — то есть экранами, которым мешала
/// ручка сверху и от которых уезжала кнопка сохранения.
class FormScreen extends StatelessWidget {
  const FormScreen({
    super.key,
    required this.title,
    required this.children,
    required this.action,
    this.onAction,
    this.danger,
    this.onDanger,
  });

  final String title;
  final List<Widget> children;

  /// Подпись главной кнопки. `onAction == null` гасит её: так форма говорит,
  /// чего ей не хватает, не пряча кнопку совсем.
  final String action;
  final VoidCallback? onAction;

  /// Опасное действие (удалить) — строкой под главной кнопкой.
  final String? danger;
  final VoidCallback? onDanger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(onPressed: onAction, child: Text(action)),
          ),
          if (danger != null)
            TextButton(
              onPressed: onDanger,
              child: Text(
                danger!,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontWeight: FontWeight.w600,
                  color: scheme.error,
                ),
              ),
            ),
        ]),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: children,
      ),
    );
  }
}
