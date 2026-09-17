import 'package:flutter/material.dart';

/// Лёгкий «вдавливающий» отклик на нажатие (M3 press) — оборачивает кнопку и
/// слегка уменьшает её, пока палец на ней.
///
/// Использует [Listener] (а не GestureDetector), поэтому НЕ участвует в
/// «гонке жестов» и не перехватывает тап у вложенной кнопки — та продолжает
/// сама обрабатывать onPressed/onTap.
class PressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.96,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
