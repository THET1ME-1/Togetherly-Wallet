import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import 'category_pick_screen.dart';
import '../l10n/strings.dart';
import '../logic/haptics.dart';
import '../design/app_theme.dart';
import '../logic/money.dart';
import '../logic/notice_match.dart';
import '../logic/notice_parse.dart';
import '../services/notices.dart';
import '../widgets/money_text.dart';
import '../widgets/motion.dart';
import '../widgets/sender_logo.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';
import '../services/analytics.dart';

/// Разбор списаний: что банк прислал, а приложение прочитало.
///
/// Отдельный экран, а не раздел настроек: здесь человек РАБОТАЕТ — смотрит
/// сумму, правит счёт, подтверждает. Настройки чтения живут своей жизнью и
/// открываются раз в полгода.
class NoticesReviewScreen extends StatefulWidget {
  const NoticesReviewScreen({super.key, required this.store, this.notices});

  final Store store;
  final Notices? notices;

  @override
  State<NoticesReviewScreen> createState() => _NoticesReviewScreenState();
}

/// Разобранная карточка уходит в свою сторону — «Записать» вправо,
/// «Отклонить» влево — и очередь смыкается. Раньше карточка пропадала за
/// кадр, и при разборе подряд было не понять, что стало с предыдущей.
///
/// У карточек ключ по отпечатку уведомления. Без ключа следующая карточка
/// получала состояние ушедшей: выбранный там счёт и категорию.
class _NoticesReviewScreenState extends State<NoticesReviewScreen> {
  Store get store => widget.store;

  List<ParsedNotice> _prev = const [];
  final Map<String, ParsedNotice> _ghosts = {};
  final Map<String, String?> _after = {};

  /// Куда уезжает карточка: 1 — записана, -1 — отклонена.
  final Map<String, int> _exit = {};

  /// Смахнутые жестом: Dismissible уже увёл их сам, второй раз не провожаем.
  final Set<String> _swiped = {};

  List<ParsedNotice> _track(List<ParsedNotice> pending) {
    final prev = _prev;
    _prev = pending;
    final now = {for (final n in pending) n.fingerprint};
    for (var i = 0; i < prev.length; i++) {
      final gone = prev[i];
      final fp = gone.fingerprint;
      if (now.contains(fp) || _ghosts.containsKey(fp)) continue;
      if (_swiped.remove(fp)) continue;
      String? after;
      for (var j = i - 1; j >= 0; j--) {
        if (now.contains(prev[j].fingerprint)) {
          after = prev[j].fingerprint;
          break;
        }
      }
      _ghosts[fp] = gone;
      _after[fp] = after;
    }
    _ghosts.removeWhere((fp, _) => now.contains(fp));
    if (_ghosts.isEmpty) return pending;
    final merged = [...pending];
    for (final g in _ghosts.values) {
      final after = _after[g.fingerprint];
      final at = after == null ? -1 : merged.indexWhere((n) => n.fingerprint == after);
      merged.insert(at + 1, g);
    }
    return merged;
  }

