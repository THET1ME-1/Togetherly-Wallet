import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/design/money_theme.dart';
import 'package:togetherly_money/widgets/comments_sheet.dart';
import 'package:togetherly_money/widgets/member_badge.dart';

import 'tm_fonts.dart';
import 'package:togetherly_money/design/myna.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

const op = Transaction(
  id: 'tx1',
  date: '2026-09-12',
  kind: TxKind.expense,
  account: 'Общий кошелёк',
  currency: 'MDL',
  amount: -1480,
  amountBase: -1480,
  category: 'Продукты',
  author: 'u_you',
  payer: 'u_you',
);

Store pairedStore({List<Comment> said = const []}) {
  final store = Store()
    ..importBackupForTest(Database(
      baseCurrency: 'MDL',
      pair: const Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: const [Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true)],
      transactions: const [op],
      comments: said,
    ));
  store.syncEnabled = true;
  store.viewer = me.uid;
  return store;
}

void main() {
  setUpAll(loadTmFonts);

  group('разговор под операцией', () {
    test('реплика уезжает на сервер и лежит под своей операцией', () {
      final store = pairedStore();
      store.saveComment(Comment(
        id: 'c1', txId: 'tx1', uid: me.uid, text: 'А это что?', created: 100));
      expect(store.outbox, contains('cm:c1'));
      expect(store.commentsOf('tx1').single.text, 'А это что?');
      expect(store.commentsOf('tx2'), isEmpty);
    });

    test('пустая реплика не пишется вовсе', () {
      final store = pairedStore();
      store.saveComment(const Comment(id: 'c1', txId: 'tx1', uid: 'u_me', text: '   '));
      expect(store.db.comments, isEmpty);
    });

    test('отклик без слов — это тоже реплика', () {
      final store = pairedStore();
      store.saveComment(const Comment(id: 'c1', txId: 'tx1', uid: 'u_me', emoji: '👍'));
      expect(store.commentsOf('tx1').single.emoji, '👍');
    });

    test('порядок разговора — по времени сказанного', () {
      final store = pairedStore(said: const [
        Comment(id: 'c2', txId: 'tx1', uid: 'u_you', text: 'Второе', created: 200),
        Comment(id: 'c1', txId: 'tx1', uid: 'u_me', text: 'Первое', created: 100),
      ]);
      expect(store.commentsOf('tx1').map((c) => c.text), ['Первое', 'Второе']);
    });

    test('удаление едет флагом, а не молчанием', () {
      final store = pairedStore(said: const [
        Comment(id: 'c1', txId: 'tx1', uid: 'u_me', text: 'Ой', created: 100),
      ]);
      store.deleteComment('c1');
      expect(store.db.comments, isEmpty);
      expect(store.outbox, contains('cm:c1'));
    });

    test('реплика партнёра приезжает дельтой, своя из очереди не затирается', () {
      final store = pairedStore();
      store.saveComment(Comment(
        id: 'mine', txId: 'tx1', uid: me.uid, text: 'Моё', created: 100));
      store.applyRemote({
        'now': 5,
        'comments': [
          {'id': 'mine', 'tx_id': 'tx1', 'uid': 'u_me', 'text': 'Подменённое',
           'emoji': '', 'updated': 400},
          {'id': 'theirs', 'tx_id': 'tx1', 'uid': 'u_you', 'text': 'Хлеб и молоко',
           'emoji': '', 'updated': 500},
        ],
      });
      final by = {for (final c in store.db.comments) c.id: c};
      expect(by['mine']!.text, 'Моё');
      expect(by['theirs']!.text, 'Хлеб и молоко');
      expect(by['theirs']!.created, 500, reason: 'время берётся из метки сервера');
    });

    test('удалённая партнёром реплика уходит с устройства', () {
      final store = pairedStore(said: const [
        Comment(id: 'c1', txId: 'tx1', uid: 'u_you', text: 'Ой', created: 100),
      ]);
      store.applyRemote({
        'now': 6,
        'comments': [
          {'id': 'c1', 'tx_id': 'tx1', 'deleted': true},
        ],
      });
      expect(store.db.comments, isEmpty);
    });

    test('разговор переживает перезапуск вместе с базой', () {
      final store = pairedStore(said: const [
        Comment(id: 'c1', txId: 'tx1', uid: 'u_me', text: 'Держим', created: 100),
      ]);
      final again = Database.fromJson(store.db.toJson());
      expect(again.comments.single.text, 'Держим');
      expect(again.comments.single.created, 100);
    });
  });

  group('лист разговора', () {
    Widget app(Store store, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
          theme: MoneyTheme.light(),
          darkTheme: MoneyTheme.dark(),
          themeMode: mode,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showComments(context, store, op),
                child: const Text('открыть'),
              ),
            ),
          ),
        );

    testWidgets('вопрос печатается и появляется в разговоре', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = pairedStore();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Пока тихо'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'А это что?');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Myna.arrowUp));
      await tester.pumpAndSettle();

      expect(store.commentsOf('tx1').single.text, 'А это что?');
      expect(find.text('А это что?'), findsOneWidget);
      expect(find.byType(MemberBadge), findsOneWidget);
    });

    testWidgets('отклик ставится одним касанием', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = pairedStore();
      await tester.pumpWidget(app(store));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('👍').first);
      await tester.pumpAndSettle();
      expect(store.commentsOf('tx1').single.emoji, '👍');
    });

    for (final mode in const [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('собирается на 320dp при шрифте 1.3, ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final store = pairedStore(said: const [
          Comment(id: 'c1', txId: 'tx1', uid: 'u_you', text: 'Это на неделю, брали мясо и сыр',
              created: 100),
          Comment(id: 'c2', txId: 'tx1', uid: 'u_me', emoji: '👍', created: 200),
        ]);
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: app(store, mode: mode),
        ));
        await tester.tap(find.text('открыть'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
