import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/accents.dart';
import '../design/app_theme.dart';
import '../logic/debts.dart';
import '../logic/envelope.dart';
import '../logic/icons.dart';
import '../logic/goals.dart';
import '../logic/plan.dart';
import '../logic/recurring.dart';
import '../logic/reserve.dart';
import '../logic/subscriptions.dart';
import '../logic/review.dart';
import '../logic/money.dart';
import '../logic/period.dart';
import '../widgets/forecast_card.dart';
import '../services/plus.dart';
import '../logic/forecast.dart';
import '../logic/split.dart';
import '../logic/stats.dart';
import '../widgets/charts.dart';
import '../widgets/date_wheel_sheet.dart';
import '../widgets/block_period.dart';
import '../widgets/app_sheet.dart';
import '../widgets/card_tile.dart';
import '../services/ads.dart';
import '../widgets/ad_banner.dart';
import '../widgets/flow_scale.dart';
import '../widgets/goal_vessel.dart';
import '../widgets/money_text.dart';
import '../widgets/quarters.dart';
import '../services/session.dart';
import '../widgets/reveal.dart';
import '../widgets/space_switch.dart';
import '../widgets/section_card.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';
import '../widgets/member_badge.dart';

/// Главная: сводка карточками. Порядок карточек — по тому, на что смотрят
/// каждый день: сначала сколько всего денег, потом откуда и куда они ушли.
class HomeScreen extends StatelessWidget {
  final Store store;

  /// Реклама. Пусто — её нет вовсе: так главная строится и в тестах, и у
  /// подписчика, и на iPhone, где РСЯ мы не подключаем.
  final Ads? ads;

  /// Подписка: прогноз конца месяца платный, и карточка знает об этом сама.
  final PlusService? plus;
  final Period period;
  final ValueChanged<Period> onPeriod;
  final VoidCallback onAccounts;
  final VoidCallback onBudgets;
  final VoidCallback onGoals;
  final VoidCallback onPlan;
  final VoidCallback onDebts;
  final VoidCallback onChat;
  final VoidCallback onSettings;

  /// Разбор банковских уведомлений. Кнопки на главной нет, пока нечего
  /// подтверждать: пустая строка «уведомлений нет» занимала бы место у денег.
  final VoidCallback? onNotices;

  /// Учётка: нужна переключателю пар в шапке. Без неё чипа просто нет.
  final Session? session;

  /// Круг синхронизации после смены пары: вторая пара могла обновиться, пока
  /// человек смотрел на первую.
  final VoidCallback? onSpaceSwitched;
  /// Переход в ленту с готовым отбором. Третьим приезжает отрезок блока:
  /// у каждой карточки он свой, и лента должна показать именно его.
  final void Function(String? category, bool income, [Period? period]) onDrill;

