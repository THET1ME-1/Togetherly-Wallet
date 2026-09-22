import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/l10n/strings.dart';
import 'package:togetherly_money/logic/period.dart';
import 'package:togetherly_money/screens/home.dart';
import 'package:togetherly_money/services/auth_failure.dart';
import 'package:togetherly_money/services/session.dart';
import 'package:togetherly_money/services/sync.dart';
import 'package:togetherly_money/ui/theme/tm_theme.dart';

const me = Member(uid: 'u_me', name: 'Федя');
const partner = Member(uid: 'u_you', name: 'THET1ME');

/// Сессия, до которой не достучаться: ровно то, что было у тестировщика
/// 22.09.2026 — записи есть, сервер их не получил.
class _DeadSession extends Session {
  @override
  bool get signedIn => true;

  @override
  String get uid => me.uid;

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      throw SessionError(AuthFailure.offline);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 20),
  }) async =>
      throw SessionError(AuthFailure.offline);
}

Store storeWithQueue() {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Наличные', currency: 'MDL')],
      pair: Pair(groupId: 'g1', members: [me, partner], baseCurrency: 'MDL'),
    ));
  store.viewer = me.uid;
  store.syncEnabled = true;
  store.saveOperation(const Transaction(
    id: 't1',
    date: '2026-09-22',
    kind: TxKind.expense,
    account: 'Наличные',
    currency: 'MDL',
    amount: -240,
    amountBase: -240,
    author: 'u_me',
    payer: 'u_me',
  ));
  return store;
}

Widget home(Store store, Sync? sync) => MaterialApp(
      theme: TmTheme.dark(),
      home: HomeScreen(
        store: store,
        sync: sync,
        period: Period.month(),
        onPeriod: (_) {},
        onAccounts: () {},
        onBudgets: () {},
        onGoals: () {},
        onPlan: () {},
        onDebts: () {},
        onChat: () {},
        onSettings: () {},
        onDrill: (_, __, [___]) {},
      ),
    );

void main() {
  testWidgets('записи, которые не уехали, видны на ГЛАВНОЙ', (tester) async {
    final store = storeWithQueue();
    final sync = Sync(session: _DeadSession(), store: store);
    await sync.run();

    await tester.pumpWidget(home(store, sync));
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.outbox, isNotEmpty);
    expect(find.text(tr('stuckTitle')), findsOneWidget);
    sync.dispose();
  });

  testWidgets('пустая очередь карточку не показывает', (tester) async {
    final store = storeWithQueue()..clearOutbox({'tx:t1'});
    final sync = Sync(session: _DeadSession(), store: store);

    await tester.pumpWidget(home(store, sync));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(tr('stuckTitle')), findsNothing);
    sync.dispose();
  });

  testWidgets('без синхронизации карточки нет', (tester) async {
    final store = storeWithQueue();

    await tester.pumpWidget(home(store, null));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(tr('stuckTitle')), findsNothing);
  });
}
