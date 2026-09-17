import '../data/models.dart';
import '../data/store.dart';
import '../l10n/strings.dart';
import 'money.dart';

/// Действие, которое предложил чат.
///
/// Модель не трогает базу сама: она называет действие словами, приложение
/// показывает карточку «вот что запишется», и только по касанию человека
/// изменение уходит в `Store` — со всеми правилами, очередью и отменой.
class AgentAction {
  final String kind;
  final Map<String, dynamic> args;

  const AgentAction(this.kind, this.args);

  factory AgentAction.fromJson(Map<String, dynamic> j) => AgentAction(
        '${j['do'] ?? ''}',
        ((j['args'] as Map?) ?? const {}).cast<String, dynamic>(),
      );

  /// Это вопрос человеку, а не изменение.
  bool get isQuestion => kind == 'ask_user';

  String get question => '${args['question'] ?? ''}';

  List<String> get options =>
      ((args['options'] as List?) ?? const []).map((e) => '$e').toList();
}

/// Что именно случится — одной строкой, человеческими словами.
///
/// Карточка без этой строки — это «модель что-то сделает», и подтверждать
/// такое человек не должен.
String agentSummary(Store store, AgentAction a) {
  final base = store.db.baseCurrency;
  String money(Object? v, [String? code]) =>
      '${code ?? args(a, 'currency') ?? base} ${formatAmount(_num(v))}';

  switch (a.kind) {
    case 'add_transaction':
      final income = '${a.args['kind']}' == 'income';
      final where = args(a, 'account') ?? _firstAccount(store);
      final what = args(a, 'category') ?? tr('noCategory');
      return '${income ? tr('opIncome') : tr('opSpending')} '
          '${money(a.args['amount'])} · $what · $where';
    case 'add_transactions':
      return trf('agentAddMany', ['${_items(a).length}']);
    case 'update_transaction':
      return trf('agentUpdateTx', [args(a, 'id') ?? '']);
    case 'delete_transaction':
      return trf('agentDeleteTx', [args(a, 'id') ?? '']);
    case 'delete_last':
      return trf('agentDeleteLast', ['${_count(a)}']);
    case 'add_account':
      return trf('agentAddAccount', [args(a, 'name') ?? '']);
    case 'add_category':
      final parent = args(a, 'parent');
      return parent == null
          ? trf('agentAddCategory', [args(a, 'name') ?? ''])
          : trf('agentAddSub', [args(a, 'name') ?? '', parent]);
    case 'set_budget':
      return trf('agentSetBudget',
          [args(a, 'category') ?? '', money(a.args['limit'], base)]);
    case 'delete_budget':
      return trf('agentDeleteBudget', [args(a, 'category') ?? '']);
    case 'add_recurring':
      return trf('agentAddRecurring',
          [args(a, 'name') ?? '', money(a.args['amount'], base)]);
    case 'delete_recurring':
      return trf('agentDeleteRecurring', [args(a, 'name') ?? '']);
    case 'set_plan_item':
      return trf('agentPlanItem',
          [args(a, 'name') ?? '', money(a.args['amount'], base)]);
    case 'add_goal':
      return trf('agentAddGoal',
          [args(a, 'name') ?? '', money(a.args['target'], base)]);
    default:
      return a.kind;
  }
}

