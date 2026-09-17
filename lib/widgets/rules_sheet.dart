import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import 'amount_field.dart';
import '../design/app_theme.dart';
import '../logic/money.dart';

/// Правила обращения с деньгами: как делим доход, округляем ли покупки, когда
/// пересматриваем бюджет и что договорились про общий кошелёк.
///
/// Один разговор — один лист. Разбросать это по настройкам значило бы, что
/// правила никто никогда не увидит целиком.
Future<void> showRules(BuildContext context, Store store) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _RulesSheet(store: store),
    );

class _RulesSheet extends StatefulWidget {
  const _RulesSheet({required this.store});

  final Store store;

  @override
  State<_RulesSheet> createState() => _RulesSheetState();
}

class _RulesSheetState extends State<_RulesSheet> {
  late Rules _rules = widget.store.db.rules;
  late final TextEditingController _maxOnce = TextEditingController(
      text: widget.store.db.rules.potMaxOnce > 0
          ? formatAmount(widget.store.db.rules.potMaxOnce)
          : '');
  late final TextEditingController _bigSpend = TextEditingController(
      text: widget.store.db.rules.bigSpend > 0
          ? formatAmount(widget.store.db.rules.bigSpend)
          : '');

  @override
  void dispose() {
    _maxOnce.dispose();
    _bigSpend.dispose();
    super.dispose();
  }

