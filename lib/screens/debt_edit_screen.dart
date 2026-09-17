import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/money.dart';
import '../widgets/amount_field.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/entry_kit.dart';
import '../widgets/form_screen.dart';
import '../widgets/segmented.dart';
import '../widgets/settings_kit.dart';

/// Заведение и правка долга — ЭКРАН.
///
/// Листом здесь стояли подпись, четыре пилюли вида, четыре поля подряд и
/// ползунок с числом месяца. Ползунок для «пятого числа» — это попадание в
/// одно деление из двадцати восьми.
Future<Debt?> editDebt(
  BuildContext context, {
  required Store store,
  Debt? current,
  VoidCallback? onDelete,
}) =>
    Navigator.of(context).push<Debt>(MaterialPageRoute(
      builder: (_) => DebtEditScreen(
        store: store,
        current: current,
        onDelete: onDelete,
      ),
    ));

class DebtEditScreen extends StatefulWidget {
  const DebtEditScreen({
    super.key,
    required this.store,
    this.current,
    this.onDelete,
  });

  final Store store;
  final Debt? current;

  /// Удаление прямо из формы: долгое нажатие в списке человек не находит.
  final VoidCallback? onDelete;

  @override
  State<DebtEditScreen> createState() => _DebtEditScreenState();
}

class _DebtEditScreenState extends State<DebtEditScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.current?.name ?? '');
  late final TextEditingController _principal = TextEditingController(
      text: widget.current == null
          ? ''
          : formatAmount(widget.current!.principal));
  late final TextEditingController _rate = TextEditingController(
      text: (widget.current?.rate ?? 0) > 0 ? '${widget.current!.rate}' : '');
  late final TextEditingController _pay = TextEditingController(
      text: (widget.current?.minPayment ?? 0) > 0
          ? formatAmount(widget.current!.minPayment)
          : '');
  late DebtKind _kind = widget.current?.kind ?? DebtKind.loan;
  late int _dueDay = widget.current?.dueDay ?? 0;
  late String _currency =
      widget.current?.currency ?? widget.store.db.baseCurrency;
  String? _error;

  static const _kinds = DebtKind.values;

  @override
  void dispose() {
    _name.dispose();
    _principal.dispose();
    _rate.dispose();
    _pay.dispose();
    super.dispose();
  }

  bool get _ready =>
      _name.text.trim().isNotEmpty && (parseAmount(_principal.text) ?? 0) > 0;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (widget.current == null &&
        widget.store.db.debts.any((d) => d.name == name)) {
      setState(() => _error = tr('debtExists'));
      return;
    }
    final principal = parseAmount(_principal.text) ?? 0;
    if (principal <= 0) return;
    Navigator.of(context).pop(Debt(
      name: name,
      kind: _kind,
      principal: principal,
      rate: parseAmount(_rate.text) ?? 0,
      minPayment: parseAmount(_pay.text) ?? 0,
      currency: _currency,
      opened: widget.current?.opened,
      dueDay: _dueDay,
      owner: widget.current?.owner,
    ));
  }

  Future<void> _pickDueDay() async {
    // Барабан, а не ползунок: попасть в одно деление из двадцати восьми
    // пальцем нельзя, а промах меняет дату платежа.
    final picked = await showNumberWheel(
      context,
      title: tr('debtDueDay'),
      initial: _dueDay == 0 ? 1 : _dueDay,
      first: 1,
      last: 28,
      label: (n) => trf('debtDueDayOn', ['$n']),
    );
    if (picked != null) setState(() => _dueDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fixed = widget.current != null;

    return FormScreen(
      title: fixed ? widget.current!.name : tr('debtNew'),
      action: tr('debtSave'),
      onAction: _ready ? _save : null,
      danger: widget.onDelete == null ? null : tr('debtRemove'),
      onDanger: widget.onDelete == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
      children: [
        AmountField(
          controller: _principal,
          currency: _currency,
          onChanged: (_) => setState(() {}),
          onCurrency: () async {
            final picked = await askCurrency(
              context,
              store: widget.store,
              current: _currency,
            );
            if (picked != null) setState(() => _currency = picked);
          },
        ),
        const SizedBox(height: 6),

        SettingsSection(tr('debtWhat'), icon: Myna.bank),
        SettingsGroup([
          SettingsBlock(
            child: Segmented(
              titles: [for (final k in _kinds) debtKindTitle(k)],
              index: _kinds.indexOf(_kind),
              onPick: (i) => setState(() => _kind = _kinds[i]),
            ),
          ),
          SettingsBlock(
            // Имя долга — ключ: по нему живёт счёт с платежами, и менять его
            // у заведённого нельзя.
            child: fixed
                ? Text(
                    widget.current!.name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : SettingsInput(
                    controller: _name,
                    hint: tr('debtNameHint'),
                    onChanged: (_) => setState(() {}),
                  ),
          ),
        ]),

        SettingsSection(tr('debtTerms'), icon: Myna.percentage),
        SettingsGroup([
          SettingsBlock(
            child: Row(children: [
              Expanded(
                child: _Field(
                  label: tr('debtRateField'),
                  controller: _rate,
                  hint: '24,9',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Field(
                  label: tr('debtPaymentMonth'),
                  controller: _pay,
                  hint: '0',
                ),
              ),
            ]),
          ),
          SettingsRow(
            icon: Myna.calendarCheck,
            title: tr('debtDueDay'),
            subtitle: _dueDay == 0 ? tr('debtDueDayNone') : null,
            trailing: _dueDay == 0
                ? const SettingsChevron()
                : Text(
                    trf('debtDueDayOn', ['$_dueDay']),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
            onTap: _pickDueDay,
          ),
        ]),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13.5,
                color: scheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

/// Число с подписью над ним: ставка и платёж стоят парой в одном блоке.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppTheme.bodyFont,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 4),
      SettingsInput(
        controller: controller,
        hint: hint,
        capitalize: false,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
    ]);
  }
}
