import '../data/models.dart';
import '../l10n/strings.dart';

/// Дележ, сальдо долга и приватность — то, чем парный трекер отличается от
/// одиночного.
///
/// Считается всё в копейках целыми числами и только на выходе превращается в
/// суммы: 0.1 + 0.2 в double даёт 0.30000000000000004, и на сводке за год это
/// расходится с выпиской. Остаток от деления достаётся плательщику, поэтому
/// сумма долей всегда сходится с суммой операции до копейки.

int _minor(double v) => (v.abs() * 100).round();

/// Кто сколько «съел» в этой операции, в валюте операции.
///
/// Ключ — uid участника Togetherly. Для операции без дележа ответ один: вся
/// сумма на том, кто платил. Доход, перевод и открывающий остаток не делятся
/// вовсе — делить нечего.
Map<String, double> splitOf(Transaction tx, Pair pair) {
  final payer = tx.payer ?? tx.author ?? '';
  final total = _minor(tx.amount);

  if (total == 0) return {};

  List<String> uids;
  List<int> bp;

  switch (tx.split) {
    case SplitMode.none:
    case SplitMode.payerOnly:
      return {if (payer.isNotEmpty) payer: total / 100};

    case SplitMode.equal:
      uids = pair.members.map((m) => m.uid).toList();
      if (uids.isEmpty) return {if (payer.isNotEmpty) payer: total / 100};
      final each = 10000 ~/ uids.length;
      bp = List<int>.filled(uids.length, each);
      bp[0] += 10000 - each * uids.length; // трое по 3333 дают 9999
      break;

    case SplitMode.income:
      uids = pair.members.map((m) => m.uid).toList();
      bp = pair.members.map((m) => m.incomeShareBp).toList();
      final sum = bp.fold<int>(0, (a, b) => a + b);
      if (sum != 10000 || uids.isEmpty) {
        return {if (payer.isNotEmpty) payer: total / 100};
      }
      break;

    case SplitMode.custom:
      final shares = tx.shares ?? const <String, int>{};
      final sum = shares.values.fold<int>(0, (a, b) => a + b);
      if (shares.isEmpty || sum != 10000) {
        return {if (payer.isNotEmpty) payer: total / 100};
      }
      uids = shares.keys.toList();
      bp = uids.map((u) => shares[u]!).toList();
      break;
  }

  final parts = <String, int>{};
  var used = 0;
  for (var i = 0; i < uids.length; i++) {
    final part = total * bp[i] ~/ 10000;
    parts[uids[i]] = part;
    used += part;
  }

  // Нечётная копейка идёт плательщику: сумма долей обязана сойтись с суммой
  // операции, иначе она повисает в воздухе и сальдо копит ошибку.
  final rest = total - used;
  if (rest != 0) {
    final holder = parts.containsKey(payer) ? payer : uids.first;
    parts[holder] = parts[holder]! + rest;
  }

  return parts.map((uid, minor) => MapEntry(uid, minor / 100));
}

/// Сальдо долгов пары в базовой валюте: положительное — участнику должны,
/// отрицательное — должен он.
///
/// Нигде не хранится, считается из журнала операций. Хранимые счётчики в
/// Togetherly врали дважды, а деньги ошибки в счётчике не прощают.
Map<String, double> settlement(List<Transaction> txs, Pair pair) {
  final net = <String, int>{for (final m in pair.members) m.uid: 0};

  for (final tx in txs) {
    if (tx.kind != TxKind.expense) continue;
    if (tx.split == SplitMode.none) continue;
    final payer = tx.payer ?? tx.author ?? '';
    if (payer.isEmpty) continue;

    // Доли считаются в валюте операции, а долг ведётся в базовой: у пары
    // из двух стран половина трат в чужой валюте.
    final ratio = tx.amount == 0 ? 1.0 : (tx.amountBase / tx.amount);
    splitOf(tx, pair).forEach((uid, share) {
      if (uid == payer) return;
      final owed = (share * ratio.abs() * 100).round();
      net[payer] = (net[payer] ?? 0) + owed;
      net[uid] = (net[uid] ?? 0) - owed;
    });
  }

  return net.map((uid, minor) => MapEntry(uid, minor / 100));
}