/// Исполнить действие. Возвращает false, если данных не хватило: тогда чат
/// говорит об этом словами, а не делает вид, что записал.
bool runAgent(Store store, AgentAction a) {
  switch (a.kind) {
    case 'add_transaction':
      final amount = _num(a.args['amount']).abs();
      if (amount <= 0) return false;
      final income = '${a.args['kind']}' == 'income';
      final account = args(a, 'account') ?? _firstAccount(store);
      if (account.isEmpty) return false;
      final currency = args(a, 'currency') ?? _currencyOf(store, account);
      final signed = income ? amount : -amount;
      store.saveOperation(
        Transaction(
          id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
          date: args(a, 'date') ?? _today(),
          kind: income ? TxKind.income : TxKind.expense,
          account: account,
          currency: currency,
          amount: signed,
          amountBase: convert(store.db, signed, currency),
          category: args(a, 'category'),
          subcategory: args(a, 'subcategory'),
          note: args(a, 'note'),
          time: args(a, 'time'),
          author: store.viewer.isEmpty ? null : store.viewer,
          payer: store.viewer.isEmpty ? null : store.viewer,
          split: store.db.pair.members.length > 1
              ? store.db.pair.defaultSplit
              : SplitMode.none,
        ),
        label: tr('agentDone'),
      );
      return true;

    case 'add_transactions':
      // Выписка целиком: одна запись в журнал отмены, а не сто.
      final items = _items(a);
      if (items.isEmpty) return false;
      final ops = <Transaction>[];
      var stamp = DateTime.now().microsecondsSinceEpoch;
      for (final raw in items) {
        final amount = _num(raw['amount']).abs();
        if (amount <= 0) continue;
        final income = '${raw['kind']}' == 'income';
        final account = _str(raw['account']) ?? _firstAccount(store);
        if (account.isEmpty) continue;
        final currency = _str(raw['currency']) ?? _currencyOf(store, account);
        final signed = income ? amount : -amount;
        ops.add(Transaction(
          id: 'ai-${stamp++}',
          date: _str(raw['date']) ?? _today(),
          kind: income ? TxKind.income : TxKind.expense,
          account: account,
          currency: currency,
          amount: signed,
          amountBase: convert(store.db, signed, currency),
          category: _str(raw['category']),
          subcategory: _str(raw['subcategory']),
          note: _str(raw['note']),
          author: store.viewer.isEmpty ? null : store.viewer,
          payer: store.viewer.isEmpty ? null : store.viewer,
          split: store.db.pair.members.length > 1
              ? store.db.pair.defaultSplit
              : SplitMode.none,
        ));
      }
      if (ops.isEmpty) return false;
      store.saveMany(ops);
      return true;

    case 'update_transaction':
      final id = args(a, 'id');
      if (id == null) return false;
      final at = store.db.transactions.indexWhere((t) => t.id == id);
      if (at < 0) return false;
      final was = store.db.transactions[at];
      final amount = a.args['amount'] == null ? null : _num(a.args['amount']).abs();
      store.saveOperation(
        was.copyWith(
          amount: amount == null
              ? null
              : (was.amount < 0 ? -amount : amount),
          amountBase: amount == null
              ? null
              : convert(store.db, was.amount < 0 ? -amount : amount, was.currency),
          category: args(a, 'category'),
          subcategory: args(a, 'subcategory'),
          account: args(a, 'account'),
          date: args(a, 'date'),
          note: args(a, 'note'),
        ),
        label: tr('agentDone'),
      );
      return true;

    case 'delete_transaction':
      final id = args(a, 'id');
      if (id == null) return false;
      if (!store.db.transactions.any((t) => t.id == id)) return false;
      store.deleteOperation(id);
      return true;

    case 'delete_last':
      final count = _count(a);
      if (count <= 0) return false;
      // Последние по дате, а внутри дня — по порядку в списке: ровно то, что
      // человек видит сверху ленты.
      final list = [...store.db.transactions]
        ..sort((x, y) => y.date.compareTo(x.date));
      final doomed = list.take(count).toList();
      if (doomed.isEmpty) return false;
      for (final t in doomed) {
        store.deleteOperation(t.id);
      }
      return true;

    case 'add_account':
      final name = args(a, 'name');
      if (name == null || name.isEmpty) return false;
      store.editAccount(name, kind: _accountKind(args(a, 'kind')));
      return true;

    case 'add_category':
      final name = args(a, 'name');
      if (name == null || name.isEmpty) return false;
      final parent = args(a, 'parent');
      if (parent != null && parent.isNotEmpty) {
        store.saveSubcategory(parent, Category(name: name, parent: parent));
        return true;
      }
      store.setCategories([
        ...store.db.categories,
        Category(
          name: name,
          kind: '${a.args['kind']}' == 'income' ? CatKind.income : CatKind.expense,
        ),
      ]);
      return true;

    case 'set_budget':
      final category = args(a, 'category');
      final limit = _num(a.args['limit']);
      if (category == null || limit <= 0) return false;
      final list = [...store.db.budgets];
      final sub = args(a, 'subcategory');
      final at = list.indexWhere(
          (b) => b.category == category && (b.subcategory ?? '') == (sub ?? ''));
      final next = Budget(
        category: category,
        subcategory: sub,
        limit: limit,
        currency: store.db.baseCurrency,
        period: '${a.args['period'] ?? 'monthly'}',
        rollover: a.args['rollover'] == true,
        days: (a.args['days'] as num?)?.toInt(),
      );
      if (at >= 0) {
        list[at] = next;
      } else {
        list.add(next);
      }
      store.setBudgets(list);
      return true;

    case 'delete_budget':
      final category = args(a, 'category');
      if (category == null) return false;
      final sub = args(a, 'subcategory') ?? '';
      store.setBudgets(store.db.budgets
          .where((b) => !(b.category == category && (b.subcategory ?? '') == sub))
          .toList());
      return true;

    case 'add_recurring':
      final name = args(a, 'name');
      final amount = _num(a.args['amount']).abs();
      if (name == null || amount <= 0) return false;
      final account = args(a, 'account') ?? _firstAccount(store);
      if (account.isEmpty) return false;
      store.saveRecurring(Recurring(
        id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        amount: amount,
        currency: store.db.baseCurrency,
        account: account,
        category: args(a, 'category'),
        interval: '${a.args['every'] ?? 'monthly'}',
        nextDate: args(a, 'next_date') ?? _today(),
        kind: '${a.args['kind'] ?? 'expense'}',
        active: true,
        days: (a.args['days'] as num?)?.toInt(),
      ));
      return true;

    case 'delete_recurring':
      final name = args(a, 'name');
      if (name == null) return false;
      final hit = store.db.recurring.where((r) => r.name == name).firstOrNull;
      if (hit == null) return false;
      store.deleteRecurring(hit.id);
      return true;

    case 'set_plan_item':
      final name = args(a, 'name');
      final amount = _num(a.args['amount']);
      if (name == null || amount <= 0) return false;
      final month = args(a, 'month') ?? _today().substring(0, 7);
      store.setPlanItem(PlanItem(
        month: month,
        kind: planItemKindOf('${a.args['kind'] ?? 'category'}'),
        name: name,
        amount: amount,
      ));
      return true;

    case 'add_goal':
      final name = args(a, 'name');
      final target = _num(a.args['target']);
      if (name == null || target <= 0) return false;
      store.saveGoal(Goal(
        name: name,
        target: target,
        currency: store.db.baseCurrency,
        deadline: args(a, 'deadline'),
      ));
      return true;
  }
  return false;
}

