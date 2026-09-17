import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import 'app_sheet.dart';
import 'money_text.dart';

/// С каких счетов считать — нижний лист с галочками.
///
/// Листом, а не экраном: счетов у человека три-пять, и поиск им не нужен;
/// правило «список длиннее десятка — с поиском» сюда не достаёт. Пусто значит
/// «со всех»: у бюджета на еду нет причины отличать карту от наличных, а у
/// бюджета на командировки — есть.
Future<List<String>?> pickAccounts(
  BuildContext context, {
  required Store store,
  required List<String> chosen,
}) => showMoneySheet<List<String>>(
  context,
  builder: (_) => _AccountsSheet(store: store, chosen: chosen),
);

class _AccountsSheet extends StatefulWidget {
  const _AccountsSheet({required this.store, required this.chosen});

  final Store store;
  final List<String> chosen;

  @override
  State<_AccountsSheet> createState() => _AccountsSheetState();
}

class _AccountsSheetState extends State<_AccountsSheet> {
  late final Set<String> _picked = {...widget.chosen};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accounts = widget.store.db.accounts;

    return SheetScaffold(
      icon: Myna.creditCard,
      title: tr('budgetAccounts'),
      text: tr('budgetAccountsNote'),
      action: tr('budgetSave'),
      onAction: () => Navigator.of(context).pop(_picked.toList()..sort()),
      child: Column(
        children: [
          for (final a in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: _picked.contains(a.name)
                      ? BorderSide(color: scheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() {
                    _picked.contains(a.name)
                        ? _picked.remove(a.name)
                        : _picked.add(a.name);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        LabelDot(
                          name: a.name,
                          icon: accountIcon(a.name, stored: a.icon),
                          size: 34,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          _picked.contains(a.name)
                              ? Myna.checkCircle
                              : Myna.circle,
                          size: 21,
                          color: _picked.contains(a.name)
                              ? scheme.primary
                              : scheme.outlineVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
