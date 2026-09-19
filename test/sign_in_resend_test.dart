import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/services/live.dart';

/// Вход в приложение не выгружает базу заново.
///
/// Жалоба 19.09.2026: «при каждом действии партнёра одно и то же
/// уведомление, даже на его вход в группу». Каждый запуск помечал к отправке
/// ВСЕ записи, сервер получал выгрузку и звал партнёра «Новая запись».
/// Заодно старая копия своей операции ложилась поверх категории, которую
/// партнёр успел поправить.
const me = Member(uid: 'u_me', name: 'Саша');
const anya = Member(uid: 'u_anya', name: 'Аня');

Transaction op(String id) => Transaction(
      id: id,
      date: '2026-09-19',
      kind: TxKind.expense,
      account: 'Карта',
      currency: 'MDL',
      amount: -40,
      amountBase: -40,
      author: me.uid,
      payer: me.uid,
    );

Store storeOf({List<Transaction> ops = const []}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      accounts: const [Account(name: 'Карта', currency: 'MDL')],
      categories: const [Category(name: 'Кофе')],
      transactions: ops,
      pair: const Pair(groupId: 'g_anya', members: [me, anya]),
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  return store;
}

void main() {
  test('синхронизированное хранилище на входе ничего не шлёт', () {
    final store = storeOf(ops: [op('a'), op('b')]);
    store.applyRemote({'now': 5});
    store.clearOutbox(store.outbox.toSet());

    store.adoptLocalRecords();

    expect(store.outbox, isEmpty,
        reason: 'правки и так ждут в очереди, выгружать базу незачем');
    expect(store.pendingLocal, 0);
  });

  test('первый вход с гостевыми записями спрашивает, а не шлёт', () {
    final store = storeOf(ops: [op('a')]);
    store.adoptLocalRecords();
    expect(store.pendingLocal, 1);
    expect(store.outbox, isEmpty);
  });

  test('первый вход без операций уносит остальное', () {
    final store = storeOf();
    store.adoptLocalRecords();
    expect(store.outbox, containsAll(['acc:Карта', 'cat:Кофе']));
  });

  group('уведомление по живому каналу', () {
    Map<String, Object?> event({String by = 'u_anya', Object? news}) => {
          'event': 'money_changed',
          'by': by,
          if (news != null) 'news': news,
        };

    test('новая операция партнёра зовёт', () {
      expect(isPartnerNews(event(news: true), 'u_me'), isTrue);
    });

    test('курсы, настройки и выгрузка молчат', () {
      expect(isPartnerNews(event(news: false), 'u_me'), isFalse);
      expect(isPartnerNews(event(), 'u_me'), isFalse,
          reason: 'событие старого сервера без флага — не новость');
    });

    test('своя запись и чужое событие молчат', () {
      expect(isPartnerNews(event(by: 'u_me', news: true), 'u_me'), isFalse);
      expect(isPartnerNews({'event': 'draw', 'news': true, 'by': 'u_anya'}, 'u_me'),
          isFalse);
      expect(isPartnerNews(null, 'u_me'), isFalse);
    });
  });
}
