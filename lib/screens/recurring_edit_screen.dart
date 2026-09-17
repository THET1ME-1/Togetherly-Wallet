import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../logic/period.dart';
import '../logic/recurring.dart';
import '../widgets/amount_field.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/entry_kit.dart';
import '../widgets/form_screen.dart';
import '../widgets/segmented.dart';
import '../widgets/settings_kit.dart';
import 'category_pick_screen.dart';

/// Заведение и правка регулярной записи — ЭКРАН.
///
/// Листом здесь стояли четыре ряда пилюль вида, ряд с одним-единственным
/// кошельком посреди пустой строки и двенадцать категорий стеной. Срок при
/// этом был один из трёх: месяц, квартал, год.
Future<Recurring?> editRecurring(
  BuildContext context, {
  required Store store,
  Recurring? current,
  VoidCallback? onDelete,
}) =>
    Navigator.of(context).push<Recurring>(MaterialPageRoute(
      builder: (_) => RecurringEditScreen(
        store: store,
        current: current,
        onDelete: onDelete,
      ),
    ));

class RecurringEditScreen extends StatefulWidget {
  const RecurringEditScreen({
    super.key,
    required this.store,
    this.current,
    this.onDelete,
  });

  final Store store;
  final Recurring? current;

  /// Удаление прямо из формы: долгое нажатие в списке человек не находит.
  final VoidCallback? onDelete;

  @override
  State<RecurringEditScreen> createState() => _RecurringEditScreenState();
}

