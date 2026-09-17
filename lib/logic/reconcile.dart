import '../data/models.dart';

/// Сверка своих записей с выпиской.
///
/// Человек ведёт траты руками, а раз в месяц кидает выписку или снимок чека.
/// Записать всё заново — получить дубли; не записывать — потерять то, чего в
/// приложении нет. Поэтому мы СОПОСТАВЛЯЕМ: совпавшую запись дополняем
/// временем, датой и описанием из файла, недостающую заводим, а свою лишнюю не
/// трогаем вовсе — её могли записать наличными, и банк о ней не знает.

/// Строка из разобранного файла.
class ImportedRow {
  final String date;
  final String time;
  final double amount;
  final String currency;
  final String note;
  final bool income;

  const ImportedRow({
    required this.date,
    required this.amount,
    this.time = '',
    this.currency = '',
    this.note = '',
    this.income = false,
  });

  factory ImportedRow.fromJson(Map<String, dynamic> j) => ImportedRow(
        date: '${j['date'] ?? ''}',
        time: '${j['time'] ?? ''}',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        currency: '${j['currency'] ?? ''}',
        note: '${j['note'] ?? ''}',
        income: '${j['kind']}' == 'income',
      );
}

/// Пара «моя запись — строка файла» и то, что из этого вышло.
class Matched {
  final Transaction was;
  final Transaction fixed;
  final ImportedRow row;

  const Matched({required this.was, required this.fixed, required this.row});

  /// Правка что-то изменила. Записи без изменений трогать незачем: лишняя
  /// правка — это лишняя строка в очереди отправки и у партнёра.
  bool get changed =>
      was.date != fixed.date ||
      (was.time ?? '') != (fixed.time ?? '') ||
      (was.note ?? '') != (fixed.note ?? '');
}

/// Итог сверки.
class Reconciled {
  final List<Matched> matched;
  final List<ImportedRow> onlyFile;
  final List<Transaction> onlyApp;

  const Reconciled({
    required this.matched,
    required this.onlyFile,
    required this.onlyApp,
  });

  /// Сколько записей поправлено по файлу.
  int get fixedCount => matched.where((m) => m.changed).length;
}

/// Сопоставить свои записи с выпиской.
///
/// [slack] — на сколько дней банк имеет право опоздать: покупка сегодня, а в
/// выписке завтра — обычное дело, и такие записи обязаны сойтись.
///
/// Перебором это не считается. У человека за годы набирается десять тысяч
/// записей, и сравнивать каждую с каждой строкой файла — сорок миллионов
/// проверок на телефоне. Поэтому:
///
///  * берём ТОЛЬКО окно дат самого файла плюс допуск — выписка за сентябрь
///    ничего не говорит о прошлогодних тратах, и «лишними» они не являются;
///  * в окне строим указатель «сторона + сумма + валюта → записи», и поиск
///    становится мгновенным независимо от того, сколько всего записей.
Reconciled reconcile(
  List<Transaction> mine,
  List<ImportedRow> theirs, {
  int slack = 3,
}) {
  if (theirs.isEmpty) {
    return const Reconciled(matched: [], onlyFile: [], onlyApp: []);
  }

  // Окно дат файла с допуском по краям.
  DateTime? from;
  DateTime? to;
  for (final row in theirs) {
    final at = DateTime.tryParse(row.date);
    if (at == null) continue;
    if (from == null || at.isBefore(from)) from = at;
    if (to == null || at.isAfter(to)) to = at;
  }
  final left = from?.subtract(Duration(days: slack));
  final right = to?.add(Duration(days: slack));

  final window = <Transaction>[];
  for (final tx in mine) {
    if (left == null || right == null) {
      window.add(tx);
      continue;
    }
    final at = DateTime.tryParse(tx.date);
    if (at == null) continue;
    if (at.isBefore(left) || at.isAfter(right)) continue;
    window.add(tx);
  }

  // Указатель по сумме: ключ отвечает на «есть ли вообще такая трата», и
  // дальше остаётся выбрать из горстки кандидатов ближайшую по дате.
  final index = <String, List<Transaction>>{};
  for (final tx in window) {
    (index[_key(tx.amount > 0, tx.amount.abs(), tx.currency)] ??= []).add(tx);
  }

  final matched = <Matched>[];
  final onlyFile = <ImportedRow>[];
  final taken = <String>{};

  for (final row in theirs) {
    final hit = _closest(index, row, slack, taken);
    if (hit == null) {
      onlyFile.add(row);
      continue;
    }
    taken.add(hit.id);
    matched.add(Matched(was: hit, fixed: _merge(hit, row), row: row));
  }

  final onlyApp = [for (final tx in window) if (!taken.contains(tx.id)) tx];
  return Reconciled(matched: matched, onlyFile: onlyFile, onlyApp: onlyApp);
}

/// Ключ указателя: сторона, сумма в копейках и валюта.
///
/// Валюта в ключ не входит, когда файл её не называет: иначе трата в леях не
/// нашлась бы под строкой без колонки валюты.
String _key(bool income, double amount, String currency) =>
    '${income ? '+' : '-'}|${(amount * 100).round()}|${currency.toUpperCase()}';

/// Ближайшая по дате запись среди тех, у кого сошлась сумма.
Transaction? _closest(
  Map<String, List<Transaction>> index,
  ImportedRow row,
  int slack,
  Set<String> taken,
) {
  final candidates = <Transaction>[];
  if (row.currency.trim().isEmpty) {
    // Валюты в файле нет — смотрим все валюты с такой суммой.
    for (final entry in index.entries) {
      final head = '${row.income ? '+' : '-'}|${(row.amount * 100).round()}|';
      if (entry.key.startsWith(head)) candidates.addAll(entry.value);
    }
  } else {
    candidates.addAll(
        index[_key(row.income, row.amount, row.currency)] ?? const []);
  }
  if (candidates.isEmpty) return null;

  final at = DateTime.tryParse(row.date);
  Transaction? best;
  var bestGap = 1 << 30;
  for (final tx in candidates) {
    if (taken.contains(tx.id)) continue;
    if (at == null) {
      if (tx.date == row.date) return tx;
      continue;
    }
    final mineAt = DateTime.tryParse(tx.date);
    if (mineAt == null) continue;
    final gap = mineAt.difference(at).inDays.abs();
    if (gap > slack) continue;
    if (gap < bestGap) {
      best = tx;
      bestGap = gap;
      if (gap == 0) break;
    }
  }
  return best;
}

/// Слить свою запись со строкой файла.
///
/// Дата и время берутся из выписки — она точнее памяти. Описание из файла
/// ставится, только если своего нет: «Кофе с собой» человеку понятнее, чем
/// «SC TUCANO SRL».
Transaction _merge(Transaction tx, ImportedRow row) => tx.copyWith(
      date: row.date.isEmpty ? null : row.date,
      time: row.time.isEmpty ? null : row.time,
      note: (tx.note ?? '').trim().isEmpty && row.note.trim().isNotEmpty
          ? row.note.trim()
          : null,
    );
