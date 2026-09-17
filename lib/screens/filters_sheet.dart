import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/money.dart';
import '../logic/stats.dart';
import '../widgets/card_tile.dart';
import '../widgets/money_text.dart';

/// Отбор поверх отрезка. Лист занимает почти весь экран: списки счетов и
/// категорий длинные, и выбирать в щели высотой в треть экрана неудобно.
Future<Filter?> pickFilter(BuildContext context, Store store, Filter current) {
  return showModalBottomSheet<Filter>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _FiltersSheet(store: store, initial: current),
    ),
  );
}

class _FiltersSheet extends StatefulWidget {
  final Store store;
  final Filter initial;
  const _FiltersSheet({required this.store, required this.initial});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late final Set<TxKind> _kinds = {...widget.initial.kinds};
  late final Set<String> _accounts = {...widget.initial.accounts};
  late final Set<String> _categories = {...widget.initial.categories};

  /// Сам счёт по имени: у него лежат и свой значок, и своё оформление.
  Account? _storedOf(String name) {
    final at = widget.store.db.accounts.indexWhere((a) => a.name == name);
    return at >= 0 ? widget.store.db.accounts[at] : null;
  }

  /// Цвет кружка — тот же, что на экране счетов: свой цвет счёта, иначе цвет
  /// оформления карты. Подбор по имени оставляет голубую карту песочной.
  Color _colorOf(String name) {
    final stored = _storedOf(name);
    return stored?.color != null
        ? Color(stored!.color!)
        : designOf(stored, name).fill;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final accounts = balances(db);
    final categories = _categoryNames(db);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 8, 6),
            child: Row(
              children: [
                Text(
                  tr('filterTitle'),
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.4,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _empty
                      ? null
                      : () => setState(() {
                            _kinds.clear();
                            _accounts.clear();
                            _categories.clear();
                          }),
                  child: Text(tr('filterReset')),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 6, 14, 12),
            child: Wrap(
              spacing: 8,
              children: [
                _kindChip(TxKind.income, tr('income')),
                _kindChip(TxKind.expense, tr('spending')),
                _kindChip(TxKind.transfer, tr('transfer')),
              ],
            ),
          ),
          TabBar(
            tabs: [Tab(text: tr('accounts')), Tab(text: tr('categories'))],
            labelStyle: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  children: [
                    for (final a in accounts)
                      CheckboxListTile(
                        value: _accounts.contains(a.name),
                        onChanged: (v) => setState(() {
                          v == true ? _accounts.add(a.name) : _accounts.remove(a.name);
                        }),
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: LabelDot(
                          name: a.name,
                          icon: accountIcon(a.name, stored: _storedOf(a.name)?.icon),
                          // Цвет берётся из самого счёта: подбор по имени
                          // давал в отборе другой кружок, чем на экране
                          // счетов, и один счёт выглядел двумя.
                          color: _colorOf(a.name),
                          size: 38,
                        ),
                        title: Text(
                          a.name,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        subtitle: MoneyText(
                          a.mainAmount,
                          currency: a.mainCurrency,
                          size: 13,
                          weight: FontWeight.w500,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (accounts.isEmpty) _nothing(tr('filterNoAccounts')),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  children: [
                    for (final name in categories) ...[
                      CheckboxListTile(
                        value: _categories.contains(name),
                        onChanged: (v) => setState(() {
                          v == true ? _categories.add(name) : _categories.remove(name);
                        }),
                        controlAffinity: ListTileControlAffinity.trailing,
                        secondary: LabelDot(
                          name: name,
                          icon: categoryIcon(name),
                          size: 38,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      // Подкатегории отбираются наравне с категориями: до
                      // 13.09.2026 их не было ни в одном отборе.
                      for (final sub in widget.store.subcategoriesOf(name))
                        Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: CheckboxListTile(
                            value: _categories.contains(sub.name),
                            onChanged: (v) => setState(() {
                              v == true
                                  ? _categories.add(sub.name)
                                  : _categories.remove(sub.name);
                            }),
                            controlAffinity: ListTileControlAffinity.trailing,
                            dense: true,
                            secondary: LabelDot(
                              name: sub.name,
                              icon: categoryIcon(sub.name, stored: sub.icon),
                              color: sub.color == null ? null : Color(sub.color!),
                              size: 28,
                            ),
                            title: Text(
                              sub.name,
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 14,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (categories.isEmpty) _nothing(tr('filterNoCategories')),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    widget.initial.copyWith(
                      kinds: _kinds,
                      accounts: _accounts,
                      categories: _categories,
                    ),
                  ),
                  child: Text(tr('filterApply')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _empty => _kinds.isEmpty && _accounts.isEmpty && _categories.isEmpty;

  Widget _kindChip(TxKind kind, String name) {
    final on = _kinds.contains(kind);
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(name),
      selected: on,
      // Выбранное — инверсия, и слово обязано остаться читаемым: чёрные
      // буквы на чёрной заливке давали пустую пилюлю с одной галочкой
      // (14.09.2026). Галочка при этом не нужна вовсе — цвет уже сказал всё,
      // а она съедала место у слова.
      showCheckmark: false,
      labelStyle: TextStyle(
        fontFamily: AppTheme.bodyFont,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: on ? scheme.onSecondaryContainer : scheme.onSurface,
      ),
      onSelected: (v) => setState(() {
        v ? _kinds.add(kind) : _kinds.remove(kind);
      }),
    );
  }

  Widget _nothing(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 14.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}

/// Имена категорий: заведённые в реестре плюс те, что встречаются только в
/// операциях, — иначе по старым записям отобрать нельзя.
List<String> _categoryNames(Database db) {
  final names = <String>{
    ...db.categories.where((c) => c.parent == null).map((c) => c.name),
    ...db.transactions
        .map((t) => (t.category ?? '').trim())
        .where((n) => n.isNotEmpty),
  }.toList()
    ..sort();
  return names;
}