  const HomeScreen({
    super.key,
    required this.store,
    this.ads,
    this.plus,
    required this.period,
    required this.onPeriod,
    required this.onAccounts,
    required this.onBudgets,
    required this.onGoals,
    required this.onPlan,
    required this.onDebts,
    required this.onChat,
    required this.onSettings,
    required this.onDrill,
    this.onNotices,
    this.session,
    this.onSpaceSwitched,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final base = db.baseCurrency;
    final accounts = balances(db);
    // У каждого блока свой отрезок: на главной человек смотрит поток за месяц,
    // а категории, бывает, за неделю.
    final flowPeriod = store.periodOf('flow', fallback: period);
    final flow = cashflow(db, flowPeriod);

    return CustomScrollView(
      slivers: [
        // Заголовка нет: раздел назван в нижней навигации, а большая шапка
        // Material забирала треть экрана под слово «Главная». Шапка осталась
        // ради кнопок и отступа под статусбар.
        SliverAppBar(
          pinned: true,
          // Слева — СВОЯ аватарка: видно, под каким аккаунтом сидишь, и это
          // же вход в профиль. Левый угол шапки до этого пустовал, а справа
          // уже стоят чат и настройки — «я, мы, приложение».
          // Отступ слева такой же, как справа у настроек: иначе шапка
          // выглядит съехавшей (14.09.2026).
          leadingWidth: 54,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _Me(store: store, session: session, onTap: onSettings),
            ),
          ),
          // Переключатель пары стоит в шапке, а не в настройках: в него ходят
          // каждый день, если пар несколько.
          titleSpacing: 0,
          title: SpaceSwitch(
            store: store,
            session: session,
            onSwitched: onSpaceSwitched,
          ),
          // Пара стоит СРАЗУ за аватаром, а не по центру: между ними зияла
          // пустая треть шапки.
          centerTitle: false,
          actions: [
            // Чат — единственная цветная кнопка в приложении: человек просил
            // выделить её, чтобы бросалась в глаза (14.09.2026). Цвет взят
            // лавандовый, чтобы не спорить с зелёным приходом и красным
            // расходом.
            _RoundAction(
              icon: Myna.chatDots,
              tooltip: tr('chat'),
              onTap: onChat,
              fill: const Color(0xFFA99BC7),
              ink: const Color(0xFF2A2540),
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: Myna.cog,
              tooltip: tr('settings'),
              onTap: onSettings,
            ),
            const SizedBox(width: 12),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 120),
          sliver: SliverList.list(
            children: [
              Reveal(child: _BalanceCard(store: store, period: period, onPeriod: onPeriod)),
              const SizedBox(height: 12),
              // Порядок трёх первых блоков задан человеком и менять его
              // нельзя: баланс, счета, поток. Всё, что приложение хочет
              // сказать само — списания, напоминания, прогноз, — живёт ниже:
              // человек открывает главную ради своих денег, а не ради наших
              // карточек (17.09.2026).
              Reveal(
                delay: const Duration(milliseconds: 10),
                child: SectionCard(
                  title: tr('accounts'),
                  onTap: onAccounts,
                  child: accounts.isEmpty
                      ? CardEmpty(
                          icon: Myna.pocket,
                          text: tr('noAccounts'),
                        )
                      : _AccountsGrid(
                          store: store,
                          accounts: accounts,
                          onGoals: onGoals,
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Reveal(
                delay: const Duration(milliseconds: 20),
                child: SectionCard(
                  title: tr('cashFlow'),
                  trailing: BlockPeriodButton(
                    store: store,
                    block: 'flow',
                    fallback: period,
                  ),
                  child: FlowScale(
                    income: flow.income,
                    expense: flow.expense,
                    total: flow.total,
                    currency: base,
                    onDrill: (income) => onDrill(null, income),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Баннер стоит ПОСЛЕ баланса и перед счетами: первый экран
              // человек открывает ради суммы, и реклама над ней читалась бы
              // как «приложение продаёт меня раньше, чем показывает деньги»
              // (раскладка человека 16.09.2026). Подписчику баннера нет.
              if (ads != null) AdBanner(ads: ads!, spot: AdSpot.homeTop),
              // Списания, прочитанные из уведомлений банка: одно касание — и
              // трата в приложении. Стоит выше остального, потому что это
              // единственное место, где приложение ждёт ответа.
              if (store.pendingNotices.isNotEmpty && onNotices != null) ...[
                Reveal(
                  delay: const Duration(milliseconds: 10),
                  child: _NoticesCard(
                    count: store.pendingNotices.length,
                    onOpen: onNotices!,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Что спишется на днях: забытый платёж стоит пени, а приложение
              // о нём знало. Стоит выше отчётов — это дело, а не сводка.
              if (dueSoon(db).isNotEmpty) ...[
                Reveal(
                  delay: const Duration(milliseconds: 14),
                  child: _SoonCard(
                    items: dueSoon(db),
                    currency: base,
                    onOpen: onPlan,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Прогноз конца месяца: сколько останется такими темпами и
              // где деньги кончатся раньше срока. Стоит рядом со «Скоро
              // спишется» — оба блока про будущее, и читаются вместе.
              Builder(builder: (context) {
                // Без подписки карточки нет вовсе. Закрытое число под
                // точками человек назвал некрасивым, и он прав: заглушка на
                // главной занимает место и не отвечает ни на один вопрос.
                // Про сам прогноз человек узнаёт на витрине (17.09.2026).
                if (!(plus?.active ?? true)) return const SizedBox.shrink();
                final f = forecastOf(db);
                if (!f.ready) return const SizedBox.shrink();
                return Column(children: [
                  Reveal(
                    delay: const Duration(milliseconds: 15),
                    child: ForecastCard(forecast: f, currency: base),
                  ),
                  const SizedBox(height: 12),
                ]);
              }),
              // Забытые подписки: одна и та же сумма уходит третий месяц, а в
              // регулярных её нет. Приём из Rocket Money.
              if (subscriptionsOf(db).isNotEmpty) ...[
                Reveal(
                  delay: const Duration(milliseconds: 16),
                  child: _SubsCard(
                    items: subscriptionsOf(db),
                    onOpen: onPlan,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Напоминание о пересмотре: цифры меняются быстрее решений, и
              // раз в месяц или квартал пара обязана свериться.
              if (reviewDue(db.rules)) ...[
                Reveal(
                  delay: const Duration(milliseconds: 20),
                  child: _ReviewCard(store: store, onOpen: onPlan),
                ),
                const SizedBox(height: 12),
              ],
              // Сальдо долга одной строкой: у пары это первый вопрос к
              // приложению, и таблица тут не нужна.
              if (_settlementLine(store) != null) ...[
                Reveal(
                  delay: const Duration(milliseconds: 40),
                  child: _DebtCard(text: _settlementLine(store)!, store: store),
                ),
                const SizedBox(height: 12),
              ],
              Reveal(
                delay: Duration(milliseconds: 150),
                child: SectionCard(
                  title: tr('monthPlan'),
                  onTap: onPlan,
                  child: _PlanRows(store: store),
                ),
              ),
              const SizedBox(height: 12),
              // Второй баннер — через пару блоков, у кварталов: подряд стоящие
              // баннеры превращают экран в ленту рекламы.
              if (ads != null) AdBanner(ads: ads!, spot: AdSpot.homeLower),
              Reveal(
                delay: const Duration(milliseconds: 180),
                child: _QuartersCard(
                  store: store,
                  onDrill: onDrill,
                  fallback: period,
                ),
              ),
              const SizedBox(height: 12),
              Reveal(
                delay: Duration(milliseconds: 240),
                child: SectionCard(
                  title: tr('budgets'),
                  onTap: onBudgets,
                  trailing: BlockPeriodButton(
                    store: store,
                    block: 'budgets',
                    fallback: period,
                  ),
                  child: db.budgets.isEmpty
                      ? CardEmpty(
                          icon: Myna.box,
                          text: tr('noBudgets'),
                        )
                      : _BudgetRows(
                          store: store,
                          period: store.periodOf('budgets', fallback: period),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Reveal(
                delay: Duration(milliseconds: 300),
                child: SectionCard(
                  title: tr('goals'),
                  onTap: onGoals,
                  child: allGoals(db).isEmpty
                      ? CardEmpty(
                          icon: Myna.flag,
                          text: tr('noGoals'),
                        )
                      : _GoalRows(store: store),
                ),
              ),
              const SizedBox(height: 12),
              if (db.debts.isNotEmpty) ...[
                Reveal(
                  delay: Duration(milliseconds: 330),
                  child: SectionCard(
                    title: tr('debts'),
                    onTap: onDebts,
                    child: _DebtRows(store: store),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Разговор о деньгах: назначенная встреча, а не «когда-нибудь».
              // Приём Zeta — иначе он не случается никогда.
              //
              // Стоит ПОСЛЕ денег и строкой, а не карточкой вторым блоком
              // экрана: ненастроенное напоминание занимало лучшее место, выше
              // счетов и потока (16.09.2026).
              if (_paired(store)) ...[
                Reveal(
                  delay: const Duration(milliseconds: 360),
                  child: _MoneyDateCard(store: store),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(height: 6),
              Center(
                child: Text(
                  tr('localOnly'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Общий остаток и как он менялся. Крупное число — деньги сейчас, кривая под
/// ним — как к этому пришли; вместе они отвечают на «сколько» и «почему».
/// Общий баланс: свёрнут по умолчанию, разворачивается касанием.
///
/// В свёрнутом виде — сумма, строка отрезка и мини-график: этого хватает,
/// чтобы понять, куда идут деньги, и не листать экран. Развёрнутый показывает
/// отрезки, стрелки и полный график с осями. Раньше всё это стояло всегда и
/// занимало пол-экрана, хотя смотрят туда раз в день.
///
/// Значок сверху справа открывает отбор по счетам: общий баланс считается по
/// тем счетам, которые человек оставил.
class _BalanceCard extends StatelessWidget {
  final Store store;
  final Period period;
  final ValueChanged<Period> onPeriod;

  const _BalanceCard({required this.store, required this.period, required this.onPeriod});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final base = db.baseCurrency;
    final chosen = store.balanceAccounts;
    final open = store.balanceOpen;
    // Свой отрезок у блока: он помнится между запусками вместе с тем месяцем,
    // который человек пролистал стрелками.
    final own = store.periodOf('balance', fallback: period);

    final all = balances(db);
    final mine = chosen.isEmpty
        ? all
        : all.where((a) => chosen.contains(a.name)).toList();
    final total = totalBase(mine);
    final flow = cashflow(db, own, filter: Filter(accounts: chosen));
    final series = balanceSeries(db, own, accounts: chosen);
    // Ровная линия не отвечает ни на один вопрос: в месяце без операций
    // мини-график рисовал пустую зелёную полоску, и человек искал в ней смысл.
    final flat = series.length < 2 ||
        series.every((p) => (p.value - series.first.value).abs() < 0.005);

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () => store.setBalanceOpen(!open),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    tr('totalBalance'),
                    style: TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      letterSpacing: -0.3,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                // Отбор по счетам: пока он не пустой, значок подсвечен —
                // иначе человек забудет, что смотрит не на все деньги.
                BlockPeriodButton(store: store, block: 'balance', fallback: period),
                IconButton(
                  onPressed: () => _pickAccounts(context, all),
                  visualDensity: VisualDensity.compact,
                  tooltip: tr('whichAccounts'),
                  icon: Icon(
                    chosen.isEmpty
                        ? Myna.filter
                        : Myna.xCircle,
                    color: chosen.isEmpty ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                ),
                Icon(
                  open ? Myna.chevronUp : Myna.chevronDown,
                  color: scheme.onSurfaceVariant,
                ),
              ]),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Главное число экрана НАБЕГАЕТ при смене месяца и
                        // отборе счетов: подмена рывком читается как
                        // перерисовка, набег — как пересчёт.
                        AnimatedMoney(
                          total,
                          currency: base,
                          size: 30,
                          weight: FontWeight.w800,
                          squeeze: true,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          MoneyText(
                            flow.total,
                            currency: base,
                            size: 13.5,
                            colored: true,
                            sign: true,
                          ),
                          if (chosen.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                trf('accountsChosen', [chosen.length]),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTheme.bodyFont,
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  if (open)
                    BlockPeriodArrows(store: store, block: 'balance', fallback: period)
                  else
                    // Отрезок стоит В СТРОКЕ ЗАГОЛОВКА, справа от «Общий
                    // баланс»: так решил человек (17.09.2026). У графика он
                    // стоял один день и был отвергнут.
                    //
                    // Свёрнутый вид отвечает на один вопрос: росло или падало.
                    // Ровная линия не отвечает ни на один, и её не рисуем.
                    if (!flat)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 2),
                        child: Sparkline(
                          points: series,
                          color: flow.total >= 0
                              ? Money.up(context)
                              : Money.down(context),
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                ],
              ),
              if (open) ...[
                const SizedBox(height: 10),
                DayChart(
                  points: series,
                  color: scheme.primary,
                  signed: true,
                  height: 140,
                  labelOf: (v) => formatMoney(v, base, decimals: 0),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAccounts(
    BuildContext context,
    List<AccountBalance> all,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _BalanceFilterSheet(store: store, accounts: all),
    );
  }
}

/// Отбор счетов для общего баланса.
class _BalanceFilterSheet extends StatefulWidget {
  const _BalanceFilterSheet({required this.store, required this.accounts});

  final Store store;
  final List<AccountBalance> accounts;

  @override
  State<_BalanceFilterSheet> createState() => _BalanceFilterSheetState();
}

class _BalanceFilterSheetState extends State<_BalanceFilterSheet> {
  late final Set<String> _chosen = {...widget.store.balanceAccounts};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.store.view.baseCurrency;

    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            tr('whichAccounts'),
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 19),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              CheckboxListTile(
                value: _chosen.isEmpty,
                onChanged: (_) => setState(_chosen.clear),
                title: Text(
                  tr('allAccounts'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const Divider(height: 1),
              for (final account in widget.accounts)
                CheckboxListTile(
                  value: _chosen.contains(account.name),
                  onChanged: (_) => setState(() {
                    if (!_chosen.remove(account.name)) _chosen.add(account.name);
                  }),
                  title: Text(
                    account.name,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    formatMoney(account.converted, base),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.store.setBalanceAccounts(_chosen);
                Navigator.of(context).pop();
              },
              child: Text(tr('done')),
            ),
          ),
        ),
      ]),
    );
  }
}
class _AccountsGrid extends StatelessWidget {
  final Store store;
  final List<AccountBalance> accounts;

  /// Строка «Отложено на цели» ведёт к целям, а не к счетам: деньги там, и смотреть
  /// их человек идёт туда.
  final VoidCallback onGoals;

  const _AccountsGrid({
    required this.store,
    required this.accounts,
    required this.onGoals,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final show = accounts.take(6).toList();
    return Column(
      children: [
        for (var i = 0; i < show.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < show.length ? 14 : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _AccountTile(store: store, item: show[i])),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < show.length
                      ? _AccountTile(store: store, item: show[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        if (accounts.length > show.length) ...[
          const SizedBox(height: 12),
          Text(
            trf('andMore', [accounts.length - show.length]),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (goalsTotal(db).abs() >= 0.01) ...[
          const SizedBox(height: 14),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onGoals,
              borderRadius: BorderRadius.circular(14),
              child: Row(
                children: [
                  Icon(Myna.flag, size: 18, color: scheme.onSurfaceVariant),
                  SizedBox(width: 8),
                  // Деньги целей лежат на отдельных счетах и в общий баланс
                  // НЕ входят. Пока строка молчала об этом, человек не знал,
                  // сложены эти двести лей с суммой сверху или нет.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('inGoals'),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 13.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          tr('goalsOutsideBalance'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  MoneyText(goalsTotal(db), currency: db.baseCurrency, size: 13.5),
                  const SizedBox(width: 4),
                  Icon(Myna.chevronRight, size: 18,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final Store store;
  final AccountBalance item;
  const _AccountTile({required this.store, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final at = store.view.accounts.indexWhere((a) => a.name == item.name);
    final stored = at >= 0 ? store.view.accounts[at] : null;
    // Цвет кружка — цвет ОФОРМЛЕНИЯ карты, а не хеш имени: человек выбрал
    // голубую карту, а в списке видел песочный кружок («цвет не передаётся»,
    // 13.09.2026). Свой цвет счёта, если он задан, сильнее.
    final color = stored?.color != null
        ? Color(stored!.color!)
        : designOf(stored, item.name).fill;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LabelDot(
          name: item.name,
          icon: accountIcon(item.name, stored: stored?.icon),
          color: color,
          size: 38,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              MoneyText(
                item.mainAmount,
                currency: item.mainCurrency,
                size: 13,
                weight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
                // Половина ширины карточки на счёт: миллион тут ломался на
                // две строки и разъезжался с именем счёта.
                squeeze: true,
              ),
              // Счёт в долларах под общей суммой в леях: сложить их глазом
              // нельзя, и единственный счёт «USD 1 500» не объяснял
              // «MDL 24 911» сверху (16.09.2026).
              if (item.mainCurrency != store.view.baseCurrency)
                Text(
                  '≈ ${formatMoney(item.converted, store.view.baseCurrency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Круглая кнопка шапки. Голый значок терялся рядом с аватаром и чипом пары,
/// а круг ставит их в один ряд одинаковых форм.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.fill,
    this.ink,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// Своя заливка и свой цвет значка. Пусто — серый круг темы.
  final Color? fill;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final tm = context.tm;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill ?? tm.field,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: ink ?? tm.text),
          ),
        ),
      ),
    );
  }
}

/// Своя аватарка в шапке: вход в профиль и знак того, чей это аккаунт.
class _Me extends StatelessWidget {
  const _Me({required this.store, required this.session, required this.onTap});

  final Store store;
  final Session? session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uid = session?.uid ?? store.viewer;
    // Имя и аватар берутся из пары, а если их там нет — из своего профиля:
    // у одиночки пары нет вовсе.
    final fromPair = store.db.pair.byUid(uid);
    final me = Member(
      uid: uid,
      name: fromPair?.name.trim().isNotEmpty == true
          ? fromPair!.name
          : (session?.name ?? ''),
      avatarUrl: (fromPair?.avatarUrl ?? '').trim().isNotEmpty
          ? fromPair!.avatarUrl
          : session?.avatar,
    );
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: MemberBadge(member: me, isMe: true, size: 40, showName: false),
    );
  }
}

class _BudgetRows extends StatelessWidget {
  final Store store;
  final Period period;
  const _BudgetRows({required this.store, required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    // Конверт считается ровно так же, как на экране бюджетов: иначе один и
    // тот же лимит показывал бы на двух экранах разные числа.
    final show = [for (final b in db.budgets.take(3)) envelopeOf(db, b)];

    return Column(
      children: [
        for (final env in show)
          Padding(
            padding: EdgeInsets.only(bottom: env == show.last ? 0 : 14),
            child: _BudgetRow(
              name: env.budget.title,
              spent: env.spent,
              limit: env.allowance,
              currency: env.budget.currency,
            ),
          ),
        if (db.budgets.length > show.length) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              trf('andMore', [db.budgets.length - show.length]),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final String name;
  final double spent;
  final double limit;
  final String currency;

  const _BudgetRow({
    required this.name,
    required this.spent,
    required this.limit,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final share = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = limit > 0 && spent > limit;
    final color = over ? Money.down(context) : labelColorFor(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
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
            const SizedBox(width: 8),
            Text(
              '${formatMoney(spent, currency)} ${trf('ofAmount', [formatAmount(limit)])}',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: over ? Money.down(context) : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: share.toDouble()),
            duration: const Duration(milliseconds: 560),
            curve: AppTheme.emphasizedDecelerate,
            builder: (context, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 7,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// Плашка пересмотра: раз в месяц или квартал пара обязана свериться.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.store, required this.onOpen});

  final Store store;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final months = store.view.rules.reviewMonths;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        Icon(Myna.repeat, color: scheme.onSurface),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              tr('reviewDue'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                // Подложка плашки — surfaceContainerHighest, и буквы к ней
                // onSurface. onPrimaryContainer равен onAccent: белым по
                // светло-серому.
                color: scheme.onSurface,
              ),
            ),
            SizedBox(height: 2),
            Text(
              months == 1
                  ? tr('reviewMonthly')
                  : trf('reviewEveryMonths', [months]),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                height: 1.3,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            store.setRules(markReviewed(store.view.rules));
            onOpen();
          },
          style: TextButton.styleFrom(foregroundColor: scheme.onPrimaryContainer),
          child: Text(tr('open')),
        ),
      ]),
    );
  }
}

/// Превью ПЛАНА: сколько осталось распределить и верхние строки плана.
///
/// Раньше здесь стояли три доли правила 50/30/20 — и карточка под заголовком
/// «План на месяц» показывала не план, а разбор дохода («почему написано План
/// на месяц, если это не план», 14.09.2026). Правило осталось на своём
/// экране, отдельным блоком «Куда уходит доход»: оно про договорённость, а не
/// про то, что человек расписал на этот месяц.
class _PlanRows extends StatelessWidget {
  const _PlanRows({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final now = DateTime.now();
    final plan = planOf(db, now);

    if (plan.isEmpty) {
      return CardEmpty(icon: Myna.clipboard, text: tr('noPlan'));
    }

    // Только СВОИ строки: траты без плана лежат в модели справкой и на
    // главной выглядели бы планом, которого нет.
    final rows = plan.rows.where((r) => r.planned > 0).toList()
      ..sort((a, b) => b.planned.compareTo(a.planned));
    final shown = rows.take(3).toList();

    return Column(children: [
      Row(children: [
        Expanded(
          child: Text(
            plan.balanced
                ? tr('planAllocated')
                : plan.unassigned > 0
                    ? tr('planLeft')
                    : tr('planOver'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        MoneyText(
          plan.unassigned,
          currency: db.baseCurrency,
          size: 15,
          weight: FontWeight.w700,
          squeeze: true,
          color: plan.balanced
              ? Money.up(context)
              : plan.unassigned < 0
                  ? Money.down(context)
                  : null,
        ),
      ]),
      const SizedBox(height: 12),
      for (var i = 0; i < shown.length; i++) ...[
        if (i > 0) const SizedBox(height: 8),
        _MiniBar(
          title: shown[i].name,
          actual: shown[i].actual,
          target: shown[i].planned,
          currency: db.baseCurrency,
        ),
      ],
      if (rows.length > shown.length) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            trf('planMoreRows', [rows.length - shown.length]),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ]);
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.title,
    required this.actual,
    required this.target,
    required this.currency,
  });

  final String title;
  final double actual;
  final double target;
  final String currency;

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
              fontSize: 13,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          target <= 0
              ? formatMoney(actual, currency)
              : '${formatMoney(actual, currency)} ${trf('ofAmount', [formatAmount(target)])}',
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12,
            color: over ? Money.down(context) : scheme.onSurfaceVariant,
          ),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: share),
          duration: const Duration(milliseconds: 560),
          curve: AppTheme.emphasizedDecelerate,
          builder: (context, v, _) => LinearProgressIndicator(
            value: v,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
                over ? Money.down(context) : labelColorFor(title)),
          ),
        ),
      ),
    ]);
  }
}

/// Превью долгов: сколько осталось и что гасить первым.
/// «2,4» или «3»: число с одним знаком, без лишнего нуля.
String _months(double v) {
  final rounded = (v * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.round().toString()
      : rounded.toString().replaceAll('.', ',');
}

class _DebtRows extends StatelessWidget {
  const _DebtRows({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = store.view;
    final totals = debtTotals(db);
    final plan = payoffPlan(db).where((s) => !s.closed).toList();

    return Column(children: [
      Row(children: [
        Expanded(
          child: Text(
            totals.open == 0 ? tr('debtsPaid') : tr('debtsLeft'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        MoneyText(totals.left, currency: db.baseCurrency, size: 15, weight: FontWeight.w700),
      ]),
      if (plan.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Myna.dangerCircle, size: 16, color: scheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              trf('debtsFirst', [plan.first.debt.name]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        ]),
        SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${trf('debtsInterest', [
                  formatMoney(totals.monthlyInterest, db.baseCurrency)
                ])}${tr('perMonth')}',
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Превью целей: три ближайших. Вклады по людям тут не рисуем — на главной
/// важно «сколько собрано», а чей вклад смотрят на самом экране целей.
class _GoalRows extends StatelessWidget {
  final Store store;
  const _GoalRows({required this.store});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = allGoals(store.view);
    // Сосуд выше прежней строки с полоской, и три подряд съедали экран:
    // на главной показываем две цели, остальные считает строка «и ещё N».
    final show = all.take(2).toList();

    return Column(
      children: [
        for (final g in show)
          Padding(
            padding: EdgeInsets.only(bottom: g == show.last ? 0 : 14),
            child: _GoalRow(
              progress: g,
              reserve: g.goal.isReserve ? reserveOf(store.view, g.goal) : null,
            ),
          ),
        if (all.length > show.length) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              trf('andMore', [all.length - show.length]),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalRow extends StatelessWidget {
  final GoalProgress progress;
  final Reserve? reserve;
  const _GoalRow({required this.progress, this.reserve});

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final own = goal.color == null ? null : Color(goal.color!);
    final color =
        progress.done ? Money.up(context) : (own ?? labelColorFor(goal.name));
    final share = reserve?.share ?? progress.share;
    final known = progress.hasTarget || (reserve != null && !reserve!.unknown);

    return GoalVessel(
      name: goal.name,
      // У подушки важны месяцы: «2,4 из 6 месяцев» говорит больше, чем сумма,
      // которая ничего не значит без расходов.
      caption: reserve != null && !reserve!.unknown
          ? trf('monthsShort', [_months(reserve!.monthsCovered), reserve!.monthsWanted])
          : progress.hasTarget
              ? '${formatMoney(progress.saved, goal.currency)} '
                  '${trf('ofAmount', [formatAmount(goal.target)])}'
              : formatMoney(progress.saved, goal.currency),
      // Цель без срока и без суммы наливать нечем: сосуд стоит пустым, и
      // процент рядом с ним был бы выдумкой.
      share: known ? share : 0,
      badge: known ? '${(share.clamp(0.0, 1.0) * 100).round()}%' : null,
      color: color,
      icons: goalScatterIcons(goal.name,
          stored: goal.icon, reserve: goal.isReserve),
      height: 96,
    );
  }
}

/// Сальдо пары словами. Пусто — пары нет или все в расчёте, и карточку
/// рисовать незачем.
String? _settlementLine(Store store) {
  final db = store.view;
  if (db.pair.members.length < 2 || store.viewer.isEmpty) return null;
  final net = settlement(db.transactions, db.pair);
  final mine = net[store.viewer] ?? 0;
  if (mine.abs() < 0.01) return null;
  return debtLine(net, db.pair, store.viewer);
}

/// Карточка долга: строка и кнопка «Рассчитались». Сальдо нигде не хранится,
/// оно считается из журнала операций при каждом заходе.
class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.text, required this.store});

  final String text;
  final Store store;

  /// Кто кому должен и сколько. Плюс — должны мне.
  double get _mine {
    final db = store.view;
    return settlement(db.transactions, db.pair)[store.viewer] ?? 0;
  }

  /// Записать расчёт. Деньги передаются вне приложения, поэтому остатки не
  /// двигаются — закрывается только долг.
  Future<void> _settle(BuildContext context) async {
    final db = store.view;
    final other = db.pair.other(store.viewer);
    if (other == null) return;
    final mine = _mine;
    if (mine.abs() < 0.005) return;

    final iOwe = mine < 0;
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.checkCircle,
        title: tr('settleAskTitle'),
        text: trf('settleAskText', [
          formatMoney(mine.abs(), db.baseCurrency),
          other.name,
        ]),
        action: tr('settleUp'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true) return;
    store.settleUp(
      from: iOwe ? store.viewer : other.uid,
      to: iOwe ? other.uid : store.viewer,
      amount: mine.abs(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              // Имя партнёра стоит ЗДЕСЬ, а сумма говорит направление:
              // «За JB SHARAN 3,50» не отвечало, кто кому должен.
              debtWith(store.view.pair, store.viewer),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        OutlinedButton(
          onPressed: () => _settle(context),
          child: Text(tr('settleUp')),
        ),
      ]),
    );
  }
}

/// Новые списания из уведомлений банка.
class _NoticesCard extends StatelessWidget {
  const _NoticesCard({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.tm.field,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Myna.bellOn,
                size: 20,
                color: context.tm.text,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _title(count),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  tr('noticesHint'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12.5,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
            Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  /// Счёт по-русски: «одно списание», «три списания», «пять списаний».
  static String _title(int n) => '$n ${trn('notices', n)}';
}

/// Категории кварталами: площадь и есть сумма.
///
/// По умолчанию расходы — их смотрят каждый день. Касание переключает на
/// доходы: кварталы переезжают и перекрашиваются, а не подменяются мгновенно,
/// поэтому видно, что это та же карточка про те же деньги.
///
/// Отрезок у блока свой, кнопка стоит в углу и помнится между запусками.
class _QuartersCard extends StatefulWidget {
  const _QuartersCard({
    required this.store,
    required this.onDrill,
    this.fallback,
  });

  final Store store;
  final void Function(String? category, bool income, [Period? period]) onDrill;

  /// Пока человек не выбрал свой отрезок, блок берёт отрезок экрана: при
  /// первом запуске все карточки говорят про один и тот же месяц.
  final Period? fallback;

  @override
  State<_QuartersCard> createState() => _QuartersCardState();
}

class _QuartersCardState extends State<_QuartersCard> {
  bool _income = false;

  static const _block = 'categories';

  /// Набор знаков для ассорти: значок самой категории и значки её
  /// подкатегорий. Повторы убираются — два одинаковых знака в наборе просто
  /// сделали бы фактуру беднее.
  List<IconData> _scatterIcons(String category) {
    final out = <IconData>[categoryIcon(category)];
    final store = widget.store;
    final own = store.view.categories
        .where((c) => c.name == category && (c.parent ?? '').isEmpty)
        .firstOrNull;
    if (own?.icon != null) out[0] = categoryIcon(category, stored: own!.icon);
    for (final sub in store.subcategoriesOf(category)) {
      final icon = categoryIcon(sub.name, stored: sub.icon);
      if (!out.contains(icon)) out.add(icon);
    }
    return out;
  }

  /// Цвет квартала — цвет КАТЕГОРИИ: тот же, которым она подписана в ленте и
  /// на круге. Свой цвет, выбранный человеком, сильнее.
  ///
  /// Если два соседних квартала оказались одного оттенка (палитра считается по
  /// имени, и совпадения бывают), второй берёт следующий свободный цвет —
  /// иначе карточка выглядит поломанной.
  Color _colorFor(List<CategorySlice> slices, int index) {
    final db = widget.store.view;

    Color own(CategorySlice slice) {
      final chosen = db.categories
          .where((c) => c.name == slice.name)
          .map((c) => c.color)
          .firstOrNull;
      return chosen != null ? Color(chosen) : labelColorFor(slice.name);
    }

    final used = <int>{};
    for (var i = 0; i <= index; i++) {
      var color = own(slices[i]);
      if (used.contains(color.toARGB32())) {
        for (final next in labelColors) {
          if (!used.contains(next.toARGB32())) {
            color = next;
            break;
          }
        }
      }
      used.add(color.toARGB32());
      if (i == index) return color;
    }
    return own(slices[index]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = widget.store;
    final db = store.view;
    final period = store.periodOf(_block, fallback: widget.fallback);
    final slices = byCategory(db, period, income: _income).take(6).toList();
    final total = slices.fold<double>(0, (sum, s) => sum + s.sum.abs());
    final tint = _income ? Money.up(context) : Money.down(context);

    // Material, а не Container: внутри живут нажимаемые кварталы и кнопка
    // отрезка, а им нужен материал-предок — на главной без Scaffold карточка
    // иначе падала с «No Material widget found».
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _income = !_income),
              child: Text(
                tr('categories'),
                style: TextStyle(
                  fontFamily: AppTheme.displayFont,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.3,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
          BlockPeriodButton(
            store: store,
            block: _block,
            fallback: widget.fallback,
          ),
        ]),
        const SizedBox(height: 10),
        // Сумма и переключатель стоят в одной строке: пилюля у заголовка
        // толкалась с кнопкой отрезка и висела криво.
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: Offset(0, _income ? 0.35 : -0.35),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Align(
                key: ValueKey(_income),
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  _income ? total : -total,
                  currency: db.baseCurrency,
                  size: 26,
                  weight: FontWeight.w800,
                  colored: true,
                  squeeze: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Пилюля и есть переключатель: говорит, что видно сейчас, и что
          // будет по нажатию.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _income = !_income),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 320),
              curve: AppTheme.emphasizedDecelerate,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                // Цвет в системе живёт на деньгах, а не на плашках: тонировка
                // подложки давала коралл по бордовому и читалась хуже слова.
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  tr(_income ? 'income' : 'spending'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tint,
                  ),
                ),
                const SizedBox(width: 5),
                Icon(Myna.arrowLeftRight, size: 15, color: tint),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Quarters(
          slices: slices,
          currency: db.baseCurrency,
          colorOf: (slice, index) => _colorFor(slices, index),
          // Ассорти на фоне квартала собирается из значков подкатегорий: у
          // продуктов свои у кофе, рынка и аптеки. Нет подкатегорий — знак
          // самой категории, но тогда и разнообразия ждать негде.
          iconsOf: (slice) => _scatterIcons(slice.name),
          // Нажали квартал — открылась лента: та же категория, та же сторона
          // и тот же отрезок, что выбран в блоке.
          onTapSlice: (name) => widget.onDrill(name, _income, period),
        ),
        SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              slices.isEmpty
                  ? (_income ? tr('noIncomeHere') : tr('noSpendingHere'))
                  : tr('quartersHint'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          BlockPeriodArrows(
            store: store,
            block: _block,
            fallback: widget.fallback,
          ),
        ]),
      ]),
      ),
    );
  }
}


/// Ближайшие списания: что уйдёт на днях и что уже просрочено.
class _SoonCard extends StatelessWidget {
  const _SoonCard({
    required this.items,
    required this.currency,
    required this.onOpen,
  });

  final List<Recurring> items;
  final String currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Myna.calendarCheck, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('soonTitle'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
            ]),
            const SizedBox(height: 10),
            for (final r in items.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      r.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _when(r.nextDate, today),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _late(r.nextDate, today)
                          ? Money.down(context)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  MoneyText(
                    -r.amount,
                    currency: r.currency,
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ]),
              ),
            if (items.length > 3)
              Text(
                trf('soonMore', ['${items.length - 3}']),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ]),
        ),
      ),
    );
  }

  static bool _late(String date, DateTime today) {
    final at = DateTime.tryParse(date);
    if (at == null) return false;
    return at.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// «Сегодня», «Завтра», «Просрочено» или число.
  static String _when(String date, DateTime today) {
    final at = DateTime.tryParse(date);
    if (at == null) return date;
    final days = DateTime(at.year, at.month, at.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (days < 0) return tr('soonLate');
    if (days == 0) return tr('today');
    if (days == 1) return tr('tomorrow');
    return '${at.day} ${monthOf(at.month)}';
  }
}

/// Забытые подписки: то, что списывается третий месяц подряд мимо регулярных.
class _SubsCard extends StatelessWidget {
  const _SubsCard({required this.items, required this.onOpen});

  final List<Subscription> items;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Myna.repeat, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trf('subsTitle', ['${items.length}']),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Myna.chevronRight, color: scheme.onSurfaceVariant),
            ]),
            const SizedBox(height: 6),
            Text(
              items.take(3).map((s) => s.name).join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}


bool _paired(Store store) => store.view.pair.members.length > 1;

/// Разговор о деньгах: дата встречи и кнопка её назначить.
///
/// «Money date» из Zeta. Раз в месяц пара садится и смотрит на числа вместе —
/// но только если день назначен заранее.
class _MoneyDateCard extends StatelessWidget {
  const _MoneyDateCard({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final raw = store.view.rules.moneyDate;
    final at = DateTime.tryParse(raw);
    final today = DateTime.now();
    final days = at == null
        ? null
        : DateTime(at.year, at.month, at.day)
            .difference(DateTime(today.year, today.month, today.day))
            .inDays;

    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _pick(context, at ?? today),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(children: [
            Icon(Myna.heart, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('moneyDateTitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _line(at, days),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: days != null && days < 0
                      ? Money.down(context)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Myna.chevronRight, size: 18, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  static String _line(DateTime? at, int? days) {
    if (at == null || days == null) return tr('moneyDateNone');
    if (days < 0) return tr('moneyDatePassed');
    if (days == 0) return tr('today');
    if (days == 1) return tr('tomorrow');
    return '${at.day} ${monthOf(at.month)}';
  }

  Future<void> _pick(BuildContext context, DateTime initial) async {
    final now = DateTime.now();
    final picked = await showDateWheel(
      context,
      title: tr('moneyDateTitle'),
      initial: initial,
      firstYear: now.year,
      lastYear: now.year + 2,
    );
    if (picked == null) return;
    store.setRules(store.view.rules.copyWith(
      moneyDate: picked.toIso8601String().substring(0, 10),
    ));
  }
}
