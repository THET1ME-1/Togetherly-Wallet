import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';

const me = Member(uid: 'u_me', name: 'Артём');
const partner = Member(uid: 'u_partner', name: 'Лена');

Store pairedStore() {
  final store = Store();
  store.importBackupForTest(const Database(
    baseCurrency: 'MDL',
    pair: Pair(groupId: 'g1', members: [me, partner], baseCurrency: 'MDL'),
  ));
  // Очередь копится только у вошедшего: без аккаунта складывать правки
  // некуда, и человек, выбравший жить на устройстве, её не видит.
  store.syncEnabled = true;
  return store;
}

Map<String, dynamic> serverTx({
  String id = 'srv1',
  String note = 'Пятёрочка',
  double amount = -1480,
  bool deleted = false,
  String author = 'u_partner',
}) =>
    {
      'id': id,
      'date': '2026-09-12',
      'kind': 'expense',
      'account': 'Общий кошелёк',
      'currency': 'MDL',
      'amount': amount,
      'amount_base': amount,
      'category': 'Еда',
      'note': note,
      'author': author,
      'payer': author,
      'split': 'equal',
      'shares': <String, int>{},
      'secret': false,
      'reveal_at': '',
      'deleted': deleted,
    };

void main() {
  group('очередь отправки', () {
    test('запись кладёт ключ в очередь', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 't1', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -100, amountBase: -100,
      ));
      expect(store.outbox, contains('tx:t1'));
    });

    test('удаление тоже едет на сервер, а не молчит', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 't2', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -100, amountBase: -100,
      ));
      store.clearOutbox(store.outbox);
      store.deleteOperation('t2');
      expect(store.outbox, contains('tx:t2'));
    });

    test('без аккаунта очередь не копится', () {
      final store = Store();
      store.importBackupForTest(const Database());
      store.syncEnabled = false;
      store.saveOperation(const Transaction(
        id: 't3', date: '2026-09-12', kind: TxKind.expense, account: 'Наличные',
        currency: 'MDL', amount: -100, amountBase: -100,
      ));
      expect(store.outbox, isEmpty);
    });

    test('очередь чистится только тем, что подтвердил сервер', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 'a', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -1, amountBase: -1,
      ));
      store.saveOperation(const Transaction(
        id: 'b', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -2, amountBase: -2,
      ));
      store.clearOutbox({'tx:a'});
      expect(store.outbox, {'tx:b'});
    });
  });

  _pairSwitchTests();
  _budgetTests();
  _refuseTests();

  group('дельта с сервера', () {
    test('чужая запись появляется в ленте', () {
      final store = pairedStore();
      store.applyRemote({'now': 111, 'transactions': [serverTx()]});
      expect(store.db.transactions.single.note, 'Пятёрочка');
      expect(store.db.transactions.single.payer, 'u_partner');
      expect(store.syncMark, 111);
    });

    test('удаление на сервере убирает запись', () {
      final store = pairedStore();
      store.applyRemote({'now': 1, 'transactions': [serverTx()]});
      store.applyRemote({'now': 2, 'transactions': [serverTx(deleted: true)]});
      expect(store.db.transactions, isEmpty);
    });

    test('своя запись из очереди сервером не затирается', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 'srv1', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -999, amountBase: -999, note: 'моя правка',
      ));
      // Сервер ещё не знает о правке и присылает прежнее значение.
      store.applyRemote({'now': 5, 'transactions': [serverTx(note: 'старое', amount: -1480)]});
      expect(store.db.transactions.single.note, 'моя правка');
      expect(store.db.transactions.single.amount, -999);
    });

    test('счета и категории приезжают вместе с владельцем', () {
      final store = pairedStore();
      store.applyRemote({
        'now': 7,
        'accounts': [
          {'name': 'Общий кошелёк', 'currency': 'MDL', 'owner_uid': '', 'is_pot': true, 'color': '#6FC2A8'},
          {'name': 'Мой Сбер', 'currency': 'RUB', 'owner_uid': 'u_me', 'is_pot': false},
        ],
        'categories': [
          {'name': 'Еда', 'parent': '', 'color': '#F2D68A'},
        ],
      });
      final pot = store.db.accounts.firstWhere((a) => a.name == 'Общий кошелёк');
      final mine = store.db.accounts.firstWhere((a) => a.name == 'Мой Сбер');
      expect(pot.isShared, isTrue);
      expect(pot.isPot, isTrue);
      expect(pot.color, 0xFF6FC2A8);
      expect(mine.owner, 'u_me');
      expect(store.db.categories.single.name, 'Еда');
    });

    test('метка времени двигается только вперёд ответом сервера', () {
      final store = pairedStore();
      store.applyRemote({'now': 100, 'transactions': const []});
      expect(store.syncMark, 100);
      store.applyRemote({'transactions': const []});
      expect(store.syncMark, 100, reason: 'ответ без метки её не сбрасывает');
    });
  });
}

