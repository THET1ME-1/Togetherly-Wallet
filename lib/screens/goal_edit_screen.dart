import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/money.dart';
import '../logic/reserve.dart';
import '../widgets/amount_field.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/entry_kit.dart';
import '../widgets/money_text.dart';
import '../widgets/form_screen.dart';
import '../widgets/settings_kit.dart';

/// Заведение и правка цели — ЭКРАН, как у бюджета и регулярного.
///
/// Листом это было до 17.09.2026: поля в столбик с плавающими подписями,
/// ползунок для месяцев подушки, кнопка валюты сбоку от суммы. Человек
/// потребовал один шаблон на три формы — «Бюджеты, цели, регулярные платежи
/// должны иметь общий шаблон добавления и редактирования», — и это он: сумма
/// главным числом, имя со значком и цветом, остальное строками настроек.
Future<Goal?> editGoal(
  BuildContext context, {
  required Store store,
  Goal? current,
  VoidCallback? onDelete,
}) => Navigator.of(context).push<Goal>(
  MaterialPageRoute(
    builder: (_) =>
        GoalEditScreen(store: store, current: current, onDelete: onDelete),
  ),
);

class GoalEditScreen extends StatefulWidget {
  const GoalEditScreen({
    super.key,
    required this.store,
    this.current,
    this.onDelete,
  });

  final Store store;
  final Goal? current;
  final VoidCallback? onDelete;

  @override
  State<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends State<GoalEditScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.current?.name ?? '',
  );
  late final TextEditingController _target = TextEditingController(
    text: (widget.current?.target ?? 0) > 0
        ? formatAmount(widget.current!.target)
        : '',
  );
  late String _currency =
      widget.current?.currency ?? widget.store.db.baseCurrency;
  late String? _deadline = widget.current?.deadline;
  late bool _reserve = widget.current?.isReserve ?? false;
  late int _months = widget.current?.months ?? 6;
  late String? _icon = widget.current?.icon;
  late Color? _color = widget.current?.color == null
      ? null
      : Color(widget.current!.color!);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  bool get _ready => _name.text.trim().isNotEmpty;

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = tr('goalNeedName'));
      return;
    }
    // Имя — ключ: по нему живёт счёт цели. Два «Отпуска» разошлись бы вкладами.
    if (widget.current == null &&
        widget.store.db.goals.any((g) => g.name == name)) {
      setState(() => _error = tr('goalExists'));
      return;
    }
    // parseAmount, а не double.tryParse: в поле лежит «45 000,00» с
    // разрядными пробелами, и обычный разбор отдал бы null, то есть ноль.
    final target = parseAmount(_target.text) ?? 0;
    Navigator.of(context).pop(
      Goal(
        name: name,
        target: target < 0 ? 0 : target,
        currency: _currency,
        deadline: (_deadline ?? '').isEmpty ? null : _deadline,
        kind: _reserve ? GoalKind.reserve : GoalKind.plain,
        months: _reserve ? _months : 0,
        icon: _icon,
        color: _color?.toARGB32(),
      ),
    );
  }

  /// Во сколько обойдётся выбранный срок по нынешним расходам.
  String _reserveHint() {
    final r = reserveOf(
      widget.store.db,
      Goal(
        name: _name.text.trim(),
        target: 0,
        currency: _currency,
        kind: GoalKind.reserve,
        months: _months,
      ),
    );
    if (r.unknown) return tr('goalReserveNoData');
    return trf('goalReserveByNow', [formatMoney(r.target, _currency)]) +
        trf('goalReservePerMonth', [formatMoney(r.perMonth, _currency)]);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('goalDeadline'),
      initial:
          DateTime.tryParse(_deadline ?? '') ??
          now.add(const Duration(days: 90)),
      firstYear: now.year - 1,
      lastYear: now.year + 10,
    );
    if (picked != null) {
      setState(() => _deadline = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _pickMonths() async {
    final picked = await showNumberWheel(
      context,
      title: tr('goalReserveMonths'),
      initial: _months,
      first: 1,
      last: 24,
      label: (n) => trn('months', n),
    );
    if (picked != null) setState(() => _months = picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FormScreen(
      title: widget.current == null ? tr('goalNew') : tr('goalOne'),
      action: tr('goalSave'),
      onAction: _ready ? _save : null,
      danger: widget.onDelete == null ? null : tr('goalRemove'),
      onDanger: widget.onDelete == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
      children: [
        // Подушка задаётся месяцами расходов, поэтому суммы у неё нет вовсе:
        // «шесть месяцев» остаётся верным и когда траты выросли.
        if (!_reserve) ...[
          AmountField(
            controller: _target,
            currency: _currency,
            hint: tr('goalAmountOptional'),
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
        ],

        SettingsSection(tr('goalWhatFor'), icon: Myna.flag),
        SettingsGroup([
          SettingsBlock(
            child: EntryIdentity(
              name: _name,
              icon: _icon,
              color: _color,
              hint: tr('goalWhatForHint'),
              // Имя заведённой цели закрыто: по нему живёт её счёт со всеми
              // вкладами, и переименование пришлось бы переносить вместе с
              // ними.
              enabled: widget.current == null,
              onChanged: (_) => setState(() => _error = null),
              onIcon: (v) => setState(() => _icon = v),
              onColor: (v) => setState(() => _color = v),
            ),
          ),
        ]),

        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(fontSize: 13.5, color: scheme.error)),
        ],

        SettingsSection(tr('goalWhen'), icon: Myna.calendar),
        SettingsGroup([
          SettingsRow(
            icon: Myna.shield,
            title: tr('goalIsReserve'),
            subtitle: tr('goalReserveHow'),
            trailing: Switch(
              value: _reserve,
              onChanged: (v) => setState(() => _reserve = v),
            ),
          ),
          if (_reserve)
            EntryNumberRow(
              icon: Myna.clockCircle,
              title: tr('goalReserveMonths'),
              value: trn('months', _months),
              onTap: _pickMonths,
            ),
          if (_reserve)
            SettingsBlock(
              child: Text(
                _reserveHint(),
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (!_reserve)
            EntryNumberRow(
              icon: Myna.calendarCheck,
              title: tr('goalDeadline'),
              value: _deadline == null
                  ? tr('goalNoDeadline')
                  : humanDate(_deadline),
              onTap: _pickDate,
            ),
        ]),
      ],
    );
  }
}
