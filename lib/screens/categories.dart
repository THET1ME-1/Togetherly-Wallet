import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/ads.dart';
import '../widgets/ad_banner.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/icons.dart';
import '../logic/period.dart';
import '../logic/stats.dart';
import '../widgets/charts.dart';
import '../widgets/money_text.dart';
import '../widgets/period_bar.dart';
import '../widgets/reveal.dart';
import '../design/myna.dart';

/// Категории за отрезок: кольцо сверху, доли списком под ним. Доход и расход
/// переключаются, а не лежат рядом: смешивать их в одном кольце нельзя — доли
/// считаются от разных сумм.
class CategoriesScreen extends StatefulWidget {
  /// Реклама. Пусто — её нет: подписка, iPhone или тест.
  final Ads? ads;

  final Store store;
  final Period period;
  final ValueChanged<Period> onPeriod;
  final void Function(String category, bool income) onDrill;
  final VoidCallback onEditCategories;

  const CategoriesScreen({
    super.key,
    required this.store,
    this.ads,
    required this.period,
    required this.onPeriod,
    required this.onDrill,
    required this.onEditCategories,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  bool _income = false;
  SliceSort _sort = SliceSort.sum;
  final _shown = <Object>{};

  Future<void> _pickSort() async {
    final next = await showModalBottomSheet<SliceSort>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final s in SliceSort.values)
            ListTile(
              onTap: () => Navigator.of(context).pop(s),
              leading: Icon(
                s == _sort ? Myna.checkCircle : Myna.circle,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                sliceSortTitle(s),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 15,
                  fontWeight: s == _sort ? FontWeight.w700 : FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (next != null) setState(() => _sort = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final base = db.baseCurrency;
    final slices = byCategory(db, widget.period, income: _income, sort: _sort);
    final flow = cashflow(db, widget.period);
    final total = _income ? flow.income : flow.expense;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          actions: [
            IconButton(
              onPressed: widget.onEditCategories,
              icon: Icon(Myna.pencil),
              tooltip: tr('categoriesEditRow'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: PeriodBar(
            period: widget.period,
            onChange: widget.onPeriod,
            onSort: _pickSort,
            sorted: _sort != SliceSort.sum,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
            child: _SideToggle(
              income: _income,
              onChange: (v) => setState(() => _income = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
            child: SizedBox(
              height: 240,
              child: Donut(
                thickness: 26,
                parts: [
                  for (final s in slices) (share: s.share, color: labelColorFor(s.name)),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoneyText(
                      total,
                      currency: base,
                      size: 22,
                      weight: FontWeight.w800,
                      color: _income ? Money.up(context) : Money.down(context),
                      // Сумма стоит В КОЛЬЦЕ: место жёстко ограничено его
                      // диаметром, и миллиард ломался там пополам.
                      squeeze: true,
                    ),
                    SizedBox(height: 2),
                    Text(
                      _income ? tr('income') : tr('spending'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Баннер под кольцом и перед списком: кольцо человек читает первым,
        // а список листает следом.
        if (widget.ads != null)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            sliver: SliverToBoxAdapter(
              child: AdBanner(ads: widget.ads!, spot: AdSpot.categories),
            ),
          ),
        if (slices.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 30, 24, 60),
              child: Text(
                _income
                    ? tr('noIncomeInPeriod')
                    : tr('noSpendingInPeriod'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 120),
            sliver: SliverList.builder(
              itemCount: slices.length,
              itemBuilder: (context, i) {
                final s = slices[i];
                return Reveal(
                  group: _shown,
                  id: '${_income}_${s.name}',
                  delay: Duration(milliseconds: 24 * (i < 10 ? i : 10)),
                  child: _CategoryRow(
                    slice: s,
                    currency: base,
                    store: widget.store,
                    onTap: () => widget.onDrill(s.name, _income),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SideToggle extends StatelessWidget {
  final bool income;
  final ValueChanged<bool> onChange;
  const _SideToggle({required this.income, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(21),
      ),
      padding: EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(child: _Half(name: tr('spendings'), on: !income, onTap: () => onChange(false))),
          Expanded(child: _Half(name: tr('income'), on: income, onTap: () => onChange(true))),
        ],
      ),
    );
  }
}

class _Half extends StatelessWidget {
  final String name;
  final bool on;
  final VoidCallback onTap;
  const _Half({required this.name, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: AppTheme.emphasized,
        decoration: BoxDecoration(
          color: on ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          name,
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: on ? scheme.onPrimary : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategorySlice slice;
  final String currency;
  final Store store;
  final VoidCallback onTap;

  const _CategoryRow({
    required this.slice,
    required this.currency,
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = store.db.categories.indexWhere((c) => c.name == slice.name);
    final stored = at >= 0 ? store.db.categories[at] : null;
    final color = stored?.color != null ? Color(stored!.color!) : labelColorFor(slice.name);
    final percent = (slice.share * 100).round();

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            children: [
              LabelDot(
                name: slice.name,
                icon: categoryIcon(slice.name, stored: stored?.icon),
                color: color,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            slice.name,
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
                        const SizedBox(width: 8),
                        MoneyText(slice.sum, currency: currency, size: 14.5),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: slice.share),
                              duration: const Duration(milliseconds: 520),
                              curve: AppTheme.emphasizedDecelerate,
                              builder: (context, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 6,
                                backgroundColor: scheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation(color),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '$percent %',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: AppTheme.bodyFont,
                              fontSize: 12.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