/// Одна строка для главного экрана.
///
/// Говорит НАПРАВЛЕНИЕ, а не падеж имени: «За JB SHARAN 3,50» человек читал и
/// не понимал, кто кому должен, а рядом стоит кнопка «Выровнять»
/// (16.09.2026). Имя партнёра ушло в подпись над строкой — в паре он один,
/// и в сумме его имя ничего не уточняло.
String debtLine(Map<String, double> net, Pair pair, String me) {
  final mine = net[me] ?? 0;
  if (mine.abs() < 0.005) return tr('settleEven');

  final sum = _format(mine.abs());

  if (mine > 0) return trf('settleTheyOwe', [sum]);
  return trf('settleYouOwe', [sum]);
}

/// Подпись над строкой долга: с кем считаемся.
String debtWith(Pair pair, String me) {
  final other = pair.other(me);
  final name = other?.name ?? tr('settlePartner');
  return trf('settleWith', [_instrumental(name)]);
}

String _format(double v) {
  final minor = (v * 100).round();
  final whole = (minor ~/ 100).toString();
  final frac = (minor % 100).toString().padLeft(2, '0');
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(' ');
    buf.write(whole[i]);
  }
  return '$buf,$frac';
}

/// Кириллица ли это. Латинские имена не склоняем: «Вы должны Partnery»
/// выглядит поломкой, а не заботой о падежах (поймано на живом эмуляторе).
bool _cyrillic(String s) => RegExp(r'^[А-Яа-яЁё\s-]+$').hasMatch(s.trim());

/// Имена в строке долга склоняются: «За Леной», «Вы должны Артёму». Правило
/// простое и покрывает русские имена на -а/-я и согласный; чего не знает —
/// оставляет как есть, и строка всё равно читается.
String instrumentalName(String name) => _instrumental(name);

String _instrumental(String name) {
  if (!_cyrillic(name)) return name;
  if (name.endsWith('а')) return '${name.substring(0, name.length - 1)}ой';
  if (name.endsWith('я')) return '${name.substring(0, name.length - 1)}ей';
  if (name.endsWith('й')) return '${name.substring(0, name.length - 1)}ем';
  return '${name}ом'; // ignore: unnecessary_brace_in_string_interps
}

String dativeName(String name) => _dative(name);

String _dative(String name) {
  if (!_cyrillic(name)) return name;
  if (name.endsWith('а')) return '${name.substring(0, name.length - 1)}е';
  if (name.endsWith('я')) return '${name.substring(0, name.length - 1)}е';
  if (name.endsWith('й')) return '${name.substring(0, name.length - 1)}ю';
  return '${name}у'; // ignore: unnecessary_brace_in_string_interps
}

/// Что увидит [viewer]: своя скрытая трата приходит целиком, чужая — без сути.
///
/// Сумма не прячется никогда. Без неё общий остаток врёт, а врущий остаток
/// хуже скрытой детали: человек перестаёт верить всему приложению.
Transaction redactFor(Transaction tx, String viewer, {DateTime? today}) {
  if (!tx.secret) return tx;
  if (tx.author == viewer) return tx;

  final reveal = tx.revealAt;
  if (reveal != null && reveal.isNotEmpty) {
    final day = DateTime.tryParse(reveal);
    final now = today ?? DateTime.now();
    if (day != null && !now.isBefore(day)) return tx;
  }

  return Transaction(
    id: tx.id,
    date: tx.date,
    kind: tx.kind,
    account: tx.account,
    currency: tx.currency,
    amount: tx.amount,
    amountBase: tx.amountBase,
    hidden: tx.hidden,
    author: tx.author,
    payer: tx.payer,
    split: tx.split,
    shares: tx.shares,
    secret: true,
    revealAt: tx.revealAt,
  );
}

/// Видно ли [viewer] этот счёт. Чужой личный не отдаётся вовсе, включая
/// остаток: на сервере он и не приезжает на устройство.
bool accountVisibleTo(Account account, String viewer) =>
    account.isShared || account.owner == viewer;
