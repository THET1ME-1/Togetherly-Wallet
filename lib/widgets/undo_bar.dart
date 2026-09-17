import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/haptics.dart';

/// Полоса отмены: встаёт над рядом вкладок после записи, правки или удаления и
/// возвращает всё, как было. Меньше пяти секунд — не успеть прочитать, больше —
/// начинает мешать экрану.
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
      _timer = Timer(const Duration(seconds: 5), () {
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
    final scheme = Theme.of(context).colorScheme;
    final undo = widget.store.undo;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: AppTheme.emphasizedDecelerate,
      child: undo == null
          ? const SizedBox.shrink()
          : Center(
              key: ValueKey(undo.label),
              child: Material(
                color: scheme.inverseSurface,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        undo.label,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 13.5,
                          color: scheme.onInverseSurface,
                        ),
                      ),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () {
                          // Человек успел передумать: отклик подтверждает, что
                          // запись вернулась, — сама полоса в этот миг уже
                          // уезжает, и читать её некогда.
                          Tap.done();
                          widget.store.undoLast();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.inversePrimary,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: Text(tr('undoCancel')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
