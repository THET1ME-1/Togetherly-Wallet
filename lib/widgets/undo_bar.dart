import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';

/// Отмена последнего действия — маленькая капсула в углу.
///
/// Широкой плашкой во всю ширину она прожила до 17.09.2026 и была отвергнута:
/// «он меня бесит… найти для него место оригинальнее и намного меньше в
/// размерах». Плашка перекрывала сальдо на главной, спорила с круглой кнопкой
/// записи и вставала даже тогда, когда человек ничего не делал.
///
/// Теперь это капсула по ширине слова, прижатая к ЛЕВОМУ краю: справа живёт
/// кнопка записи, и место под ней занимать нельзя. Время жизни показывает
/// кольцо вокруг значка — видно, сколько осталось на «передумать», и полоса
/// не исчезает неожиданно.
const _life = Duration(seconds: 5);

class UndoBar extends StatefulWidget {
  final Store store;
  const UndoBar({super.key, required this.store});

  @override
  State<UndoBar> createState() => _UndoBarState();
}

class _UndoBarState extends State<UndoBar> {
  Timer? _timer;
  String? _shown;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_check);
  }

  void _check() {
    final label = widget.store.undo?.label;
    if (label == _shown) return;
    _shown = label;
    _timer?.cancel();
    if (label != null) {
      _timer = Timer(_life, () {
        if (mounted) widget.store.forgetUndo();
      });
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.store.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final undo = widget.store.undo;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: AppTheme.emphasizedDecelerate,
      switchOutCurve: Curves.easeIn,
      // Капсула выезжает снизу и подрастает, а не проявляется на месте:
      // движение снизу читается как «это про только что сделанное».
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.6), end: Offset.zero)
              .animate(anim),
          child: ScaleTransition(
            scale: Tween(begin: 0.88, end: 1.0).animate(anim),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: undo == null
          ? const SizedBox(key: ValueKey('none'), height: 0, width: 0)
          : Align(
              key: ValueKey(undo.label),
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: _Pill(
                  label: undo.label,
                  onTap: () {
                    // Человек успел передумать: отклик подтверждает, что
                    // запись вернулась, — сама капсула в этот миг уже уезжает,
                    // и читать её некогда.
                    Tap.done();
                    widget.store.undoLast();
                  },
                ),
              ),
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.inverseSurface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 7, 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Кольцо тает пять секунд: человек видит, сколько осталось на
              // «передумать», и капсула не пропадает без предупреждения.
              SizedBox(
                width: 26,
                height: 26,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: _life,
                  builder: (context, left, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: left,
                        strokeWidth: 2,
                        color: scheme.inversePrimary,
                        backgroundColor: scheme.onInverseSurface.withValues(alpha: 0.18),
                      ),
                      Icon(Myna.undo, size: 14, color: scheme.onInverseSurface),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 9),
              // Слово одно: что именно вернётся, человек помнит — он это
              // только что сделал. Ярлык действия ушёл в подсказку.
              Text(
                tr('undoCancel'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onInverseSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
