import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../data/models.dart';
import '../l10n/strings.dart';
import '../logic/period.dart';
import '../logic/stats.dart';
import 'session.dart';

/// Отчёт за период файлом.
///
/// Числа собирает ПРИЛОЖЕНИЕ теми же функциями, которыми рисует экран
/// статистики (`cashflow`, `byCategory`, `visible`), и отправляет готовыми.
/// Пересчёт на сервере вторым кодом разошёлся бы с экраном на первом же курсе
/// валюты, а отчёт, который спорит с приложением, хуже отсутствия отчёта.
///
/// Верстает сервер: правка вёрстки доезжает до человека в тот же час, а не
/// через неделю ревью магазина, и одинаково на обеих платформах.
enum ReportFormat { pdf, xlsx, csv }

String reportFormatName(ReportFormat f) => switch (f) {
      ReportFormat.pdf => 'pdf',
      ReportFormat.xlsx => 'xlsx',
      ReportFormat.csv => 'csv',
    };

class ReportResult {
  const ReportResult({this.file, this.error = ''});

  final File? file;

  /// Что сказать человеку. Пусто — всё вышло.
  final String error;

  bool get ok => file != null;
}

class ReportService {
  ReportService({required this.session});

  final Session session;

  /// Собрать отчёт и положить файлом рядом с базой.
  Future<ReportResult> build({
    required Database db,
    required Period period,
    required ReportFormat format,
    Filter filter = const Filter(),
  }) async {
    if (!session.signedIn) return ReportResult(error: tr('reportNeedAccount'));

    final flow = cashflow(db, period, filter: filter);
    final slices = byCategory(db, period, income: false, filter: filter);
    final rows = visible(db, period, filter: filter);

    final body = <String, dynamic>{
      'format': reportFormatName(format),
      'title': '${tr('reportTitle')} · ${period.label}',
      'subtitle': _subtitle(db, filter),
      'currency': db.baseCurrency,
      'totals': {
        'income': flow.income,
        'expense': flow.expense,
        'net': flow.total,
      },
      'categories': [
        for (final s in slices) {'name': s.name, 'amount': s.sum},
      ],
      'rows': [
        for (final t in rows)
          {
            'date': t.date,
            'category': [
              if ((t.category ?? '').isNotEmpty) t.category,
              if ((t.subcategory ?? '').isNotEmpty) t.subcategory,
            ].join(' · '),
            'account': t.account,
            'note': t.note ?? '',
            'amount': t.amount,
            'currency': t.currency,
          },
      ],
      // Слова отчёта приезжают с телефона: сервер не знает, на каком языке
      // человек читает приложение, а семь языков в нём уже есть.
      'wordIncome': tr('statsIncome'),
      'wordExpense': tr('statsSpending'),
      'wordNet': tr('statsNet'),
      'wordCategories': tr('reportCategories'),
      'wordOperations': tr('reportOperations'),
      'wordSummary': tr('reportSummary'),
      'wordDate': tr('reportDate'),
      'wordCategory': tr('reportCategory'),
      'wordAccount': tr('reportAccount'),
      'wordNote': tr('reportNote'),
      'wordAmount': tr('reportAmount'),
      'wordCurrency': tr('reportCurrency'),
      'wordMoreRows': tr('reportMoreRows'),
    };

    try {
      // Отчёт за год — это тысячи строк и вёрстка сотни страниц: двадцати
      // секунд общего срока тут мало.
      final r = await session.post(
        '/api/money/report',
        body,
        timeout: const Duration(seconds: 120),
      );
      if (r['ok'] != true) {
        return ReportResult(
            error: '${r['message'] ?? tr('reportFailed')}');
      }
      final blob = base64Decode('${r['file'] ?? ''}');
      final dir = await getTemporaryDirectory();
      final name = _fileName(period, format);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(blob, flush: true);
      return ReportResult(file: file);
    } on SessionError catch (e) {
      // Подписка кончилась или её не было: сервер отвечает 402, и человеку
      // надо сказать это словами, а не «не получилось».
      return ReportResult(
          error: e.needPlus ? tr('reportNeedPlus') : e.message);
    } catch (_) {
      return ReportResult(error: tr('reportFailed'));
    }
  }

  String _subtitle(Database db, Filter filter) {
    final parts = <String>[];
    final pair = db.pair;
    if (pair.members.length > 1) parts.add(pair.members.map((m) => m.name).join(' · '));
    return parts.join(' · ');
  }

  String _fileName(Period period, ReportFormat format) {
    final at = period.anchor;
    final stamp = '${at.year}-${at.month.toString().padLeft(2, '0')}';
    return 'wallet-$stamp.${reportFormatName(format)}';
  }
}
