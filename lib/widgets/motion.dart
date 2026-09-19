import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/app_theme.dart';

/// Словарь движения Wallet: длительности, кривые и три приёма, которыми
/// экран объясняет, что произошло.
///
/// До 19.09.2026 движение жило только на главной, в статистике и на
/// приветствии, а формы и списки менялись скачком: принятая карточка списания
/// пропадала, удалённая трата исчезала, новая строка сдвигала соседей рывком.
/// Человек не понимал, что сделала кнопка. Здесь приёмы, общие для всех экранов.
///
/// Правила: движение говорит о состоянии, а не украшает; 150–320 мс; выход
/// быстрее входа; без пружин и отскоков; при системном «меньше движения»
/// ([still]) всё стоит сразу.
abstract final class Motion {
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration state = Duration(milliseconds: 240);
  static const Duration layout = Duration(milliseconds: 320);

  /// Появление: быстрый старт, долгое торможение (M3 emphasized decelerate).
  static const Curve enter = AppTheme.emphasizedDecelerate;

  /// Перемещение по месту (M3 emphasized).
  static const Curve move = AppTheme.emphasized;

  /// Уход: разгон, чтобы уходящее не задерживало взгляд (M3 emphasized
  /// accelerate).
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Системное «меньше движения».
  static bool still(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// Новая строка в уже показанном списке: раздвигает соседей по высоте и
/// проявляется. Без раздвигания соседи прыгали вниз за один кадр.
class GrowIn extends StatefulWidget {
  const GrowIn({super.key, required this.child});

  final Widget child;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Motion.layout);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.still(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = CurvedAnimation(parent: _c, curve: Motion.move);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.3, 1, curve: Curves.easeOut));
    return SizeTransition(
      sizeFactor: size,
      axisAlignment: -1,
      child: FadeTransition(opacity: fade, child: widget.child),
    );
  }
}

/// Уходящая строка: гаснет и отъезжает вбок, потом список смыкается на её
/// месте. [onDone] зовётся, когда высота дошла до нуля.
///
/// Направление [slide] — куда уезжает: -1 влево (отказ), 1 вправо
/// (принято), 0 — гаснет на месте (удаление из ленты).
class Collapse extends StatefulWidget {
  const Collapse({
    super.key,
    required this.child,
    this.slide = 0,
    this.onDone,
  });

  final Widget child;
  final int slide;
  final VoidCallback? onDone;

  @override
  State<Collapse> createState() => _CollapseState();
}

class _CollapseState extends State<Collapse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (Motion.still(context)) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Первая половина — уход с глаз, вторая — смыкание списка. Одновременно
    // это читалось бы как «строка сплющилась», а не «строка ушла».
    final away = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Motion.exit));
    final shut = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Motion.move));
    return IgnorePointer(
      child: SizeTransition(
        sizeFactor: ReverseAnimation(shut),
        axisAlignment: -1,
        child: FadeTransition(
          opacity: ReverseAnimation(away),
          child: SlideTransition(
            position: Tween(begin: Offset.zero, end: Offset(0.35 * widget.slide, 0)).animate(away),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Встряска «не вышло»: поле коротко качается и успокаивается. Срабатывает на
/// каждое изменение [trigger]; ноль — не трясти.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger != 0 && !Motion.still(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        // Три качания с затуханием: амплитуда 8 точек тает к нулю.
        final dx = t == 0 || t == 1 ? 0.0 : math.sin(t * math.pi * 6) * 8 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}

/// Переход «сквозь» (M3 fade through) между экранами, у которых нет общей
/// геометрии: вкладки навигации, смена пары. Прежний гаснет за первую треть,
/// новый проявляется и чуть подрастает из 0,96 — взгляд понимает, что экран
/// сменился целиком, а не мигнул.
///
/// Переход идёт, когда меняется [id]. Ключом на самом виджете его задавать
/// нельзя: смена ключа пересоздала бы переключатель, и перехода не было бы.
class FadeThrough extends StatelessWidget {
  const FadeThrough({super.key, required this.id, required this.child});

  final Object id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final still = Motion.still(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 300),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(id);
        if (!incoming) {
          // Уходящий: анимация идёт 1 → 0, гаснет за первую треть времени.
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: const Interval(0.65, 1, curve: Curves.easeIn)),
            child: child,
          );
        }
        final shown = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Motion.enter));
        return FadeTransition(
          opacity: shown,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(shown),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(id), child: child),
    );
  }
}

/// Появление строки списка, один раз на [id] в пределах [group].
///
/// Первый показ экрана — подъём с проявлением ([grow] = false, каскад по
/// [delay]). Строка, появившаяся в УЖЕ показанном списке, — раздвигание
/// ([grow] = true): соседи уступают место плавно, а не прыгают за кадр.
/// Вернувшаяся при прокрутке строка стоит сразу: повторная анимация на
/// скролле роняла кадры (та же причина, что у [Reveal]).
class Entry extends StatefulWidget {
  const Entry({
    super.key,
    required this.group,
    required this.id,
    required this.child,
    this.grow = false,
    this.delay = Duration.zero,
  });

  final Set<Object> group;
  final Object id;
  final bool grow;
  final Duration delay;
  final Widget child;

  @override
  State<Entry> createState() => _EntryState();
}

class _EntryState extends State<Entry> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.grow ? Motion.layout : const Duration(milliseconds: 460),
  );
  late final bool _fresh = widget.group.add(widget.id);
  bool _started = false;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (!_fresh) {
      _c.value = 1;
      _started = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.still(context)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _wait = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.grow) {
      return SizeTransition(
        sizeFactor: CurvedAnimation(parent: _c, curve: Motion.move),
        axisAlignment: -1,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _c, curve: const Interval(0.3, 1, curve: Curves.easeOut)),
          child: widget.child,
        ),
      );
    }
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.10), end: Offset.zero)
            .animate(CurvedAnimation(parent: _c, curve: Motion.enter)),
        child: widget.child,
      ),
    );
  }
}

/// Обёртка, которая стоит на карточке всегда и по [leaving] проигрывает её
/// уход (как [Collapse]), не пересоздавая содержимое: выбранный в карточке
/// счёт и категория доживают до конца анимации, а не сбрасываются.
class Leaving extends StatefulWidget {
  const Leaving({
    super.key,
    required this.leaving,
    required this.child,
    this.slide = 0,
    this.onDone,
  });

  final bool leaving;
  final int slide;
  final VoidCallback? onDone;
  final Widget child;

  @override
  State<Leaving> createState() => _LeavingState();
}

class _LeavingState extends State<Leaving> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void initState() {
    super.initState();
    if (widget.leaving) WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  @override
  void didUpdateWidget(covariant Leaving old) {
    super.didUpdateWidget(old);
    if (widget.leaving && !old.leaving) _go();
  }

  void _go() {
    if (!mounted || _c.isAnimating || _c.isCompleted) return;
    if (Motion.still(context)) {
      _c.value = 1;
      widget.onDone?.call();
      return;
    }
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final away = CurvedAnimation(parent: _c, curve: const Interval(0, 0.55, curve: Motion.exit));
    final shut = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Motion.move));
    return IgnorePointer(
      ignoring: widget.leaving,
      child: SizeTransition(
        sizeFactor: ReverseAnimation(shut),
        axisAlignment: -1,
        child: FadeTransition(
          opacity: ReverseAnimation(away),
          child: SlideTransition(
            position: Tween(begin: Offset.zero, end: Offset(0.35 * widget.slide, 0)).animate(away),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
