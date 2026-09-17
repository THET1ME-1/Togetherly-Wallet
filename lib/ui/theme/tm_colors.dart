import 'package:flutter/widgets.dart';

/// Палитра Togetherly Money — ПЕЧАТЬ: ровно белый и ровно чёрный, нулевая
/// температура.
///
/// Решение человека от 13.09.2026, оно отменяет прежнюю систему «мята — общее,
/// лаванда — личное». Цвет остался ровно на одном: на деньгах. Приход зелёный,
/// расход красный, и только в сумме, знаке и графике — на кнопки, плашки и
/// значки цвет не заходит. Всё остальное держится на светлоте: белый лист,
/// серая карточка, чёрный текст, серая линия.
///
/// Общее и личное различаются теперь значком и подписью, а не оттенком: цвет
/// как граница приватности жил ровно до этой палитры.
abstract final class TmColors {
  // ── Светлая: печать по белому ──
  static const paper = Color(0xFFFFFFFF); // фон
  static const card = Color(0xFFF5F5F5); // карточка
  static const field = Color(0xFFEDEDED); // поле, неактивный чип, вторая ступень
  static const row = Color(0xFFF0F0F0); // строка внутри карточки
  static const ink = Color(0xFF000000); // текст и «чёрные» кнопки
  static const muted = Color(0xFF767676); // второстепенный текст
  static const line = Color(0xFFE0E0E0); // граница 1px
  static const lineSoft = Color(0xFFEBEBEB);

  // ── Тёмная: печать по графиту ──
  //
  // Ровно чёрный фон человек отверг сразу, как увидел: «слишком чёрный, мне
  // не нравится» (13.09.2026). Лист стал графитовым, всё остальное поднялось
  // на ступень — температура прежняя, нулевая, контраст прежний.
  static const paperDark = Color(0xFF121212);
  static const cardDark = Color(0xFF1C1C1C);
  static const fieldDark = Color(0xFF262626);
  static const rowDark = Color(0xFF212121);
  static const inkDark = Color(0xFFFFFFFF);
  static const mutedDark = Color(0xFF9A9A9A);
  static const lineDark = Color(0xFF323232);
  static const lineSoftDark = Color(0xFF282828);

  // ── Деньги: единственное место, где остаётся цвет ──
  static const income = Color(0xFF1E7A4D);
  static const expense = Color(0xFFB3271E);
  static const incomeDark = Color(0xFF5FBE8F);
  static const expenseDark = Color(0xFFE5786C);

  static Color inkAlpha(double a) => ink.withValues(alpha: a);
  static Color darkTextAlpha(double a) => inkDark.withValues(alpha: a);
}
