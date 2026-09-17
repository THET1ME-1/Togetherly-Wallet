import 'package:flutter/material.dart';

import '../data/store.dart';
import '../services/ads.dart';
import '../widgets/ad_banner.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../data/models.dart';
import '../logic/buckets.dart';
import '../logic/money.dart';
import '../logic/period.dart';
import '../logic/stats.dart';
import '../widgets/charts.dart';
import '../widgets/money_text.dart';
import '../widgets/period_bar.dart';
import '../widgets/reveal.dart';
import '../widgets/section_card.dart';
import '../design/myna.dart';

enum _Side { income, expense, net }

/// Статистика: одна кривая и числа под ней. Сравнение с прошлым отрезком стоит
/// последним — оно отвечает на «стало лучше или хуже», а не на «сколько», и
/// смотрят его реже.
class StatsScreen extends StatefulWidget {
  /// Реклама. Пусто — её нет: подписка, iPhone или тест.
  final Ads? ads;

  final Store store;
  final Period period;
  final ValueChanged<Period> onPeriod;

  /// Куда уходит нажатие по строке дохода или расхода: в ленту с этим
  /// разрезом. Без этого числа на экране — тупик: посмотреть, из чего они
  /// сложились, негде.
  final void Function(String? category, bool income)? onDrill;

