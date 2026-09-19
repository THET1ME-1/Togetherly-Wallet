import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../services/session.dart';
import 'app_sheet.dart';
import 'member_badge.dart';
import 'motion.dart';
import '../logic/period.dart';

/// Переключатель пары в шапке главной.
///
/// Человек ведёт деньги с несколькими людьми сразу: с женой одна пара, с
/// другом другая. Прятать переключение в настройки нельзя — в него ходят
/// каждый день («у меня тоже много групп, как их менять то», 13.09.2026).
/// Чипа нет вовсе, пока пара одна: лишняя кнопка на главной ничего не решает.
class SpaceSwitch extends StatefulWidget {
  const SpaceSwitch({
    super.key,
    required this.store,
    required this.session,
    this.onSwitched,
  });

  final Store store;
  final Session? session;
  final VoidCallback? onSwitched;

  @override
  State<SpaceSwitch> createState() => _SpaceSwitchState();
}

class _SpaceSwitchState extends State<SpaceSwitch> {
  List<Pair> _pairs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = widget.session;
    if (session == null || !session.signedIn) return;
    try {
      final all = await session.loadPairs();
      if (mounted) setState(() => _pairs = all);
    } catch (_) {
      // Сеть мёртвая — остаётся то, что уже открыто.
    }
  }

  /// Личное пространство: деньги, которых не видит НИКТО.
  ///
  /// Модель «yours, mine, ours» из приложений для пар: у каждого свой контур
  /// плюс общий. У Splitwise то же самое решается тратой вне группы.
  Pair _alone(String uid) => Pair(
        groupId: uid,
        baseCurrency: widget.store.db.baseCurrency,
        members: [
          widget.store.db.pair.byUid(uid) ?? Member(uid: uid, name: ''),
        ],
      );

  Future<void> _pick() async {
    final store = widget.store;
    final uid = widget.session?.uid ?? store.viewer;
    // Сводка живёт ОТДЕЛЬНЫМ ответом: она не пространство, а способ смотреть.
    final picked = await showMoneySheet<Object>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.users,
        title: tr('spaceTitle'),
        text: tr('spaceText'),
        action: tr('cancel'),
        onAction: () => Navigator.of(context).pop(),
        child: Column(children: [
          // «Все пары» — только взгляд: записи по-прежнему ложатся в открытую
          // пару, а сводка считается на этом телефоне и никому не уезжает.
          _AllLine(
            on: store.viewAll,
            onTap: () => Navigator.of(context).pop(#all),
          ),
          // Личное — первым: это контур, который не видит никто.
          if (uid.isNotEmpty)
            _Line(
              pair: _alone(uid),
              me: uid,
              on: store.space == uid,
              onTap: () => Navigator.of(context).pop(_alone(uid)),
            ),
          for (final p in _known)
            _Line(
              pair: p,
              me: uid,
              on: p.groupId == store.space,
              onTap: () => Navigator.of(context).pop(p),
            ),
        ]),
      ),
    );
    if (picked == null) return;
    if (picked == #all) {
      store.setViewAll(!store.viewAll);
      return;
    }
    if (picked is! Pair || picked.groupId == store.space) return;
    store.setViewAll(false);
    store.setPairChoice(picked.groupId);
    store.openSpace(picked);
    widget.onSwitched?.call();
  }

  /// Пары, между которыми выбирают. Пока список с сервера не приехал —
  /// открытая пара из базы: без сети чип просто исчезал из шапки, хотя пара
  /// есть (14.09.2026).
  List<Pair> get _known {
    if (_pairs.isNotEmpty) return _pairs;
    final open = widget.store.db.pair;
    return open.isPaired ? [open] : const [];
  }

  @override
  Widget build(BuildContext context) {
    // Чип нужен, когда есть между чем выбирать: своё личное плюс хотя бы одна
    // пара. У человека без пары выбора нет, и кнопки тоже.
    if (_known.isEmpty) return const SizedBox.shrink();
    // Смена пары перетекает: прежнее имя гаснет, новое проявляется. Подмена
    // за кадр не давала заметить, что выбор сработал.
    final space = widget.store.viewAll ? 'all' : widget.store.db.pair.groupId;
    return AnimatedSwitcher(
      duration: Motion.still(context) ? Duration.zero : Motion.state,
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(space), child: _chip(context)),
    );
  }

  Widget _chip(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = widget.session?.uid ?? widget.store.viewer;
    final other = widget.store.db.pair.other(me);
    if (widget.store.viewAll) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Text(
                  tr('spaceAll'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Myna.chevronDown,
                    size: 16, color: scheme.onSurface),
              ]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: _pick,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
            child: Row(children: [
              MemberBadge(member: other, size: 30, showName: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  other?.name ?? tr('spaceAlone'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Myna.chevronDown, size: 16, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Строка пары в листе выбора.
class _Line extends StatelessWidget {
  const _Line({
    required this.pair,
    required this.me,
    required this.on,
    required this.onTap,
  });

  final Pair pair;
  final String me;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final other = pair.other(me);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: on ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              MemberBadge(member: other, size: 32, showName: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      other?.name ?? tr('spaceAlone'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    // Дата начала различает пары с ОДНИМ человеком: старую
                    // группу в Togetherly часто бросают, не распуская, и в
                    // списке она стоит вторым таким же именем (13.09.2026).
                    if (pair.since.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          trf('spaceSince', [humanDay(pair.since)]),
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 12.5,
                            height: 1.1,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (on) Icon(Myna.check, size: 20, color: scheme.onSurface),
            ]),
          ),
        ),
      ),
    );
  }
}


/// Строка «Все пары» в листе выбора.
class _AllLine extends StatelessWidget {
  const _AllLine({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: on ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(Myna.grid, size: 22, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('spaceAll'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('spaceAllNote'),
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (on) Icon(Myna.check, size: 20, color: scheme.onSurface),
            ]),
          ),
        ),
      ),
    );
  }
}
