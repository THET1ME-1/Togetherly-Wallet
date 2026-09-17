import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';

/// «Перенести записи в облако?» — спрашивается один раз, сразу после входа.
///
/// Молча уносить нельзя: человек не давал согласия делиться тем, что писал
/// для себя. Молча не уносить тоже нельзя: он решит, что потерял всё.
Future<void> askAboutLocalRecords(BuildContext context, Store store) async {
  final count = store.pendingLocal;
  if (count <= 0) return;

  final yes = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr('importAskTitle'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 21,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            trf('importAskText', [count, _word(count)]),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(tr('importAskMove')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(tr('importAskKeep')),
            ),
          ),
        ]),
      );
    },
  );

  if (yes == true) {
    store.markAllForSync();
  } else {
    // Решение принято: второй раз не спрашиваем, иначе это назойливость.
    store.pendingLocal = 0;
    store.notify();
  }
}

String _word(int n) {
  return trn('records', n);
}
