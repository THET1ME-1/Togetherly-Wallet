import 'package:flutter/material.dart';

import '../data/store.dart';
import '../l10n/strings.dart';
import '../design/app_theme.dart';
import '../design/myna.dart';
import '../l10n/language.dart';
import '../logic/currencies.dart';
import '../logic/money.dart';
import '../services/session.dart';
import '../widgets/converter_card.dart';
import '../widgets/settings_kit.dart';
import 'currency_pick_screen.dart';

/// Базовая валюта и курсы.
///
/// До этого листа задать их было НЕГДЕ: приложение молча жило на лее, и пара в
/// России видела свои рубли, пересчитанные один к одному. Курс здесь означает
/// одно: сколько базовой валюты стоит единица чужой.
///
/// Курсы тянет сервер: у открытого источника нет ключа, запрос кэшируется на
/// всех, и устройству не нужно ходить к третьей стороне самому.
Future<void> showCurrencySheet(
  BuildContext context, {
  required Store store,
  Session? session,
}) =>
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => CurrencyScreen(store: store, session: session),
    ));

/// Валюта и курсы — ЭКРАН.
///
/// Листом это был попап в полный экран с полями курсов, которые уезжают под
/// клавиатуру: «зачем они попапы, делай экраны полноценные» (13.09.2026).

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key, required this.store, this.session});

  final Store store;
  final Session? session;

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  final Map<String, TextEditingController> _fields = {};

  /// Конвертер сверху: сумма, из чего и во что. Он и есть ответ на вопрос,
  /// ради которого экран открывают.
  final _sum = TextEditingController(text: '1');
  String? _from;
  String? _to;

  bool _busy = false;
  String? _note;

  @override
  void dispose() {
    _sum.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Поле курса живёт ровно столько, сколько валюта в списке.
  TextEditingController _field(String code, double? value) =>
      _fields.putIfAbsent(
        code,
        () => TextEditingController(
          text: value == null ? '' : formatAmount(value, decimals: 4),
        ),
      );

  List<String> get _codes {
    final db = widget.store.db;
    final codes = <String>{
      ...widget.store.currenciesInUse,
      ...db.rates.keys,
    }..removeWhere((c) => c.isEmpty || c == db.baseCurrency);
    final list = codes.toList()..sort();
    return list;
  }

  Future<void> _refreshRates() async {
    final session = widget.session;
    if (session == null || !session.signedIn) {
      setState(() => _note = tr('currencyNeedAccount'));
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final base = widget.store.db.baseCurrency;
      final r = await session.get('/api/money/rates?base=$base');
      final table = (r['rates'] as Map?) ?? const {};
      final next = <String, double>{};
      // Берём только те валюты, которыми человек пользуется: полная таблица
      // из полутора сотен строк в настройках бесполезна.
      for (final code in _codes) {
        final value = (table[code] as num?)?.toDouble();
        if (value != null && value > 0) next[code] = value;
      }
      widget.store.setRates(next, source: '${r['source'] ?? ''}');
      for (final e in next.entries) {
        _fields[e.key]?.text = formatAmount(e.value, decimals: 4);
      }
      if (!mounted) return;
      setState(() => _note = next.isEmpty
          ? tr('currencyNoServer')
          : r['stale'] == true
              ? tr('currencyStale')
              : tr('currencyUpdated'));
    } on SessionError catch (e) {
      if (mounted) setState(() => _note = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCurrency() async {
    final code = await pickCurrency(
      context,
      mine: [widget.store.db.baseCurrency, ..._codes],
    );
    if (code == null || code == widget.store.db.baseCurrency) return;
    widget.store.setRate(code, widget.store.db.rates[code] ?? 1);
    setState(() {});
  }

  Future<void> _pickBase() async {
    final code = await pickCurrency(
      context,
      current: widget.store.db.baseCurrency,
      mine: [widget.store.db.baseCurrency, ..._codes],
    );
    if (code == null) return;
    widget.store.setBaseCurrency(code);
    setState(() {});
  }

  Future<void> _pickSide({required bool left}) async {
    final store = widget.store;
    final code = await pickCurrency(
      context,
      current: left ? (_from ?? store.db.baseCurrency) : (_to ?? _otherSide()),
      mine: [store.db.baseCurrency, ..._codes],
    );
    if (code == null) return;
    setState(() {
      if (left) {
        _from = code;
      } else {
        _to = code;
      }
      // Обе стороны одинаковыми быть не могут: пересчёт из леев в леи ответа
      // не содержит.
      if (_from == _to) {
        if (left) {
          _to = store.db.baseCurrency == code ? _codes.firstOrNull ?? code : store.db.baseCurrency;
        } else {
          _from = store.db.baseCurrency == code ? _codes.firstOrNull ?? code : store.db.baseCurrency;
        }
      }
    });
  }

  /// Вторая сторона по умолчанию: первая чужая валюта, а если их нет — базовая.
  String _otherSide() {
    final codes = _codes;
    return codes.isEmpty ? widget.store.db.baseCurrency : codes.first;
  }

  /// Сколько единиц базовой стоит одна единица [code].
  double _rate(String code) {
    if (code == widget.store.db.baseCurrency) return 1;
    final r = widget.store.db.rates[code];
    return r == null || r <= 0 ? 0 : r;
  }

  @override
  Widget build(BuildContext context) =>
      // Лист слушает хранилище: курс вводят в поле, а подпись под ним считает
      // обратный курс — без подписки она оставалась от прежнего значения.
      ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => _body(context),
      );

  Widget _body(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = widget.store;
    final base = store.db.baseCurrency;
    final codes = _codes;

    final from = _from ?? base;
    final to = _to ?? _otherSide();
    final sum = parseAmount(_sum.text) ?? 0;
    final rateFrom = _rate(from);
    final rateTo = _rate(to);
    final result =
        rateFrom <= 0 || rateTo <= 0 ? null : sum * rateFrom / rateTo;

    return Scaffold(
      appBar: AppBar(title: Text(tr('currencyTitle'))),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy ? null : _refreshRates,
            icon: Icon(_busy ? Myna.clockCircle : Myna.refresh, size: 20),
            label: Text(_busy ? tr('currencyAsking') : tr('currencyRefresh')),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          ConverterCard(
            controller: _sum,
            from: from,
            to: to,
            result: result,
            note: rateFrom <= 0 || rateTo <= 0
                ? tr('currencyRateMissing')
                : '1 $from = ${formatAmount(rateFrom / rateTo, decimals: 4)} $to',
            onFrom: () => _pickSide(left: true),
            onTo: () => _pickSide(left: false),
            onSwap: () => setState(() {
              _from = to;
              _to = from;
            }),
            onChanged: (_) => setState(() {}),
          ),

          SettingsSection(tr('currencyBase'), icon: Myna.dollarSquare),
          SettingsGroup([
            SettingsRow(
              key: const ValueKey('base-row'),
              icon: Myna.pocket,
              title: '${flagOf(base)}  $base',
              subtitle: currencyName(base,
                  russian: appLanguage == MoneyLanguage.ru),
              trailing: const SettingsChevron(),
              onTap: _pickBase,
            ),
          ]),

          SettingsSection(trf('currencyRates', [base]), icon: Myna.chartLine),
          SettingsGroup([
            if (codes.isEmpty)
              SettingsBlock(
                child: Text(
                  tr('currencyNoOthers'),
                  style: TextStyle(
                    fontFamily: AppTheme.bodyFont,
                    fontSize: 13,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final code in codes)
              SettingsBlock(
                child: Row(children: [
                  Text(flagOf(code), style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '1 $code',
                      style: TextStyle(
                        fontFamily: AppTheme.bodyFont,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SettingsInput(
                          key: ValueKey('rate-$code'),
                          controller: _field(code, store.db.rates[code]),
                          hint: '0',
                          capitalize: false,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (v) => store.setRate(code, parseAmount(v)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _line(store, code, base) ?? '',
                          style: TextStyle(
                            fontFamily: AppTheme.bodyFont,
                            fontSize: 11.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    base,
                    style: TextStyle(
                      fontFamily: AppTheme.bodyFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ]),
              ),
            SettingsRow(
              key: const ValueKey('add-currency'),
              icon: Myna.plus,
              title: tr('currencyAdd'),
              trailing: const SettingsChevron(),
              onTap: _addCurrency,
            ),
          ]),
          // Откуда курс — видно всегда, а не только сразу после обновления:
          // человек должен знать, что считает Нацбанк, а не приложение.
          if (store.ratesSource.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${trf('currencySource', [store.ratesSource])}'
              '${store.ratesAt == null ? '' : ' · ${_day(store.ratesAt!)}'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              _note!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.bodyFont,
                fontSize: 12.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }


  /// День обновления курсов по-человечески.
  static String _day(DateTime at) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    return switch (days) {
      0 => tr('today'),
      1 => tr('yesterday'),
      _ => '${at.day.toString().padLeft(2, '0')}.'
          '${at.month.toString().padLeft(2, '0')}.${at.year}',
    };
  }

  /// Подпись под полем: обратный курс. «1 MDL = 0,056 USD» — так человек
  /// проверяет, не перевёрнут ли курс.
  static String? _line(Store store, String code, String base) {
    final rate = store.db.rates[code];
    if (rate == null || rate <= 0) return tr('currencyRateMissing');
    return '1 $base = ${formatAmount(1 / rate, decimals: 4)} $code';
  }
}
