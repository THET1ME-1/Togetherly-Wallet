import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/language.dart';
import '../l10n/strings.dart';
import '../logic/currencies.dart';

/// Выбор валюты поиском.
///
/// До 13.09.2026 валюты стояли девятью пилюлями, и десятая добавлялась полем
/// на три буквы: «даже поиска не сделал».
Future<String?> pickCurrency(
  BuildContext context, {
  String? current,

  /// Валюты, которые уже в ходу: они идут первыми, ещё до поиска.
  List<String> mine = const [],
}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => CurrencyPickScreen(current: current, mine: mine),
    ));

class CurrencyPickScreen extends StatefulWidget {
  const CurrencyPickScreen({super.key, this.current, this.mine = const []});

  final String? current;
  final List<String> mine;

  @override
  State<CurrencyPickScreen> createState() => _CurrencyPickScreenState();
}

class _CurrencyPickScreenState extends State<CurrencyPickScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final russian = appLanguage == MoneyLanguage.ru;
    final q = _query.text.trim();
    final found = searchCurrencies(q, russian: russian);

    // Свои валюты сверху, но только пока человек не начал искать: в поиске
    // важен порядок совпадений, а не привычка.
    final mine = q.isEmpty
        ? widget.mine
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
        : const <String>[];
    final rest = found.where((c) => !mine.contains(c.code)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(tr('currencyPickTitle'))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr('currencyPickSearch'),
              prefixIcon: const Icon(Myna.search, size: 20),
              filled: true,
              fillColor: scheme.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              for (final code in mine)
                _Row(
                  code: code,
                  name: currencyName(code, russian: russian),
                  on: code == widget.current,
                  onTap: () => Navigator.of(context).pop(code),
                ),
              if (mine.isNotEmpty) const SizedBox(height: 10),
              for (final c in rest)
                _Row(
                  code: c.code,
                  name: russian ? c.ru : c.en,
                  on: c.code == widget.current,
                  onTap: () => Navigator.of(context).pop(c.code),
                ),
              // Своя валюта кодом: в справочнике нет всего на свете, а
              // трёхбуквенный код принимает и сервер.
              if (rest.isEmpty && q.length == 3)
                _Row(
                  code: q.toUpperCase(),
                  name: tr('currencyPickOwn'),
                  on: false,
                  onTap: () => Navigator.of(context).pop(q.toUpperCase()),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.code,
    required this.name,
    required this.on,
    required this.onTap,
  });

  final String code;
  final String name;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: on ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Text(flagOf(code), style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                child: Text(
                  code,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                  ),
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
