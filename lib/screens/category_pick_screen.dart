import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import '../widgets/money_text.dart';

/// Что выбрано: категория и, если человек уточнил, подкатегория.
typedef CategoryChoice = ({String category, String? subcategory});

/// Выбор категории отдельным экраном с поиском.
///
/// До 13.09.2026 категории лежали в форме бюджета и регулярного стеной из
/// двадцати шести пилюль: экран уходил вниз на три пролистывания, а искать
/// глазами приходилось по алфавиту. Своим экраном и поиском это занимает одно
/// касание и одно слово.
Future<CategoryChoice?> pickCategory(
  BuildContext context, {
  required Store store,
  String? category,
  String? subcategory,

  /// Показывать только расходные категории: у бюджета доходных не бывает.
  bool expenseOnly = false,
}) =>
    Navigator.of(context).push<CategoryChoice>(MaterialPageRoute(
      builder: (_) => CategoryPickScreen(
        store: store,
        category: category,
        subcategory: subcategory,
        expenseOnly: expenseOnly,
      ),
    ));

class CategoryPickScreen extends StatefulWidget {
  const CategoryPickScreen({
    super.key,
    required this.store,
    this.category,
    this.subcategory,
    this.expenseOnly = false,
  });

  final Store store;
  final String? category;
  final String? subcategory;
  final bool expenseOnly;

  @override
  State<CategoryPickScreen> createState() => _CategoryPickScreenState();
}

class _CategoryPickScreenState extends State<CategoryPickScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Категории верхнего уровня: те, что заведены, плюс встреченные в записях.
  List<String> get _names {
    final db = widget.store.db;
    final kinds = <String, CatKind?>{
      for (final c in db.categories.where((c) => c.parent == null)) c.name: c.kind,
    };
    final out = <String>{
      ...kinds.keys,
      ...db.transactions
          .where((t) => !widget.expenseOnly || t.kind == TxKind.expense)
          .map((t) => (t.category ?? '').trim())
          .where((n) => n.isNotEmpty),
    };
    if (widget.expenseOnly) {
      // Доходную категорию в предел не поставишь: лимит на зарплату это не
      // бюджет, а мечта.
      out.removeWhere((n) => kinds[n] == CatKind.income);
    }
    final list = out.toList()..sort();
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((n) => n.toLowerCase().contains(q)).toList();
  }

  List<String> _subs(String parent) {
    final q = _query.text.trim().toLowerCase();
    return widget.store.db.categories
        .where((c) => c.parent == parent)
        .map((c) => c.name)
        .where((n) => q.isEmpty || n.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = _names;

    return Scaffold(
      appBar: AppBar(title: Text(tr('categoryPickTitle'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr('categoryPickSearch'),
              prefixIcon: const Icon(Myna.search, size: 20),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: names.isEmpty
              ? Center(
                  child: Text(
                    tr('categoryPickNothing'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: names.length,
                  itemBuilder: (context, i) {
                    final name = names[i];
                    final subs = _subs(name);
                    return _Row(
                      name: name,
                      subs: subs,
                      chosen: widget.category == name ? widget.subcategory ?? '' : null,
                      onPick: (sub) => Navigator.of(context)
                          .pop((category: name, subcategory: sub)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.subs,
    required this.chosen,
    required this.onPick,
  });

  final String name;
  final List<String> subs;

  /// Что выбрано в ЭТОЙ категории: пустая строка — сама категория, имя —
  /// подкатегория, null — выбрана другая.
  final String? chosen;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = chosen == '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Material(
          color: scheme.surfaceContainerHigh,
          // Material принимает ЛИБО shape, ЛИБО borderRadius — вместе валят
          // ассерт material.dart:209, и в релизе это молчит.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: on
                ? BorderSide(color: scheme.primary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: () => onPick(null),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                LabelDot(name: name, icon: categoryIcon(name), size: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (on) Icon(Myna.check, size: 20, color: scheme.onSurface),
              ]),
            ),
          ),
        ),
        if (subs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 2),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sub in subs)
                _SubChip(
                  name: sub,
                  on: chosen == sub,
                  onTap: () => onPick(sub),
                ),
            ]),
          ),
      ]),
    );
  }
}

class _SubChip extends StatelessWidget {
  const _SubChip({required this.name, required this.on, required this.onTap});

  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: on ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            LabelDot(name: name, icon: categoryIcon(name), size: 22),
            const SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