  int get _needs => (_rules.needsBp / 100).round();
  int get _wants => (_rules.wantsBp / 100).round();
  int get _savings => 100 - _needs - _wants;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final db = widget.store.db;
    final goals = db.goals.map((g) => g.name).toList();
    final paired = db.pair.members.length > 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            tr('rulesTitle'),
            style: TextStyle(
                fontFamily: AppTheme.displayFont, fontSize: 20, color: scheme.onSurface),
          ),
          SizedBox(height: 16),

          _Head(text: tr('rulesSplitIncome')),
          Text(
            '${trf('rulesSplitNote', [
                  _needs,
                  _wants,
                  _savings
                ])} ${tr('rulesSplitAdvice')}',
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          _Share(
            title: tr('bucketNeeds'),
            percent: _needs,
            onChange: (v) => setState(() {
              final needs = v.clamp(0, 100 - _wants);
              _rules = _rules.copyWith(
                needsBp: needs * 100,
                savingsBp: (100 - needs - _wants) * 100,
              );
            }),
          ),
          _Share(
            title: tr('bucketWants'),
            percent: _wants,
            onChange: (v) => setState(() {
              final wants = v.clamp(0, 100 - _needs);
              _rules = _rules.copyWith(
                wantsBp: wants * 100,
                savingsBp: (100 - _needs - wants) * 100,
              );
            }),
          ),
          Row(children: [
            Expanded(
              child: Text(
                tr('bucketSavings'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '$_savings%',
              style: TextStyle(
                  fontFamily: AppTheme.displayFont, fontSize: 16, color: scheme.onSurface),
            ),
          ]),
          if (_needs + _wants > 100) ...[
            SizedBox(height: 6),
            Text(
              tr('rulesSplitOver'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                color: scheme.error,
              ),
            ),
          ],
          SizedBox(height: 20),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(height: 16),

          _Head(text: tr('rulesRoundUp')),
          Text(
            tr('rulesRoundUpNote'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final step in [0, 10, 50, 100])
              ChoiceChip(
                label: Text(step == 0 ? tr('rulesRoundUpNone') : trf('rulesRoundUpTo', [step])),
                selected: _rules.roundUpStep == step,
                onSelected: (_) => setState(() => _rules = _rules.copyWith(roundUpStep: step)),
              ),
          ]),
          if (_rules.roundUpStep > 0) ...[
            SizedBox(height: 10),
            if (goals.isEmpty)
              Text(
                tr('rulesRoundUpNeedGoal'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  color: scheme.error,
                ),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final g in goals)
                  ChoiceChip(
                    label: Text(g),
                    selected: _rules.roundUpGoal == g,
                    onSelected: (_) => setState(() => _rules = _rules.copyWith(roundUpGoal: g)),
                  ),
              ]),
          ],
          SizedBox(height: 20),
          Divider(height: 1, color: scheme.outlineVariant),
          SizedBox(height: 16),

          _Head(text: tr('rulesReview')),
          Text(
            tr('rulesReviewNote'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in [
              (0, tr('rulesReviewNever')),
              (1, tr('rulesReviewMonth')),
              (3, tr('rulesReviewQuarter')),
              (6, tr('rulesReviewHalfYear')),
            ])
              ChoiceChip(
                label: Text(item.$2),
                selected: _rules.reviewMonths == item.$1,
                onSelected: (_) =>
                    setState(() => _rules = _rules.copyWith(reviewMonths: item.$1)),
              ),
          ]),

          if (paired) ...[
            SizedBox(height: 20),
            Divider(height: 1, color: scheme.outlineVariant),
            SizedBox(height: 16),
            _Head(text: tr('rulesPot')),
            Text(
              tr('rulesPotWhy'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _rules.potNotice,
              onChanged: (v) => setState(() => _rules = _rules.copyWith(potNotice: v)),
              title: Text(
                tr('rulesPotWarn'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 15,
                  color: scheme.onSurface,
                ),
              ),
              subtitle: Text(
                tr('rulesPotWarnNote'),
                style: TextStyle(
                  fontFamily: AppTheme.bodyFont,
                  fontSize: 12.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            // Подпись стоит СТРОКОЙ над полем: тема гасит `labelText`
            // намертво, и поле с валютой выглядело безымянным.
            _FieldLabel(trf('rulesPotMax', [db.baseCurrency])),
            AmountField(
              controller: _maxOnce,
              currency: db.baseCurrency,
              hint: tr('rulesEmptyOk'),
            ),
            const SizedBox(height: 12),
            // Договорённость про ЛЮБОЙ счёт, а не только про общий кошелёк:
            // «покупки дороже пяти тысяч обсуждаем заранее».
            _FieldLabel(trf('rulesBigSpend', [db.baseCurrency])),
            AmountField(
              controller: _bigSpend,
              currency: db.baseCurrency,
              hint: tr('rulesEmptyOk'),
            ),
            const SizedBox(height: 6),
            Text(
              tr('rulesBigSpendNote'),
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: Text(tr('rulesSave'))),
          ),
        ]),
      ),
    );
  }

  void _save() {
    final next = _rules.copyWith(
      potMaxOnce: parseAmount(_maxOnce.text) ?? 0,
      bigSpend: parseAmount(_bigSpend.text) ?? 0,
      // Округление без цели бессмысленно: гасим шаг, а не оставляем правило,
      // которое ничего не делает.
      roundUpStep: _rules.roundUpGoal.isEmpty ? 0 : _rules.roundUpStep,
    );
    widget.store.setRules(next);
    Navigator.of(context).pop();
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
}

class _Share extends StatelessWidget {
  const _Share({required this.title, required this.percent, required this.onChange});

  final String title;
  final int percent;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
              fontFamily: AppTheme.displayFont, fontSize: 16, color: scheme.onSurface),
        ),
      ]),
      Slider(
        value: percent.toDouble(),
        min: 0,
        max: 100,
        divisions: 20,
        label: '$percent%',
        onChanged: (v) => onChange(v.round()),
      ),
    ]);
  }
}


/// Подпись поля строкой над ним.
///
/// `labelText` в этом приложении не виден никогда: тема ставит
/// `floatingLabelBehavior: never`, потому что заливка с рамкой режет под
/// плавающую подпись щель, которой нет. Поле с валютой из-за этого выглядело
/// безымянным — человек не понимал, в чём вводит сумму.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
}
