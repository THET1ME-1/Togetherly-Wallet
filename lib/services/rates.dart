import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/store.dart';
import 'session.dart';

/// Курсы валют: тянутся сами.
///
/// До 13.09.2026 их приходилось обновлять вручную кнопкой в настройках, а до
/// первого нажатия чужая валюта считалась один к одному: человек записал
/// зарплату в долларах и увидел «USD 1 500,00 ≈ MDL 1 500,00 по текущему
/// курсу» — «почему не работает конвертация».
class Rates {
  Rates(this.store, this.session);

  final Store store;
  final Session? session;

  /// Раз в сутки: курсы Нацбанка меняются раз в день, а чаще ходить к серверу
  /// незачем — он всё равно отдаёт свой кэш.
  static const _ttl = Duration(hours: 20);

  bool _busy = false;

  /// Обновить, если пора или если у какой-то валюты курса нет вовсе.
  ///
  /// Входа НЕ требует: курс — общее знание, и маршрут на сервере открыт. Без
  /// этого человек, записавший зарплату в долларах до входа, видел «USD
  /// 1 500,00 ≈ MDL 1 500,00».
  Future<void> refreshIfStale() async {
    if (_busy) return;

    final need = store.currenciesInUse
        .where((c) => (store.db.rates[c] ?? 0) <= 0)
        .toList();
    final at = store.ratesAt;
    final stale = at == null || DateTime.now().difference(at) > _ttl;
    if (need.isEmpty && !stale) return;
    // Курс нужен только тому, чем человек пользуется: полная таблица на
    // полторы сотни валют в настройках бесполезна.
    if (store.currenciesInUse.isEmpty) return;

    _busy = true;
    try {
      final base = store.db.baseCurrency;
      final r = await _ask(base);
      final table = (r['rates'] as Map?) ?? const {};
      final next = <String, double>{};
      for (final code in store.currenciesInUse) {
        final value = (table[code] as num?)?.toDouble();
        if (value != null && value > 0) next[code] = value;
      }
      if (next.isNotEmpty) {
        store.setRates(next, source: '${r['source'] ?? ''}');
      }
    } catch (_) {
      // Молчим: сеть бывает мёртвой, а в приложении лежит встроенная таблица —
      // курс есть всегда, просто не самый свежий.
    } finally {
      _busy = false;
    }
  }
}

extension on Rates {
  /// Спросить курсы. Со своей сессией — её каналом (там уже есть повторы и
  /// таймауты), без неё — обычным запросом: маршрут открытый.
  Future<Map<String, dynamic>> _ask(String base) async {
    final ses = session;
    final path = '/api/money/rates?base=$base';
    if (ses != null && ses.signedIn) return ses.get(path);
    final r = await http
        .get(Uri.parse('$kApiBase$path'))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return const {};
    return (jsonDecode(r.body) as Map).cast<String, dynamic>();
  }
}