  void _gone(String fp) {
    if (!mounted) return;
    setState(() {
      _ghosts.remove(fp);
      _after.remove(fp);
      _exit.remove(fp);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pending = store.pendingNotices;
        final shown = _track(pending);
        final still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('reviewTitle')),
            actions: [
              if (pending.length > 1)
                TextButton(
                  onPressed: _dismissAll,
                  child: Text(tr('reviewClearAll')),
                ),
              const SizedBox(width: 4),
            ],
          ),
          // Последняя карточка ушла — «всё разобрано» проявляется, а не
          // подменяет пустоту за кадр.
          body: AnimatedSwitcher(
            duration: still ? Duration.zero : Motion.state,
            switchInCurve: Motion.enter,
            child: shown.isEmpty
                ? const _Empty(key: ValueKey('empty'))
                : ListView(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                    children: [
                      // Трата уже произошла — заходить и подтверждать каждую
                      // человек не нанимался («зачем ждать, я заходить и жать
                      // Записать», 22.09.2026). Одно касание пишет всё, что
                      // приложение поняло наверняка; спорное остаётся ждать.
                      if (_ready.length > 1) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: _acceptAll,
                            child: Text(trf('reviewSaveAll', [_ready.length])),
                          ),
                        ),
                        if (_ready.length < pending.length)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: Text(
                              tr('reviewSaveAllHint'),
                              style: TextStyle(
                                fontFamily: AppTheme.bodyFont,
                                fontSize: 12.5,
                                height: 1.35,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      for (final notice in shown)
                        Leaving(
                          key: ValueKey(notice.fingerprint),
                          leaving: _ghosts.containsKey(notice.fingerprint),
                          slide: _exit[notice.fingerprint] ?? 0,
                          onDone: () => _gone(notice.fingerprint),
                          child: _NoticeCard(
                            key: ValueKey('card-${notice.fingerprint}'),
                            store: store,
                            notice: notice,
                            logo: widget.notices?.logos[notice.package],
                            onExit: (slide, swiped) {
                              _exit[notice.fingerprint] = slide;
                              if (swiped) _swiped.add(notice.fingerprint);
                            },
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  void _dismissAll() {
    Tap.warn();
    for (final notice in store.pendingNotices) {
      _exit[notice.fingerprint] = -1;
      store.dismissNotice(notice);
    }
  }

  /// Списания, у которых спрашивать нечего: разбор уверенный и счёт понятен.
  ///
  /// Неуверенное сюда не попадает намеренно — объявление с доски объявлений
  /// на 65 000 € приходило именно таким, и записывать такое пачкой нельзя.
  List<ParsedNotice> get _ready => store.pendingNotices
      .where((n) =>
          n.ok &&
          accountForNotice(
                store.db,
                ParsedNoticeRef(package: n.package, last4: n.last4),
                learned: store.noticeAccounts,
              ) !=
              null)
      .toList();

  void _acceptAll() {
    Tap.done();
    for (final notice in _ready) {
      final account = accountForNotice(
        store.db,
        ParsedNoticeRef(package: notice.package, last4: notice.last4),
        learned: store.noticeAccounts,
      );
      if (account == null) continue;
      _exit[notice.fingerprint] = 1;
      // Ту же трату человек мог записать руками до пуша: вторая такая же
      // строка хуже, чем ни одной.
      final day = DateTime.fromMillisecondsSinceEpoch(notice.at)
          .toIso8601String()
          .substring(0, 10);
      if (alreadyRecorded(store.db,
          amount: notice.amount,
          currency: notice.currency,
          date: day,
          account: account)) {
        store.dismissNotice(notice);
        continue;
      }
      Analytics.instance.action('notice_accepted', params: {
        'has_category': categoryForNotice(notice.merchant, store.noticeCategories) != null,
        'confident': notice.confidence >= 0.7,
        'bulk': true,
      });
      store.acceptNotice(
        notice,
        account: account,
        category: categoryForNotice(notice.merchant, store.noticeCategories),
        subcategory: subcategoryForNotice(notice.merchant, store.noticeCategories),
      );
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Myna.checkSquare, size: 40, color: scheme.onSurfaceVariant),
          SizedBox(height: 14),
          Text(
            tr('reviewDone'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 13.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ]),
      ),
    );
  }
}

/// Разобранный пуш: сумма, магазин, счёт и категория. Одно касание —
/// и трата записана.
class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    super.key,
    required this.store,
    required this.notice,
    required this.onExit,
    this.logo,
  });

  final Store store;
  final ParsedNotice notice;
  final Uint8List? logo;

  /// Карточку разобрали: куда ей уезжать (1 — записана, -1 — отклонена) и
  /// увёл ли её уже жест.
  final void Function(int slide, bool swiped) onExit;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  String? _account;
  String? _category;
  String? _sub;
  bool _raw = false;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    _account = accountForNotice(
      widget.store.db,
      ParsedNoticeRef(package: notice.package, last4: notice.last4),
      learned: widget.store.noticeAccounts,
    );
    _category = categoryForNotice(notice.merchant, widget.store.noticeCategories);
    _sub = subcategoryForNotice(notice.merchant, widget.store.noticeCategories);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notice = widget.notice;
    final income = notice.kind == TxKind.income;
    final at = DateTime.fromMillisecondsSinceEpoch(notice.at);
    final signed = income ? notice.amount : -notice.amount;
    final unsure = !notice.ok;
    // Та же покупка могла прийти дважды — от банка и от кошелька, — или быть
    // записанной руками. Запретить нельзя: суммы честно совпадают у разных
    // покупок. Поэтому говорим и оставляем решение человеку.
    final twin = _account != null &&
        alreadyRecorded(
          widget.store.db,
          amount: notice.amount,
          currency: notice.currency,
          date: DateTime.fromMillisecondsSinceEpoch(notice.at)
              .toIso8601String()
              .substring(0, 10),
          account: _account,
        );

    // Смахнуть — тот же выбор, что кнопки: вправо записать, влево
    // отклонить. Вправо без счёта не пускаем: записывать некуда.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('swipe-${notice.fingerprint}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.startToEnd && _account == null) {
            Tap.warn();
            return false;
          }
          return true;
        },
        onDismissed: (dir) => dir == DismissDirection.startToEnd
            ? _accept(swiped: true)
            : _dismiss(swiped: true),
        background: _SwipeHint(accept: true),
        secondaryBackground: _SwipeHint(accept: false),
        child: _body(context, scheme, notice, income, at, signed, unsure, twin),
      ),
    );
  }

  Widget _body(BuildContext context, ColorScheme scheme, ParsedNotice notice,
      bool income, DateTime at, double signed, bool unsure, bool twin) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: unsure ? scheme.onSurfaceVariant : scheme.outlineVariant,
          width: unsure ? 1.5 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SenderLogo(package: notice.package, bytes: widget.logo, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${senderTitle(notice.package)} · ${_time(at)}'
              '${notice.last4 == null ? '' : ' · •••• ${notice.last4}'}',
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _raw = !_raw),
            visualDensity: VisualDensity.compact,
            icon: Icon(_raw ? Myna.chevronUp : Myna.list, size: 20),
            tooltip: tr('reviewNoticeText'),
          ),
        ]),
        MoneyText(
          signed,
          currency: notice.currency,
          size: 24,
          colored: true,
          sign: income,
        ),
        if (notice.merchant != null)
          Text(
            notice.merchant!,
            maxLines: 2,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: scheme.onSurface,
            ),
          ),
        if (twin) ...[
          SizedBox(height: 8),
          Text(
            tr('reviewMaybeDouble'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: context.tm.expense,
            ),
          ),
        ],
        if (unsure) ...[
          SizedBox(height: 8),
          Text(
            tr('reviewUnsure'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: context.tm.expense,
            ),
          ),
        ],
        if (_raw) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              [notice.title, notice.body].where((s) => s.isNotEmpty).join('\n'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        SizedBox(height: 10),
        _Pick(
          icon: Myna.pocket,
          label: _account ?? tr('reviewPickAccount'),
          chosen: _account != null,
          onTap: _pickAccount,
        ),
        SizedBox(height: 6),
        _Pick(
          icon: Myna.label,
          label: _category == null
              ? tr('noCategory')
              : (_sub == null ? _category! : '$_category · $_sub'),
          chosen: _category != null,
          onTap: _pickCategory,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: _account == null ? null : _accept,
              child: Text(tr('reviewSave')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: _dismiss,
              child: Text(tr('reviewDismiss')),
            ),
          ),
        ]),
      ]),
    );
  }

  void _dismiss({bool swiped = false}) {
    // Отказ отвечает отчётливее подтверждения: списание уходит насовсем, и
    // спутать эти две кнопки на ощупь нельзя.
    Tap.warn();
    widget.onExit(-1, swiped);
    widget.store.dismissNotice(widget.notice);
  }

  void _accept({bool swiped = false}) {
    // Очередь списаний проходят подряд, глядя на суммы, а не на кнопки:
    // палец должен знать, что карточка принята.
    Tap.done();
    widget.onExit(1, swiped);
    // Сколько трат приложение записывает за человека — главная мера пользы
    // разбора уведомлений.
    Analytics.instance.action('notice_accepted', params: {
      'has_category': _category != null,
      'confident': widget.notice.confidence >= 0.7,
    });
    widget.store.acceptNotice(
      widget.notice,
      account: _account!,
      category: _category,
      subcategory: _sub,
    );
  }

  Future<void> _pickAccount() async {
    final picked = await _choose(
      context,
      title: tr('reviewWhere'),
      options: widget.store.db.accounts
          .where((a) => !isVirtualAccount(a.name))
          .map((a) => a.last4 == null ? a.name : '${a.name} · •••• ${a.last4}')
          .toList(),
      values: widget.store.db.accounts
          .where((a) => !isVirtualAccount(a.name))
          .map((a) => a.name)
          .toList(),
    );
    if (picked != null && mounted) setState(() => _account = picked);
  }

  /// Категория тем же экраном с поиском, что и везде.
  ///
  /// Раньше список собирался из всех записей подряд, включая подкатегории: их
  /// можно было выбрать, но записывались они КАТЕГОРИЕЙ — «Кофе» вместо
  /// «Продукты · Кофе».
  Future<void> _pickCategory() async {
    final picked = await pickCategory(
      context,
      store: widget.store,
      category: _category,
      subcategory: _sub,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _category = picked.category;
      _sub = picked.subcategory;
    });
  }

  static String _time(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Строка выбора: счёт или категория. Выглядит как поле, а не как кнопка, —
/// человек и правда выбирает значение.
class _Pick extends StatelessWidget {
  const _Pick({
    required this.icon,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 13.5,
                  fontWeight: chosen ? FontWeight.w600 : FontWeight.w400,
                  color: chosen ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
            Icon(Myna.chevronDown, size: 18, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}

Future<String?> _choose(
  BuildContext context, {
  required String title,
  required List<String> options,
  required List<String> values,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            title,
            style: TextStyle(fontFamily: AppTheme.displayFont, fontSize: 19),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (var i = 0; i < options.length; i++)
                ListTile(
                  title: Text(
                    options[i],
                    style: TextStyle(fontFamily: AppTheme.bodyFont, fontSize: 14.5),
                  ),
                  onTap: () => Navigator.of(context).pop(values[i]),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ]),
    ),
  );
}



/// Подложка под смахиваемой карточкой: что случится, если отпустить палец.
/// Цвет на неё не заходит — по правилу системы цвет живёт на деньгах.
class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.accept});

  final bool accept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: accept ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(accept ? Myna.check : Myna.x, size: 22, color: scheme.onSurface),
          const SizedBox(width: 8),
          Text(
            accept ? tr('reviewSave') : tr('reviewDismiss'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