/// Строковый аргумент или null, если его нет или он пустой.
String? args(AgentAction a, String key) {
  final v = a.args[key];
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

double _num(Object? v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);

/// Строки пачки. Больше двухсот за раз не берём: это уже не выписка, а
/// перенос базы, и делать его молча нельзя.
List<Map<String, dynamic>> _items(AgentAction a) => [
      for (final raw in (a.args['items'] as List?) ?? const [])
        if (raw is Map) raw.cast<String, dynamic>(),
    ].take(200).toList();

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// Сколько записей просили удалить. Больше двадцати за раз не отдаём: это уже
/// не «удали последние», а чистка базы, и делать её молча нельзя.
int _count(AgentAction a) {
  final raw = a.args['count'];
  final n = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  return n.clamp(0, 20);
}

String _today() => DateTime.now().toIso8601String().substring(0, 10);

String _firstAccount(Store store) =>
    store.db.accounts.isEmpty ? '' : store.db.accounts.first.name;

String _currencyOf(Store store, String account) {
  final at = store.db.accounts.indexWhere((a) => a.name == account);
  return at >= 0 ? store.db.accounts[at].currency : store.db.baseCurrency;
}

AccountKind? _accountKind(String? raw) =>
    raw == null ? null : accountKindOf(raw);

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
