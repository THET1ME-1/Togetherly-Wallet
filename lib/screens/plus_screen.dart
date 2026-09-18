import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../data/models.dart';
import '../logic/period.dart';
import '../logic/plus.dart';
import '../logic/store_kind.dart';
import '../services/plus.dart';
import '../widgets/app_sheet.dart';
import '../widgets/member_badge.dart';
import '../widgets/reveal.dart';
import '../widgets/settings_kit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics.dart';

/// Витрина Wallet+.
///
/// Экран, а не лист: тарифы, девять пунктов и блок «что бесплатно навсегда» в
/// попап не помещаются, а попап во весь экран — просто экран, которому мешает
/// ручка сверху.
///
/// Порядок блоков выбран не случайно. Сначала цена: человек всё равно ищет её
/// первой, и прятать её под список — приём, за который приложения ругают.
/// Потом список того, что откроется. В конце — что останется бесплатным:
/// после витрины подписки это единственное, что снимает тревогу «а теперь всё
/// станет платным».
class PlusScreen extends StatefulWidget {
  const PlusScreen({
    super.key,
    required this.plus,
    this.onBuy,
    this.onRestore,
    this.prices,
    this.onManage,
  });

  final PlusService plus;

  /// Покупка магазином. У сборок RuStore и GitHub её нет: они платят через
  /// lava, и экран делает это сам.
  final Future<void> Function(PlusPlan plan)? onBuy;
  final Future<void> Function()? onRestore;

  /// Цены из магазина. Пусто — показываем свои: так живут сборки RuStore и
  /// GitHub, где касса lava и цена наша.
  final Future<Map<PlusPlan, String>> Function()? prices;
  final VoidCallback? onManage;

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  /// Годовой выбран заранее: он выгоднее человеку и нам, и прятать выгоду за
  /// лишнее касание незачем.
  PlusPlan _plan = PlusPlan.year;

  /// Кому достанется второе место. Пусто — никому: подписка открывает Плюс
  /// ОДНОМУ партнёру, а не всем парам разом.
  String _seat = '';
  List<PlusSeat> _pairs = const [];

  /// Цены магазина. Пока не приехали, стоят наши: пустая кнопка «Оформить»
  /// без цены хуже, чем цена, которая через миг уточнится.
  Map<PlusPlan, String> _storePrices = const {};

  @override
  void initState() {
    super.initState();
    _seat = widget.plus.seatUid;
    _loadPairs();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    final ask = widget.prices;
    if (ask == null) return;
    final found = await ask();
    if (!mounted || found.isEmpty) return;
    setState(() => _storePrices = found);
  }

  String _price(PlusPlan plan) => _storePrices[plan] ?? PlusPrice.rub.of(plan);