void _pairSwitchTests() {
  group('смена пары', () {
    test('записи прежней пары не остаются', () {
      final store = pairedStore();
      store.applyRemote({'now': 10, 'transactions': [serverTx(id: 'old1')]});
      store.clearOutbox(store.outbox);
      expect(store.db.transactions.length, 1);

      store.setPair(const Pair(
        groupId: 'g2',
        members: [me, partner],
        baseCurrency: 'MDL',
      ));

      expect(store.db.transactions, isEmpty, reason: 'иначе баланс задваивается');
      expect(store.syncMark, 0, reason: 'дельту новой пары надо тянуть с нуля');
    });

    test('своя неотправленная запись переезжает в новую пару', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 'mine', date: '2026-09-12', kind: TxKind.expense, account: 'Наличные',
        currency: 'MDL', amount: -50, amountBase: -50,
      ));
      store.setPair(const Pair(groupId: 'g3', members: [me, partner]));
      expect(store.db.transactions.single.id, 'mine');
      expect(store.outbox, contains('tx:mine'));
    });
  });
}

void _budgetTests() {
  group('лимиты', () {
    test('новый лимит уезжает на сервер', () {
      final store = pairedStore();
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4000, currency: 'MDL', period: 'monthly'),
      ]);
      expect(store.outbox, contains(Store.budgetKey('Еда', null)));
    });

    test('изменённый лимит уезжает, нетронутый — нет', () {
      final store = pairedStore();
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4000, currency: 'MDL', period: 'monthly'),
        Budget(category: 'Дом', limit: 2000, currency: 'MDL', period: 'monthly'),
      ]);
      store.clearOutbox(store.outbox.toSet());
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4500, currency: 'MDL', period: 'monthly'),
        Budget(category: 'Дом', limit: 2000, currency: 'MDL', period: 'monthly'),
      ]);
      expect(store.outbox, {Store.budgetKey('Еда', null)});
    });

    test('снятый лимит уезжает флагом, а не молчанием', () {
      final store = pairedStore();
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4000, currency: 'MDL', period: 'monthly'),
      ]);
      store.clearOutbox(store.outbox.toSet());
      store.setBudgets(const []);
      expect(store.outbox, contains(Store.budgetKey('Еда', null)));
    });

    test('принятая договорённость уводит лимит на сервер', () {
      final store = pairedStore();
      final a = Agreement(
        id: 'a1',
        kind: AgreementKind.limit,
        proposedBy: partner.uid,
        payload: const {'category': 'Кафе', 'amount': 1200.0, 'currency': 'MDL'},
      );
      store.saveAgreement(a);
      store.clearOutbox(store.outbox.toSet());
      store.acceptAgreement(a, me.uid);
      // До правки лимит оставался у согласившегося, а у партнёра была живая
      // договорённость без единой цифры.
      expect(store.db.budgets.single.limit, 1200);
      expect(store.outbox, contains(Store.budgetKey('Кафе', null)));
    });

    test('лимит партнёра приезжает дельтой, своя правка не затирается', () {
      final store = pairedStore();
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4000, currency: 'MDL', period: 'monthly'),
      ]);
      store.applyRemote({
        'now': 7,
        'budgets': [
          {'category': 'Еда', 'subcategory': '', 'limit_value': 9999,
           'currency': 'MDL', 'period': 'monthly', 'scope': 'shared'},
          {'category': 'Дом', 'subcategory': '', 'limit_value': 2500,
           'currency': 'MDL', 'period': 'monthly', 'scope': 'shared'},
        ],
      });
      final by = {for (final b in store.db.budgets) b.category: b};
      expect(by['Еда']!.limit, 4000, reason: 'своя правка ещё не уехала');
      expect(by['Дом']!.limit, 2500);
    });

    test('личный лимит партнёра на устройство не приезжает', () {
      final store = pairedStore();
      store.viewer = me.uid;
      store.applyRemote({
        'now': 8,
        'budgets': [
          {'category': 'Кофе', 'subcategory': '', 'limit_value': 300,
           'currency': 'MDL', 'period': 'monthly', 'scope': 'personal:${partner.uid}'},
          {'category': 'Книги', 'subcategory': '', 'limit_value': 500,
           'currency': 'MDL', 'period': 'monthly', 'scope': 'personal:${me.uid}'},
        ],
      });
      expect(store.db.budgets.map((b) => b.category), ['Книги']);
    });

    test('снятый партнёром лимит уходит с устройства', () {
      final store = pairedStore();
      store.setBudgets(const [
        Budget(category: 'Еда', limit: 4000, currency: 'MDL', period: 'monthly'),
      ]);
      store.clearOutbox(store.outbox.toSet());
      store.applyRemote({
        'now': 9,
        'budgets': [
          {'category': 'Еда', 'subcategory': '', 'deleted': true},
        ],
      });
      expect(store.db.budgets, isEmpty);
    });
  });
}

void _refuseTests() {
  group('отказ сервера', () {
    test('отказанная запись остаётся в очереди, принятая уходит', () {
      final store = pairedStore();
      store.saveOperation(const Transaction(
        id: 'good', date: '2026-09-12', kind: TxKind.expense, account: 'Общий кошелёк',
        currency: 'MDL', amount: -10, amountBase: -10,
      ));
      store.saveOperation(const Transaction(
        id: 'bad', date: '2026-09-12', kind: TxKind.expense, account: 'Чужой личный',
        currency: 'MDL', amount: -20, amountBase: -20,
      ));
      // Так отвечает сервер: одна запись отбита стражем приватности.
      final refused = {'tx:bad'};
      store.clearOutbox(store.outbox.difference(refused));
      expect(store.outbox, {'tx:bad'},
          reason: 'иначе запись исчезает бесследно: у автора есть, у партнёра нет');
    });
  });
}
