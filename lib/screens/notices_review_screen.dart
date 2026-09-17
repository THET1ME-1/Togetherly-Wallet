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
import '../widgets/sender_logo.dart';
import '../design/myna.dart';
import '../ui/theme/tm_scheme.dart';

/// Разбор списаний: что банк прислал, а приложение прочитало.
///
/// Отдельный экран, а не раздел настроек: здесь человек РАБОТАЕТ — смотрит
/// сумму, правит счёт, подтверждает. Настройки чтения живут своей жизнью и
/// открываются раз в полгода.
class NoticesReviewScreen extends StatelessWidget {
  const NoticesReviewScreen({super.key, required this.store, this.notices});

  final Store store;
  final Notices? notices;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final pending = store.pendingNotices;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('reviewTitle')),
            actions: [
              if (pending.length > 1)
                TextButton(
                  onPressed: () => _dismissAll(context),
                  child: Text(tr('reviewClearAll')),
                ),
              const SizedBox(width: 4),
            ],
          ),
          body: pending.isEmpty
              ? const _Empty()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                  children: [
                    for (final notice in pending)
                      _NoticeCard(
                        store: store,
                        notice: notice,
                        logo: notices?.logos[notice.package],
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _dismissAll(BuildContext context) {
    Tap.warn();
    for (final notice in store.pendingNotices) {
      store.dismissNotice(notice);
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

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
    required this.store,
    required this.notice,
    this.logo,
  });

  final Store store;
  final ParsedNotice notice;
  final Uint8List? logo;

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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              onPressed: () {
                // Отказ отвечает отчётливее подтверждения: списание уходит
                // насовсем, и спутать эти две кнопки на ощупь нельзя.
                Tap.warn();
                widget.store.dismissNotice(notice);
              },
              child: Text(tr('reviewDismiss')),
            ),
          ),
        ]),
      ]),
    );
  }

  void _accept() {
    // Очередь списаний проходят подряд, глядя на суммы, а не на кнопки:
    // палец должен знать, что карточка принята.
    Tap.done();
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