  Future<void> _loadPairs() async {
    final pairs = await widget.plus.seats();
    if (!mounted) return;
    setState(() => _pairs = pairs);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.plus,
      builder: (context, _) {
        final active = widget.plus.active;
        return Scaffold(
          appBar: AppBar(title: Text(tr('plusName'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            children: [
              Reveal(
                child: _Head(active: active, plus: widget.plus),
              ),
              const SizedBox(height: 16),
              if (!active) ...[
                Reveal(
                  delay: const Duration(milliseconds: 60),
                  child: _Tariffs(
                    plan: _plan,
                    priceOf: _price,
                    onPick: (v) => setState(() => _plan = v),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_pairs.isNotEmpty) ...[
                Reveal(
                  delay: const Duration(milliseconds: 75),
                  child: _Seat(
                    pairs: _pairs,
                    seat: _seat,
                    freeAt: widget.plus.seatFreeAt,
                    onPick: _pickSeat,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Reveal(
                delay: const Duration(milliseconds: 90),
                child: const _Features(),
              ),
              const SizedBox(height: 16),
              Reveal(
                delay: const Duration(milliseconds: 120),
                child: const _Free(),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: active
                ? OutlinedButton(
                    onPressed: widget.onManage,
                    child: Text(tr('plusManage')),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: widget.plus.busy ? null : _buy,
                          child: Text(tr('plusBuy')),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.plus.busy
                            ? null
                            : () => widget.onRestore == null
                                  ? _say(tr('plusSoon'))
                                  : widget.onRestore!(),
                        child: Text(tr('plusRestore')),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  /// Покупка. Сборки RuStore и GitHub платят через lava — ссылка открывается
  /// в браузере, а вернувшись, приложение сверяет талон с сервером. Сборки
  /// магазинов ждут своего биллинга и честно говорят об этом.
  Future<void> _buy() async {
    Analytics.instance.money('plus_buy_tap', params: {'plan': _plan.name});
    if (storeHasBilling) {
      final buy = widget.onBuy;
      if (buy == null) {
        _say(tr('plusSoon'));
        return;
      }
      await buy(_plan);
      return;
    }

    final url = await widget.plus.checkout(_plan, seat: _seat);
    if (!mounted) return;
    if (url.isEmpty) {
      _say(tr('plusPayFailed'));
      return;
    }
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    _say(opened ? tr('plusPayOpened') : tr('plusPayFailed'));
  }

  /// Кому отдать второе место. Место одно: пар у человека бывает несколько, и
  /// без выбора один платил бы, а пользовались все.
  Future<void> _pickSeat() async {
    final picked = await showMoneySheet<String>(
      context,
      builder: (context) => _SeatSheet(pairs: _pairs, seat: _seat),
    );
    if (picked == null || !mounted) return;
    final next = picked == '-' ? '' : picked;
    setState(() => _seat = next);
    // Подписки может ещё не быть: тогда выбор поедет вместе со счётом, а
    // сервер поставит место после оплаты.
    if (!widget.plus.active) return;
    final error = await widget.plus.giveSeat(next);
    if (!mounted || error.isEmpty) return;
    setState(() => _seat = widget.plus.seatUid);
    _say(error == 'too_soon'
        ? trf('plusSeatWait', ['${_daysLeft(widget.plus.seatFreeAt)}'])
        : tr('plusPayFailed'));
  }

  int _daysLeft(int at) {
    final left = at - DateTime.now().millisecondsSinceEpoch;
    return left <= 0 ? 0 : (left / 86400000).ceil();
  }

  void _say(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

/// Шапка: чем это приложению человека. У действующей подписки — срок и то,
/// чья она.
class _Head extends StatelessWidget {
  const _Head({required this.active, required this.plus});

  final bool active;
  final PlusService plus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pass = plus.pass;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Myna.sparkles,
              size: 26,
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            active ? tr('plusActive') : tr('plusTitle'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active ? _stateLine(pass, plus) : tr('plusText'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _stateLine(PlusPass? pass, PlusService plus) {
    if (pass == null) return tr('plusText');
    final until = DateTime.fromMillisecondsSinceEpoch(pass.until);
    final parts = <String>[
      trf('plusUntil', [Period(PeriodKind.day, until).label]),
      if (pass.fromPartner) tr('plusFromPartner'),
    ];
    return parts.join(' · ');
  }
}

/// Два тарифа в ряд. В столбик их ставить нельзя — сравнивают их взглядом,
/// а не пролистыванием.
class _Tariffs extends StatelessWidget {
  const _Tariffs({
    required this.plan,
    required this.priceOf,
    required this.onPick,
  });

  final PlusPlan plan;

  /// Цена тарифа. Берётся у магазина, если он ответил, иначе наша.
  final String Function(PlusPlan) priceOf;
  final ValueChanged<PlusPlan> onPick;

  @override
  Widget build(BuildContext context) {
    // Три ячейки в ряд, год посередине: он выгоднее всех в пересчёте на
    // месяц, и стоять ему по краю незачем (выбор человека 16.09.2026).
    const order = [PlusPlan.month, PlusPlan.year, PlusPlan.quarter];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in order) ...[
            if (p != order.first) const SizedBox(width: 8),
            Expanded(
              child: _TariffCell(
                title: switch (p) {
                  PlusPlan.month => tr('plusMonth'),
                  PlusPlan.quarter => tr('plusQuarter'),
                  PlusPlan.year => tr('plusYear'),
                },
                price: priceOf(p),
                // Выгода считается из самих цен: написанная руками, она
                // переживёт цены и начнёт врать.
                note: plusSaving(p) == 0
                    ? null
                    : trf('plusSaving', ['${plusSaving(p)}']),
                on: plan == p,
                onTap: () => onPick(p),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Второе место: кому, кроме покупателя, откроется Плюс.
///
/// Строка со своим листом, как переключатель пар в шапке. Место ОДНО: пар у
/// человека бывает несколько, а в группе бывает трое и больше, и правило
/// «одна подписка на пару» без выбора раздавало бы Плюс всем (16.09.2026).
class _Seat extends StatelessWidget {
  const _Seat({
    required this.pairs,
    required this.seat,
    required this.freeAt,
    required this.onPick,
  });

  final List<PlusSeat> pairs;
  final String seat;
  final int freeAt;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chosen = pairs.where((p) => p.uid == seat && seat.isNotEmpty).firstOrNull;
    final waiting = freeAt > DateTime.now().millisecondsSinceEpoch;

    return SettingsGroup([
      SettingsSection(tr('plusSeatTitle'), icon: Myna.users),
      SettingsBlock(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: Row(children: [
              if (chosen != null)
                MemberBadge(
                  member: Member(uid: chosen.uid, name: chosen.name,
                      avatarUrl: chosen.avatarUrl),
                  size: 36,
                  showName: false,
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Myna.userPlus, size: 18, color: scheme.onSurfaceVariant),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chosen?.name.trim().isNotEmpty == true
                          ? chosen!.name
                          : tr('plusSeatFree'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chosen == null ? tr('plusSeatNone') : tr('plusSeatWith'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Myna.chevronRight, size: 18, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
      SettingsBlock(
        child: Text(
          waiting
              ? trf('plusSeatWait',
                  ['${((freeAt - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil()}'])
              : '${tr('plusSeatSoon')} · ${tr('plusSeatDisband')}',
          style: TextStyle(
            fontFamily: AppTheme.bodyFont,
            fontSize: 12.5,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    ]);
  }
}

/// Лист выбора: все пары человека, чужие группы — с причиной отказа.
class _SeatSheet extends StatelessWidget {
  const _SeatSheet({required this.pairs, required this.seat});

  final List<PlusSeat> pairs;
  final String seat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('plusSeatPick'),
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final p in pairs)
            _SeatRow(
              pair: p,
              on: p.uid == seat && seat.isNotEmpty,
              // Отказ говорится словами: серый пункт без объяснения человек
              // читает как поломку приложения.
              reason: p.can ? null : trf('plusSeatGroup', ['${p.size}']),
              onTap: p.can ? () => Navigator.of(context).pop(p.uid) : null,
            ),
          _SeatRow(
            pair: const PlusSeat(
                groupId: '', uid: '', name: '', avatarUrl: '', size: 1, can: true),
            on: seat.isEmpty,
            label: tr('plusSeatOnlyMe'),
            reason: tr('plusSeatNone'),
            onTap: () => Navigator.of(context).pop('-'),
          ),
        ]),
      ),
    );
  }
}

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.pair,
    required this.on,
    this.label,
    this.reason,
    this.onTap,
  });

  final PlusSeat pair;
  final bool on;
  final String? label;
  final String? reason;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Выбранное — инверсия, правило системы.
    final bg = on ? scheme.secondaryContainer : scheme.surfaceContainerHigh;
    final ink = on ? scheme.onSecondaryContainer : scheme.onSurface;
    final soft = on
        ? scheme.onSecondaryContainer.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Opacity(
            opacity: onTap == null ? 0.55 : 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                if (pair.uid.isNotEmpty)
                  MemberBadge(
                    member: Member(
                        uid: pair.uid, name: pair.name, avatarUrl: pair.avatarUrl),
                    size: 32,
                    showName: false,
                  )
                else
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Myna.user, size: 16, color: scheme.onSurfaceVariant),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label ?? (pair.name.trim().isEmpty ? pair.uid : pair.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTheme.bodyFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      if (reason != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          reason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12,
                            color: soft,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (on) Icon(Myna.checkCircle, size: 20, color: ink),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TariffCell extends StatelessWidget {
  const _TariffCell({
    required this.title,
    required this.price,
    required this.on,
    required this.onTap,
    this.note,
  });

  final String title;
  final String price;
  final String? note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Выбранное — инверсия, правило системы.
    final bg = on ? scheme.secondaryContainer : scheme.surfaceContainerHigh;
    final ink = on ? scheme.onSecondaryContainer : scheme.onSurface;
    final soft = on
        ? scheme.onSecondaryContainer.withValues(alpha: 0.75)
        : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: soft,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  price,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppTheme.displayFont,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: ink,
                  ),
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note!,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: soft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Что откроется. Порядок по ценности: сперва то, за что платят, потом мелочи.
class _Features extends StatelessWidget {
  const _Features();

  static const _rows = <(IconData, String, String)>[
    (Myna.sparkles, 'plusFeatureChat', 'plusFeatureChatNote'),
    (Myna.fileText, 'plusFeatureFiles', 'plusFeatureFilesNote'),
    (Myna.bell, 'plusFeatureAuto', 'plusFeatureAutoNote'),
    (Myna.filter, 'plusFeatureRules', 'plusFeatureRulesNote'),
    (Myna.clipboard, 'plusFeaturePlanning', 'plusFeaturePlanningNote'),
    (Myna.chartBar, 'plusFeatureReport', 'plusFeatureReportNote'),
    (Myna.chartPieOne, 'plusFeatureReview', 'plusFeatureReviewNote'),
    (Myna.chartSpline, 'plusFeatureForecast', 'plusFeatureForecastNote'),
    (Myna.lock, 'plusFeatureLock', 'plusFeatureLockNote'),
    (Myna.cloud, 'plusFeatureBackups', 'plusFeatureBackupsNote'),
    (Myna.droplet, 'plusFeatureLooks', 'plusFeatureLooksNote'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(tr('plusWhatsIn'), icon: Myna.sparkles),
        SettingsGroup([
          for (final (icon, title, note) in _rows)
            SettingsRow(icon: icon, title: tr(title), subtitle: tr(note)),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            tr('plusPerPair'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Что бесплатно навсегда. Блок обязателен: витрина подписки без него читается
/// как объявление о том, что приложение закрывается на замок.
class _Free extends StatelessWidget {
  const _Free();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(tr('plusFreeTitle'), icon: Myna.heart),
        SettingsGroup([
          SettingsBlock(
            child: Text(
              tr('plusFreeText'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
