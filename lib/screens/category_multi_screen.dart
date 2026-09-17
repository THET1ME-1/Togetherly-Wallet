import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/icons.dart';
import '../widgets/money_text.dart';

/// Выбор НЕСКОЛЬКИХ категорий — экран с поиском и галочками.
///
/// Бюджет на машину — это бензин, мойка и страховка вместе: по отдельности их
/// никто не планирует, а три отдельных предела по 500 не отвечают на вопрос
/// «сколько у меня уходит на машину». Человек попросил это прямо: «нет учёта
/// с каких категорий его считать» (17.09.2026).
///
/// Своим экраном, а не листом: категорий бывает под сотню, и список с поиском
/// в нижнем листе живёт ровно до появления клавиатуры.
Future<List<String>?> pickCategories(
  BuildContext context, {
  required Store store,
  required List<String> chosen,
  bool expenseOnly = true,
}) => Navigator.of(context).push<List<String>>(
  MaterialPageRoute(
    builder: (_) => CategoryMultiScreen(
      store: store,
      chosen: chosen,
      expenseOnly: expenseOnly,
    ),
  ),
);

class CategoryMultiScreen extends StatefulWidget {
  const CategoryMultiScreen({
    super.key,
    required this.store,
    required this.chosen,
    this.expenseOnly = true,
  });

  final Store store;
  final List<String> chosen;
  final bool expenseOnly;

  @override
  State<CategoryMultiScreen> createState() => _CategoryMultiScreenState();
}

class _CategoryMultiScreenState extends State<CategoryMultiScreen> {
  final _query = TextEditingController();
  late final Set<String> _picked = {...widget.chosen};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Расходные категории верхнего уровня: заведённые плюс встреченные в
  /// записях. Доходную в предел не поставишь — лимит на зарплату это мечта.
  List<String> get _names {
    final db = widget.store.db;
    final kinds = <String, CatKind?>{
      for (final c in db.categories.where((c) => c.parent == null))
        c.name: c.kind,
    };
    final out = <String>{
      ...kinds.keys,
      ...db.transactions
          .where((t) => !widget.expenseOnly || t.kind == TxKind.expense)
          .map((t) => (t.category ?? '').trim())
          .where((n) => n.isNotEmpty),
    };
    if (widget.expenseOnly) {
      out.removeWhere((n) => kinds[n] == CatKind.income);
    }
    final list = out.toList()..sort();
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((n) => n.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = _names;

    return Scaffold(
      appBar: AppBar(title: Text(tr('budgetCategoriesTitle'))),
      body: Column(
        children: [
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
                      final on = _picked.contains(name);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: scheme.surfaceContainerHigh,
                          // Material принимает ЛИБО shape, ЛИБО borderRadius.
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: on
                                ? BorderSide(color: scheme.primary, width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => setState(() {
                              on ? _picked.remove(name) : _picked.add(name);
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  LabelDot(
                                    name: name,
                                    icon: categoryIcon(name),
                                    size: 38,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontFamily: AppTheme.bodyFont,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    on ? MynaCheckbox.on : MynaCheckbox.off,
                                    size: 22,
                                    color: on
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_picked.toList()..sort()),
            child: Text(trf('budgetCategoriesDone', ['${_picked.length}'])),
          ),
        ),
      ),
    );
  }
}

/// Значки галочки: набор MyNaUI, а не Material.
class MynaCheckbox {
  const MynaCheckbox._();
  static const on = Myna.checkCircle;
  static const off = Myna.circle;
}
