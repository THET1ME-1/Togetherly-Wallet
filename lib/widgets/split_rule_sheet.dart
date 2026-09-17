import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import 'member_badge.dart';
import '../design/myna.dart';

/// Как пара делит общие траты.
///
/// До этого листа правило «по доходу» было обманом: доли у всех стояли по 50%,
/// потому что задать их было негде, а расчёт при неверной сумме долей молча
/// отдавал всю трату плательщику.
Future<void> showSplitRule(BuildContext context, Store store) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _SplitRuleSheet(store: store),
    );

class _SplitRuleSheet extends StatefulWidget {
  const _SplitRuleSheet({required this.store});

  final Store store;

  @override
  State<_SplitRuleSheet> createState() => _SplitRuleSheetState();
}

class _SplitRuleSheetState extends State<_SplitRuleSheet> {
  late SplitMode _mode = widget.store.db.pair.defaultSplit;

  /// Доли в процентах, по человеку. Последний участник не правится: ему
  /// достаётся остаток, и сумма долей поэтому всегда ровно сто.
  late final Map<String, int> _percent = {
    for (final m in widget.store.db.pair.members) m.uid: (m.incomeShareBp / 100).round(),
  };

  List<Member> get _members => widget.store.db.pair.members;

  int get _takenByOthers {
    var sum = 0;
    for (final m in _members.take(_members.length - 1)) {
      sum += _percent[m.uid] ?? 0;
    }
    return sum;
  }

  int _shareOf(Member m) =>
      m.uid == _members.last.uid ? (100 - _takenByOthers) : (_percent[m.uid] ?? 0);

  void _save() {
    final bp = <String, int>{};
    for (final m in _members) {
      bp[m.uid] = _shareOf(m) * 100;
    }
    // Округление процентов не должно съесть базисный пункт: последнему
    // достаётся остаток от десяти тысяч.
    final sum = bp.values.fold<int>(0, (a, b) => a + b);
    if (sum != 10000 && _members.isNotEmpty) {
      bp[_members.last.uid] = bp[_members.last.uid]! + (10000 - sum);
    }
    widget.store.setSplitRule(_mode, shares: bp);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = widget.store;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr('splitRuleTitle'),
            style: TextStyle(
                fontFamily: AppTheme.displayFont, fontSize: 20, color: scheme.onSurface),
          ),
          SizedBox(height: 6),
          Text(
            tr('splitRuleDefault'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 16),
          // Сегменты в столбик: на 320 dp три слова в строку не влезают.
          for (final item in [
            (SplitMode.equal, tr('splitEqual'), tr('splitRuleEqual')),
            (SplitMode.income, tr('splitIncome'), tr('splitRuleIncome')),
            (SplitMode.payerOnly, tr('splitPayer'), tr('splitRulePayer')),
          ])
            _ModeRow(
              title: item.$2,
              note: item.$3,
              on: _mode == item.$1,
              onTap: () => setState(() => _mode = item.$1),
            ),
          if (_mode == SplitMode.income && _members.length > 1) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 14),
            for (final m in _members)
              _ShareRow(
                member: m,
                isMe: m.uid == store.viewer,
                percent: _shareOf(m),
                // Последнему остаётся остаток: так сумма долей не может
                // разойтись с сотней, и «доли не сходятся» человек не увидит.
                fixed: m.uid == _members.last.uid,
                onChange: (v) => setState(() {
                  final others = _takenByOthers - (_percent[m.uid] ?? 0);
                  _percent[m.uid] = v.clamp(0, 100 - others);
                }),
              ),
            SizedBox(height: 4),
            Text(
              tr('splitRuleLast'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 11.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: Text(tr('splitRuleSave'))),
          ),
        ]),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.title,
    required this.note,
    required this.on,
    required this.onTap,
  });

  final String title;
  final String note;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(
                on ? Myna.checkCircle : Myna.circle,
                size: 20,
                color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 12,
                      height: 1.35,
                      color: on ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.member,
    required this.isMe,
    required this.percent,
    required this.fixed,
    required this.onChange,
  });

  final Member member;
  final bool isMe;
  final int percent;
  final bool fixed;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MemberBadge(member: member, isMe: isMe),
          const Spacer(),
          Text(
            '$percent%',
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 16,
              color: scheme.onSurface,
            ),
          ),
        ]),
        if (!fixed)
          Slider(
            value: percent.toDouble(),
            min: 0,
            max: 100,
            // Шаг 5: доли вроде 37% пара не обсуждает, а точность слайдера
            // в один процент пальцем всё равно не берётся.
            divisions: 20,
            label: '$percent%',
            onChanged: (v) => onChange(v.round()),
          ),
      ]),
    );
  }
}