  const StatsScreen({
    super.key,
    required this.store,
    this.ads,
    required this.period,
    required this.onPeriod,
    this.onDrill,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Side _side = _Side.expense;
  MoneyScope _scope = MoneyScope.all;

  @override
  Widget build(BuildContext context) {
    final db = widget.store.view;
    final base = db.baseCurrency;
    // «Сколько ушло из общего» и «сколько я потратил своего» — разные
    // вопросы, и один ответ на оба ничего не объясняет.
    final filter = Filter(scope: _scope, viewer: widget.store.viewer);
    final paired = db.pair.members.length > 1;
    final flow = cashflow(db, widget.period, filter: filter);
    final days = widget.period.days ?? _dataDays(db);

    final points = daily(
      db,
      widget.period,
      income: _side == _Side.income,
      net: _side == _Side.net,
      filter: filter,
    );
    final color = switch (_side) {
      _Side.income => Money.up(context),
      _Side.expense => Money.down(context),
      _Side.net => Theme.of(context).colorScheme.primary,
    };
    final totalOfSide = switch (_side) {
      _Side.income => flow.income,
      _Side.expense => flow.expense,
      _Side.net => flow.total,
    };

    return CustomScrollView(
      slivers: [
        // Ни заголовка, ни кнопок: остаётся ровно отступ под статусбар.
        const SliverToBoxAdapter(
          child: SafeArea(bottom: false, child: SizedBox(height: 8)),
        ),
        SliverToBoxAdapter(
          child: PeriodBar(period: widget.period, onChange: widget.onPeriod),
        ),
        if (paired)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: SegmentedButton<MoneyScope>(
                segments: [
                  ButtonSegment(value: MoneyScope.all, label: Text(tr('statsScopeAll'))),
                  ButtonSegment(value: MoneyScope.shared, label: Text(tr('statsScopeShared'))),
                  ButtonSegment(value: MoneyScope.mine, label: Text(tr('statsScopeMine'))),
                ],
                selected: {_scope},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _scope = v.first),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
          sliver: SliverList.list(
            children: [
              _SideSegments(side: _side, onChange: (s) => setState(() => _side = s)),
              const SizedBox(height: 16),
              Reveal(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: MoneyText(
                          totalOfSide,
                          currency: base,
                          size: 26,
                          weight: FontWeight.w800,
                          color: color,
                          squeeze: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DayChart(
                        points: points,
                        color: color,
                        signed: _side == _Side.net,
                        height: 168,
                        labelOf: (v) => formatMoney(v, base, decimals: 0),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Баннер после первого графика: на статистике сидят дольше, и
              // реклама здесь мешает меньше, чем в списках.
              if (widget.ads != null)
                AdBanner(ads: widget.ads!, spot: AdSpot.stats),
              Reveal(
                delay: Duration(milliseconds: 60),
                child: SectionCard(
                  title: tr('statsFlow'),
                  subtitle: widget.period.label,
                  child: _Pair(
                    rows: [
                      ('income', tr('statsIncome'), flow.income, Money.up(context)),
                      ('spending', tr('statsSpending'), flow.expense, Money.down(context)),
                      ('net', tr('statsNet'), flow.total, null),
                    ],
                    currency: base,
                    // «Итого» разворачивать некуда: доход и расход в одном
                    // списке не показать.
                    onTap: widget.onDrill == null
                        ? null
                        : (code) {
                            // «Итого» разворачивать некуда.
                            if (code == 'net') return;
                            widget.onDrill!(null, code == 'income');
                          },
                  ),
                ),
              ),
              SizedBox(height: 12),
              // Правило 50/30/20 живёт ЗДЕСЬ, а не на экране плана: оно
              // разбирает уже потраченное, то есть отвечает на вопрос «куда
              // ушёл доход», а не «сколько я собираюсь потратить». На экране
              // с заголовком «План на месяц» оно врало названием — человек
              // читал его как план, которого сам не заводил (14.09.2026).
              Reveal(
                delay: Duration(milliseconds: 90),
                child: SectionCard(
                  title: tr('planWhereIncomeGoes'),
                  subtitle: trf('planRule', [_ruleLine(widget.store.view.rules)]),
                  child: _RuleBars(
                    split: bucketsOf(widget.store.view, widget.period, filter: filter),
                    rules: widget.store.view.rules,
                    currency: base,
                  ),
                ),
              ),
              SizedBox(height: 12),
              Reveal(
                delay: Duration(milliseconds: 120),
                child: SectionCard(
                  title: tr('statsAverage'),
                  subtitle: days == null ? tr('statsNoData') : trf('statsForDays', [days, _daysWord(days)]),
                  child: days == null
                      ? CardEmpty(icon: Myna.chartSpline, text: tr('statsNothingToCount'))
                      : _Averages(
                          income: Averages.of(flow.income, days),
                          expense: Averages.of(flow.expense, days),
                          currency: base,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: _CompareCard(store: widget.store, period: widget.period, filter: filter),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Для «всего времени» отрезок задан данными, а не календарём.
  int? _dataDays(db) {
    final dates = widget.store.view.transactions.map((t) => t.date).toList()..sort();
    if (dates.isEmpty) return null;
    return DateTime.parse(dates.last).difference(DateTime.parse(dates.first)).inDays + 1;
  }
}

String _daysWord(int n) => trn('days', n);

String _ruleLine(Rules r) =>
    '${(r.needsBp / 100).round()}/${(r.wantsBp / 100).round()}/${(r.savingsBp / 100).round()}';

class _SideSegments extends StatelessWidget {
  final _Side side;
  final ValueChanged<_Side> onChange;
  const _SideSegments({required this.side, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (_Side.income, tr('statsIncome')),
      (_Side.expense, tr('statsSpending')),
      (_Side.net, tr('statsNet')),
    ];
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(21),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final (value, name) in items)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChange(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: AppTheme.emphasized,
                  decoration: BoxDecoration(
                    color: side == value ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: side == value ? scheme.onPrimary : scheme.onSurfaceVariant,
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

class _Pair extends StatelessWidget {
  /// Строка потока: устойчивый код стороны, подпись, сумма, цвет. Код нужен и
  /// ключу проверки, и обработчику нажатия — по переведённому слову их не
  /// различить, оно меняется вместе с языком.
  final List<(String, String, double, Color?)> rows;
  final String currency;

  /// Куда ведёт строка. Пусто — строка итога: разворачивать её некуда, доход
  /// и расход в одном списке не показать.
  final void Function(String code)? onTap;

  const _Pair({required this.rows, required this.currency, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (code, name, value, color) in rows)
          _Tappable(
            // Ключ нужен проверке: слово «Расходы» на экране встречается
            // трижды, и отличить строку потока от переключателя стороны
            // иначе нечем. Ключ — код стороны, а не подпись: подпись зависит
            // от языка.
            key: ValueKey('flow-$code'),
            onTap: onTap == null ? null : () => onTap!(code),
            child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                MoneyText(
                  value,
                  currency: currency,
                  size: 15,
                  color: color,
                  colored: color == null,
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(Myna.chevronRight, size: 18,
                      color: scheme.onSurfaceVariant),
                ],
              ],
            ),
            ),
          ),
      ],
    );
  }
}

/// Обёртка нажатия: без обработчика строка остаётся обычным текстом, и палец
/// по ней не «щёлкает» вхолостую.
class _Tappable extends StatelessWidget {
  const _Tappable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class _Averages extends StatelessWidget {
  final Averages income;
  final Averages expense;
  final String currency;

  const _Averages({required this.income, required this.expense, required this.currency});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      (tr('statsDay'), income.perDay, expense.perDay),
      (tr('statsWeek'), income.perWeek, expense.perWeek),
      (tr('statsMonth'), income.perMonth, expense.perMonth),
    ];
    return Column(
      children: [
        for (final (name, plus, minus) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MoneyText(plus,
                        currency: currency,
                        size: 14,
                        color: Money.up(context),
                        squeeze: true),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MoneyText(minus,
                        currency: currency,
                        size: 14,
                        color: Money.down(context),
                        squeeze: true),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Сравнение с таким же отрезком назад. Проценты считаются от прошлого; когда
/// в прошлом было ноль, процента нет — делить не на что, и «+∞ %» ничего не
/// объясняет.
class _CompareCard extends StatelessWidget {
  final Store store;
  final Period period;

  /// Тот же разрез, что и выше на экране: сравнивать общее с общим, а не с
  /// суммой всего подряд.
  final Filter filter;
  const _CompareCard({required this.store, required this.period, required this.filter});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!period.shiftable) {
      return SectionCard(
        title: tr('statsCompare'),
        child: CardEmpty(
          icon: Myna.arrowLeftRight,
          text: tr('statsCompareNone'),
        ),
      );
    }
    final db = store.view;
    final base = db.baseCurrency;
    final now = cashflow(db, period, filter: filter);
    final was = cashflow(db, period.previous, filter: filter);

    return SectionCard(
      title: tr('statsCompare'),
      subtitle: trf('statsCompareWith', [period.previous.label]),
      child: Column(
        children: [
          _CompareRow(name: tr('statsIncome'), now: now.income, was: was.income, currency: base, moreIsBetter: true),
          SizedBox(height: 12),
          _CompareRow(name: tr('statsSpending'), now: now.expense, was: was.expense, currency: base, moreIsBetter: false),
          SizedBox(height: 12),
          _CompareRow(name: tr('statsNet'), now: now.total, was: was.total, currency: base, moreIsBetter: true),
          if (was.isEmpty) ...[
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr('statsPrevEmpty'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String name;
  final double now;
  final double was;
  final String currency;
  final bool moreIsBetter;

  const _CompareRow({
    required this.name,
    required this.now,
    required this.was,
    required this.currency,
    required this.moreIsBetter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delta = now - was;
    final percent = was.abs() < 0.005 ? null : (delta / was.abs()) * 100;
    final good = moreIsBetter ? delta >= 0 : delta <= 0;
    final tint = delta.abs() < 0.005
        ? scheme.onSurfaceVariant
        : (good ? Money.up(context) : Money.down(context));

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            name,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: MoneyText(now, currency: currency, size: 14.5),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 74,
          child: Text(
            percent == null
                ? '—'
                : '${percent >= 0 ? '+' : '−'}${percent.abs().round()} %',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ),
      ],
    );
  }
}

class _RuleBars extends StatelessWidget {
  const _RuleBars({required this.split, required this.rules, required this.currency});

  final BucketSplit split;
  final Rules rules;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (split.income <= 0.005) {
      return CardEmpty(
        icon: Myna.chartPieOne,
        text: tr('planNoIncome'),
      );
    }
    final targets = targetsOf(rules, split.income);

    return Column(children: [
      _Bar(
        title: tr('bucketNeeds'),
        actual: split.needs,
        target: targets.needs,
        currency: currency,
        color: labelColorFor(tr('bucketNeeds')),
      ),
      SizedBox(height: 12),
      _Bar(
        title: tr('bucketWants'),
        actual: split.wants,
        target: targets.wants,
        currency: currency,
        color: labelColorFor(tr('bucketWants')),
      ),
      SizedBox(height: 12),
      _Bar(
        title: tr('bucketSavings'),
        actual: split.savings,
        target: targets.savings,
        currency: currency,
        color: labelColorFor(tr('planSavings')),
      ),
      if (split.unknown > 0.005) ...[
        SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            trf('planUnmarked', [formatMoney(split.unknown, currency)]) +
            tr('planUnmarkedTail'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              height: 1.35,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ]);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.title,
    required this.actual,
    required this.target,
    required this.currency,
    required this.color,
  });

  final String title;
  final double actual;
  final double target;
  final String currency;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = target <= 0 ? (actual > 0 ? 1.0 : 0.0) : (actual / target).clamp(0.0, 1.0);
    final over = actual > target + 0.005;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '${formatMoney(actual, currency)} ${trf('goalOfTarget', [formatAmount(target)])}',
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            color: over ? Money.down(context) : scheme.onSurfaceVariant,
          ),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: share,
          minHeight: 7,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(over ? Money.down(context) : color),
        ),
      ),
    ]);
  }
}
