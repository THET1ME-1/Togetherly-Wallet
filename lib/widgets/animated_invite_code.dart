import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/invite.dart';

/// Код приглашения «дешифратором», как в Togetherly
/// (`AnimatedInviteCode` в `lib/widgets/connect_expressive.dart`).
///
/// Каждая позиция бежит сменой символов из алфавита кодов, пока код грузится;
/// код пришёл или сменился — позиции по очереди садятся на свои символы.
/// Ширина ячейки считается от доступной ширины: ряд не прыгает при смене
/// глифов и помещается на 320 dp. При выключенных анимациях код стоит сразу.
class AnimatedInviteCode extends StatefulWidget {
  const AnimatedInviteCode({
    super.key,
    required this.code,
    required this.loading,
    required this.style,
  });

  final String code;
  final bool loading;

  /// Стиль цифр: цвет и кегль берутся отсюда, кегль ужимается под ширину.
  final TextStyle style;

  @override
  State<AnimatedInviteCode> createState() => _AnimatedInviteCodeState();
}

class _AnimatedInviteCodeState extends State<AnimatedInviteCode> {
  static const int _len = 6;
  Timer? _timer;
  int _tick = 0;
  List<bool> _settled = List.filled(_len, false);

  /// Посадки по очереди. Держим их, чтобы отменить: `Future.delayed` не
  /// отменяется, и закрытый экран оставлял за собой живые таймеры.
  final List<Timer> _landings = [];

  /// Выключены анимации — пробега нет вовсе, код стоит сразу.
  bool _still = false;

  bool get _ready => widget.code.length >= _len;

  @override
  void initState() {
    super.initState();
    _startSpin();
    // Код уже есть — короткий пробег и посадка: вход на экран заметен.
    if (!widget.loading && _ready) _scheduleSettle(initialDelayMs: 360);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    if (_still) _stopAll();
  }

  void _stopAll() {
    _timer?.cancel();
    _timer = null;
    for (final t in _landings) {
      t.cancel();
    }
    _landings.clear();
  }

  void _startSpin() {
    if (_still) return;
    _timer ??= Timer.periodic(const Duration(milliseconds: 65), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  void _stopIfDone() {
    if (_settled.every((s) => s)) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _scheduleSettle({int initialDelayMs = 0}) {
    if (_still) return;
    for (var i = 0; i < _len; i++) {
      _landings.add(Timer(Duration(milliseconds: initialDelayMs + i * 95), () {
        if (!mounted) return;
        setState(() => _settled[i] = true);
        _stopIfDone();
      }));
    }
  }

  void _rescramble() {
    for (final t in _landings) {
      t.cancel();
    }
    _landings.clear();
    setState(() => _settled = List.filled(_len, false));
    _startSpin();
  }

  @override
  void didUpdateWidget(covariant AnimatedInviteCode old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) {
      _rescramble();
    } else if (!widget.loading &&
        _ready &&
        (old.loading || widget.code != old.code)) {
      _rescramble();
      _scheduleSettle();
    }
  }

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = _still;
    return Semantics(
      label: widget.code,
      excludeSemantics: true,
      child: LayoutBuilder(builder: (context, box) {
        final base = widget.style.fontSize ?? 36;
        final avail = box.maxWidth.isFinite ? box.maxWidth : base * _len;
        final cellW = avail / _len;
        final fs = math.min(base, cellW * 0.92);
        return Row(
          children: List.generate(_len, (i) {
            final settled = (still || _settled[i]) && _ready;
            final ch = settled
                ? widget.code[i]
                : Invite.alphabet[(_tick + i * 5) % Invite.alphabet.length];
            return SizedBox(
              width: cellW,
              child: AnimatedSwitcher(
                duration: still ? Duration.zero : const Duration(milliseconds: 70),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.7, end: 1.0).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  ch,
                  key: ValueKey('$i-$ch-$settled'),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: widget.style.copyWith(
                    fontSize: fs,
                    height: 1.0,
                    letterSpacing: 0,
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
