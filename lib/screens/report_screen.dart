import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/period.dart';
import '../logic/plus.dart';
import '../logic/stats.dart';
import '../services/plus.dart';
import '../services/report.dart';
import '../services/session.dart';
import '../widgets/form_screen.dart';
import '../widgets/pick_row.dart';
import '../widgets/plus_gate.dart';
import '../widgets/settings_kit.dart';

/// Отчёт за период файлом.
///
/// Экран отвечает на три вопроса и ни на один лишний: за какой отрезок, чьи
/// деньги и чем открывать. Всё остальное решено за человека — что попадёт в
/// отчёт, в каком порядке и как выглядит, — потому что выбор здесь не делает
/// отчёт лучше, а делает экран длиннее.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.store,
    required this.session,
    this.plus,
  });

  final Store store;
  final Session session;
  final PlusService? plus;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late Period _period = Period.month(DateTime.now());
  ReportFormat _format = ReportFormat.pdf;
  MoneyScope _scope = MoneyScope.all;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paired = widget.store.db.pair.members.length > 1;

    return FormScreen(
      title: tr('reportTitle'),
      action: _busy ? tr('reportBuilding') : tr('reportBuild'),
      onAction: _busy ? null : _build,
      children: [
        SettingsSection(tr('reportPeriod'), icon: Myna.calendar),
        SettingsGroup([
          SettingsBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PickRow(
                  height: 40,
                  children: [
                    for (final p in _periods())
                      ChoiceChip(
                        label: Text(p.label),
                        selected: _period.kind == p.kind &&
                            _period.anchor.month == p.anchor.month &&
                            _period.anchor.year == p.anchor.year,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _period = p),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]),
        // Разрез спрашивается только у пары: одиночке выбирать не из чего, и
        // ряд из одной пилюли читался бы поломкой.
        if (paired) ...[
          const SizedBox(height: 14),
          SettingsSection(tr('reportScope'), icon: Myna.users),
          SettingsGroup([
            SettingsBlock(
              child: PickRow(
                height: 40,
                children: [
                  for (final s in MoneyScope.values)
                    ChoiceChip(
                      label: Text(_scopeTitle(s)),
                      selected: _scope == s,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _scope = s),
                    ),
                ],
              ),
            ),
          ]),
        ],
        const SizedBox(height: 14),
        SettingsSection(tr('reportFormat'), icon: Myna.fileText),
        SettingsGroup([
          SettingsRow(
            icon: Myna.fileText,
            title: tr('reportFormatPdf'),
            subtitle: tr('reportFormatPdfNote'),
            trailing: _format == ReportFormat.pdf
                ? Icon(Myna.checkCircle, size: 20, color: scheme.onSurface)
                : null,
            onTap: () => setState(() => _format = ReportFormat.pdf),
          ),
          SettingsRow(
            icon: Myna.grid,
            title: tr('reportFormatXlsx'),
            subtitle: tr('reportFormatXlsxNote'),
            trailing: _format == ReportFormat.xlsx
                ? Icon(Myna.checkCircle, size: 20, color: scheme.onSurface)
                : null,
            onTap: () => setState(() => _format = ReportFormat.xlsx),
          ),
        ]),
        const SizedBox(height: 14),
        // Выгрузка базы бесплатна всегда, и об этом сказано прямо на экране
        // платной функции: трекер, который держит записи в заложниках, второй
        // раз никому не продашь.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            tr('reportFreeNote'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 12.5,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }


  /// Отрезки на выбор: этот месяц, прошлый, год и всё время. Барабан здесь не
  /// нужен — отчёт берут за понятный кусок, а не за «с 3 по 17 мая».
  List<Period> _periods() {
    final now = DateTime.now();
    return [
      Period.month(now),
      Period.month(DateTime(now.year, now.month - 1)),
      Period(PeriodKind.year, now),
      Period(PeriodKind.all, now),
    ];
  }

  String _scopeTitle(MoneyScope s) => switch (s) {
        MoneyScope.all => tr('statsScopeAll'),
        MoneyScope.shared => tr('statsScopeShared'),
        MoneyScope.mine => tr('statsScopeMine'),
      };

  Future<void> _build() async {
    if (!await askPlus(context, plus: widget.plus, gate: PlusGate.report)) {
      return;
    }
    if (!mounted) return;

    setState(() => _busy = true);
    final result = await ReportService(session: widget.session).build(
      db: widget.store.view,
      period: _period,
      format: _format,
      filter: Filter(scope: _scope, viewer: widget.store.viewer),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    final file = result.file;
    if (file == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.error)));
      return;
    }
    await Share.shareXFiles([XFile(file.path)]);
  }
}
