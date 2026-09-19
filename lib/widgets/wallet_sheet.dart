import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import 'money_text.dart';

/// Выбор кошелька листом снизу: куда вернуть деньги цели, куда перенести
/// операции удаляемого счёта. Отвечает именем выбранного счёта.
class WalletSheet extends StatelessWidget {
  const WalletSheet({super.key, required this.wallets, required this.title});

  final List<AccountBalance> wallets;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(w.name),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(children: [
                      LabelDot(
                        name: w.name,
                        icon: accountIcon(w.name),
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          w.name,
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
                      MoneyText(w.mainAmount,
                          currency: w.mainCurrency, size: 13.5, squeeze: true),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