class _RecurringEditScreenState extends State<RecurringEditScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.current?.name ?? '');
  late final TextEditingController _amount = TextEditingController(
      text: widget.current == null ? '' : formatAmount(widget.current!.amount));
  late RecurringKind _kind = widget.current?.kindOf ?? RecurringKind.expense;
  late RecurringEvery _every = widget.current?.every ?? RecurringEvery.monthly;
  late int _days = widget.current?.days ?? 10;
  late String? _account = widget.current?.account;
  late String? _category = widget.current?.category;
  late String? _sub;
  late String _target = widget.current?.target ?? '';
  late String _next = widget.current?.nextDate ?? _defaultNext();
  late bool _active = widget.current?.active ?? true;
  late String? _icon = widget.current?.icon;
  late Color? _color =
      widget.current?.color == null ? null : Color(widget.current!.color!);

  static const _kinds = RecurringKind.values;
  static const _everies = RecurringEvery.values;

  static String _defaultNext() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, now.day)
        .toIso8601String()
        .substring(0, 10);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<String> get _wallets =>
      balances(widget.store.db).map((a) => a.name).toList();

  List<String> get _targets => switch (_kind) {
        RecurringKind.goal => widget.store.db.goals.map((g) => g.name).toList(),
        RecurringKind.debt => widget.store.db.debts.map((d) => d.name).toList(),
        _ => const <String>[],
      };

  bool get _ready {
    if (_name.text.trim().isEmpty) return false;
    if ((parseAmount(_amount.text) ?? 0) <= 0) return false;
    if ((_account ?? _wallets.firstOrNull ?? '').isEmpty) return false;
    if ((_kind == RecurringKind.goal || _kind == RecurringKind.debt) &&
        _target.isEmpty) {
      return false;
    }
    return true;
  }

  /// Валюта регулярного. До 17.09.2026 её вовсе нельзя было выбрать: сумма
  /// бралась в валюте записи или базовой, и подписка в евро записывалась
  /// леями.
  late String _currency =
      widget.current?.currency ?? widget.store.db.baseCurrency;

  void _save() {
    if (!_ready) return;
    Navigator.of(context).pop(Recurring(
      id: widget.current?.id ?? 'rec-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      amount: parseAmount(_amount.text) ?? 0,
      currency: _currency,
      account: _account ?? _wallets.first,
      category: _kind == RecurringKind.expense ? _category : null,
      interval: recurringEveryName(_every),
      nextDate: _next,
      kind: recurringKindName(_kind),
      active: _active,
      target: _target,
      lastRun: widget.current?.lastRun ?? '',
      owner: widget.current?.owner,
      days: _every == RecurringEvery.custom ? _days : null,
      icon: _icon,
      color: _color?.toARGB32(),
    ));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('recurringNextTime'),
      initial: DateTime.tryParse(_next) ?? now,
      firstYear: now.year - 1,
      lastYear: now.year + 5,
    );
    if (picked != null) {
      setState(() => _next = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _pickDays() async {
    final picked = await showNumberWheel(
      context,
      title: tr('everyCustom'),
      initial: _days,
      first: 2,
      last: 365,
      label: (n) => trf('everyCustomDays', ['$n']),
    );
    if (picked != null) setState(() => _days = picked);
  }

  Future<void> _pickCategory() async {
    final picked = await pickCategory(
      context,
      store: widget.store,
      category: _category,
      subcategory: _sub,
    );
    if (picked == null) return;
    setState(() {
      _category = picked.category;
      _sub = picked.subcategory;
    });
  }

  String get _nextTitle {
    final at = DateTime.tryParse(_next);
    if (at == null) return _next;
    final head = '${at.day} ${monthOf(at.month)}';
    return at.year == DateTime.now().year ? head : '$head ${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wallets = _wallets;
    final targets = _targets;
    final account = _account ?? wallets.firstOrNull;

    return FormScreen(
      title: tr('recurringTitle'),
      action: tr('recurringSave'),
      onAction: _ready ? _save : null,
      danger: widget.onDelete == null ? null : tr('recurringRemove'),
      onDanger: widget.onDelete == null
          ? null
          : () {
              Navigator.of(context).pop();
              widget.onDelete!();
            },
      children: [
        AmountField(
          controller: _amount,
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

        SettingsSection(tr('recurringWhat'), icon: Myna.repeat),
        SettingsGroup([
          SettingsBlock(
            child: Segmented(
              titles: [for (final k in _kinds) recurringKindTitle(k)],
              index: _kinds.indexOf(_kind),
              onPick: (i) => setState(() {
                _kind = _kinds[i];
                _target = '';
              }),
            ),
          ),
          SettingsBlock(
            child: EntryIdentity(
              name: _name,
              icon: _icon,
              color: _color,
              hint: tr('recurringNameHint'),
              onChanged: (_) => setState(() {}),
              onIcon: (v) => setState(() => _icon = v),
              onColor: (v) => setState(() => _color = v),
            ),
          ),
        ]),

        SettingsSection(tr('recurringWallet'), icon: Myna.creditCard),
        SettingsGroup([
          if (wallets.isEmpty)
            SettingsBlock(
              child: Text(
                tr('recurringNeedWallet'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            SettingsBlock(
              child: Segmented(
                titles: wallets,
                index: wallets.indexOf(account ?? ''),
                onPick: (i) => setState(() => _account = wallets[i]),
              ),
            ),
          if (_kind == RecurringKind.expense)
            SettingsRow(
              icon: categoryIcon(_category ?? ''),
              iconBg: _category == null ? null : labelColorFor(_category!),
              iconFg:
                  _category == null ? null : inkOn(labelColorFor(_category!)),
              title: _category == null
                  ? tr('categoryPickNone')
                  : (_sub == null ? _category! : '$_category · $_sub'),
              subtitle: tr('recurringCategory'),
              trailing: const SettingsChevron(),
              onTap: _pickCategory,
            ),
          if (targets.isNotEmpty)
            SettingsBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kind == RecurringKind.goal
                        ? tr('recurringWhichGoal')
                        : tr('recurringWhichDebt'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Segmented(
                    titles: targets,
                    index: targets.indexOf(_target),
                    onPick: (i) => setState(() => _target = targets[i]),
                  ),
                ],
              ),
            ),
        ]),

        SettingsSection(tr('recurringHowOften'), icon: Myna.calendar),
        SettingsGroup([
          SettingsBlock(
            child: Segmented(
              titles: [for (final e in _everies) everyTitle(e)],
              index: _everies.indexOf(_every),
              onPick: (i) => setState(() => _every = _everies[i]),
            ),
          ),
          if (_every == RecurringEvery.custom)
            SettingsRow(
              icon: Myna.clockCircle,
              title: tr('everyCustom'),
              subtitle: trf('everyCustomDays', ['$_days']),
              trailing: const SettingsChevron(),
              onTap: _pickDays,
            ),
          SettingsRow(
            icon: Myna.calendarCheck,
            title: _every == RecurringEvery.once
                ? tr('recurringWhen')
                : tr('recurringNextTime'),
            trailing: Text(
              _nextTitle,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            onTap: _pickDate,
          ),
          SettingsRow(
            icon: _active ? Myna.play : Myna.pause,
            title: tr('recurringOn'),
            trailing: Switch(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ),
        ]),
      ],
    );
  }
}
