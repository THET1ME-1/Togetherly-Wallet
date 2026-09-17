import 'package:flutter/material.dart';

import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/debts.dart';
import '../logic/money.dart';
import '../widgets/amount_field.dart';
import '../widgets/form_screen.dart';
import '../widgets/money_text.dart';
import '../widgets/segmented.dart';
import '../widgets/settings_kit.dart';

/// Платёж по долгу: сколько и с какого кошелька.
typedef DebtPayment = ({String wallet, double amount});

Future<DebtPayment?> payDebt(
  BuildContext context, {
  required Store store,
  required DebtState state,
}) =>
    Navigator.of(context).push<DebtPayment>(MaterialPageRoute(
      builder: (_) => DebtPayScreen(store: store, state: state),
    ));

class DebtPayScreen extends StatefulWidget {
  const DebtPayScreen({super.key, required this.store, required this.state});

  final Store store;
  final DebtState state;

  @override
  State<DebtPayScreen> createState() => _DebtPayScreenState();
}

class _DebtPayScreenState extends State<DebtPayScreen> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.state.debt.minPayment > 0
          ? formatAmount(widget.state.debt.minPayment)
          : '');
  String? _wallet;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final wallets = balances(db).map((a) => a.name).toList();
    final wallet = _wallet ?? wallets.firstOrNull ?? '';
    final debt = widget.state.debt;
    final value = parseAmount(_amount.text) ?? 0;

    return FormScreen(
      title: trf('debtPayOn', [debt.name]),
      action: tr('debtPay'),
      onAction: value > 0 && wallet.isNotEmpty
          ? () => Navigator.of(context).pop((wallet: wallet, amount: value))
          : null,
      children: [
        AmountField(
          controller: _amount,
          currency: debt.currency,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            trf('debtLeft', [formatMoney(widget.state.left, debt.currency)]),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        SettingsSection(tr('debtFromWallet'), icon: Myna.creditCard),
        SettingsGroup([
          SettingsBlock(
            child: Segmented(
              titles: wallets,
              index: wallets.indexOf(wallet),
              onPick: (i) => setState(() => _wallet = wallets[i]),
            ),
          ),
        ]),
      ],
    );
  }
}
