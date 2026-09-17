import 'dart:async';

import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Появление дочернего виджета с проявлением и лёгким подъёмом (M3 emphasized).
///
/// Анимация проигрывается один раз при первом построении. Опциональная [delay]
/// даёт каскадный эффект, когда несколько [Reveal] идут подряд (список/сетка).
///
/// В прокручиваемых списках ([ListView.builder]/[SliverChildBuilderDelegate])
/// элементы пересоздаются каждый раз, когда возвращаются в зону видимости, из-за
/// чего анимация появления перезапускалась на каждый скролл и роняла кадры.
/// Чтобы этого не было, передайте [group] (набор уже показанных id, живущий в
/// state родительского экрана) и стабильный [id] элемента — тогда анимация
/// проиграется ТОЛЬКО при первом появлении, а при возврате на экран элемент
/// покажется сразу, без анимации.
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;

  /// Набор id уже показанных элементов (владелец — родительский экран).
  final Set<Object>? group;

  /// Стабильный идентификатор элемента в пределах [group].
  final Object? id;

  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 460),
    this.beginOffset = const Offset(0, 0.10),
    this.group,
    this.id,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: AppTheme.emphasizedDecelerate));

  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    // Элемент этой группы уже показывали (он вернулся в зону видимости при
    // прокрутке — списки пересоздают виджеты) → не анимируем заново: именно
    // повторная анимация на скролле давала дропы кадров. Set.add вернёт false,
    // если id уже был, — так одним вызовом и проверяем, и регистрируем.
    if (widget.group != null &&
        widget.id != null &&
        !widget.group!.add(widget.id!)) {
      _c.value = 1;
      return;
    }
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      // Таймер храним и отменяем в dispose, чтобы не «течь» при быстром
      // уходе с экрана (и не ронять виджет-тесты).
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
