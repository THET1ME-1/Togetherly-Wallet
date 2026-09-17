import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/strings.dart';
import '../logic/period.dart';
import '../logic/plus.dart';
import '../services/plus.dart';
import '../services/snapshots.dart';
import '../widgets/app_sheet.dart';
import '../widgets/plus_gate.dart';
import '../widgets/settings_kit.dart';

/// Возврат к любому дню.
///
/// Экран из двух состояний. Пока фразы нет — объяснение и одна кнопка:
/// человек должен узнать про фразу ДО первого снимка, а не после потери
/// телефона. Когда фраза есть — список дней, где каждый день открывается
/// одним касанием.
class SnapshotsScreen extends StatefulWidget {
  const SnapshotsScreen({super.key, required this.service, this.plus});

  final SnapshotService service;
  final PlusService? plus;

  @override
  State<SnapshotsScreen> createState() => _SnapshotsScreenState();
}

class _SnapshotsScreenState extends State<SnapshotsScreen> {
  @override
  void initState() {
    super.initState();
    widget.service.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final service = widget.service;
        return Scaffold(
          appBar: AppBar(title: Text(tr('snapshotTitle'))),
          body: RefreshIndicator(
            onRefresh: service.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                if (!service.ready)
                  _Intro(onStart: _start)
                else ...[
                  SettingsSection(tr('snapshotKeySection'), icon: Myna.key),
                  SettingsGroup([
                    SettingsRow(
                      icon: Myna.key,
                      title: tr('snapshotPhraseRow'),
                      subtitle: tr('snapshotPhraseNote'),
                      trailing: const SettingsChevron(),
                      onTap: () => _showPhrase(service.phrase),
                    ),
                  ]),
                  SettingsSection(
                    tr('snapshotDaysSection'),
                    icon: Myna.archive,
                    trailing: service.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                  if (service.days.isEmpty)
                    SettingsGroup([
                      SettingsRow(
                        icon: Myna.clock12,
                        title: tr('snapshotEmpty'),
                        subtitle: tr('snapshotEmptyNote'),
                        onTap: () => service.push(),
                      ),
                    ])
                  else
                    SettingsGroup([
                      for (final day in service.days)
                        SettingsRow(
                          icon: Myna.archive,
                          title: _dayTitle(day.day),
                          subtitle: trf('snapshotSize',
                              ['${(day.size / 1024).round()}']),
                          trailing: const SettingsChevron(),
                          onTap: () => _restore(day.day),
                        ),
                    ]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Подпись дня в списке: «Сегодня» или «15 сентября 2026».
  ///
  /// С заглавной буквы — правило приложения; ключ `today` живёт строчным,
  /// потому что в других местах он стоит в середине фразы.
  String _dayTitle(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return iso;
    final today = DateTime.now();
    if (at.year == today.year && at.month == today.month && at.day == today.day) {
      final word = tr('today');
      return word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
    }
    return humanDay(iso);
  }

  Future<void> _start() async {
    if (!await askPlus(context, plus: widget.plus, gate: PlusGate.cloudBackups)) {
      return;
    }
    final phrase = await widget.service.start();
    if (!mounted) return;
    await _showPhrase(phrase, first: true);
    await widget.service.push();
  }

  /// Показать фразу. Первый раз — с объяснением, дальше — по просьбе.
  Future<void> _showPhrase(List<String> phrase, {bool first = false}) async {
    await showMoneySheet<void>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.key,
        title: tr('snapshotPhraseTitle'),
        text: tr('snapshotPhraseWarn'),
        action: tr('snapshotPhraseCopy'),
        onAction: () {
          Clipboard.setData(ClipboardData(text: phrase.join(' ')));
          Navigator.of(context).pop();
        },
        cancel: first ? tr('snapshotPhraseWrote') : tr('close'),
        child: _PhraseBox(phrase: phrase),
      ),
    );
  }

  Future<void> _restore(String day) async {
    final yes = await showMoneySheet<bool>(
      context,
      builder: (context) => SheetScaffold(
        icon: Myna.archive,
        tone: Theme.of(context).colorScheme.error,
        // В заголовке всегда ДАТА, а не «сегодня»: «Вернуться к сегодня»
        // читается сломанной фразой, а падеж у дат сходится всегда.
        title: trf('snapshotRestoreTitle', [humanDay(day)]),
        text: tr('snapshotRestoreText'),
        action: tr('snapshotRestore'),
        onAction: () => Navigator.of(context).pop(true),
      ),
    );
    if (yes != true || !mounted) return;

    final problem = await widget.service.restore(day);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(problem.isEmpty ? tr('snapshotRestored') : problem),
    ));
  }
}

/// Фраза словами: шесть блоков с номерами.
///
/// Номера нужны не для красоты — человек переписывает фразу рукой, и порядок
/// слов здесь единственное, что нельзя перепутать.
class _PhraseBox extends StatelessWidget {
  const _PhraseBox({required this.phrase});

  final List<String> phrase;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < phrase.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  phrase[i],
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 28, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Myna.archive, size: 27, color: scheme.onSurface),
          ),
          const SizedBox(height: 18),
          Text(
            tr('snapshotIntroTitle'),
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            tr('snapshotIntroText'),
            style: TextStyle(
              fontFamily: AppTheme.bodyFont,
              fontSize: 15,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          // Про фразу сказано ДО первого снимка и отдельным блоком, а не
          // сноской: это единственная цена, которую человек платит за то, что
          // сервер не может прочитать его деньги.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Myna.key, size: 18, color: scheme.onSurface),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('snapshotIntroKey'),
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13.5,
                      height: 1.45,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onStart,
              child: Text(tr('snapshotStart')),
            ),
          ),
        ],
      ),
    );
  }
}
