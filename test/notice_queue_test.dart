import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';

const me = Member(uid: 'u_me', name: 'Саша');
const you = Member(uid: 'u_you', name: 'Линелла');

/// Пара с тремя счетами: общий, мой личный и её личный. Разница в владельце —
/// это и есть ответ на «кто платил».
Database sample() => const Database(
      baseCurrency: 'MDL',
      pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
      accounts: [
        Account(name: 'Общий кошелёк', currency: 'MDL', isPot: true, last4: '4568'),
        Account(name: 'Карта maib', currency: 'MDL', last4: '1234', owner: 'u_me'),
        Account(name: 'Карта Линеллы', currency: 'MDL', last4: '9911', owner: 'u_you'),
      ],
      categories: [Category(name: 'Продукты'), Category(name: 'Транспорт')],
    );

Store storeOf({NoticeMode mode = NoticeMode.ask, Database? db}) {
  final store = Store()..importBackupForTest(db ?? sample());
  store.viewer = me.uid;
  store.setSenderMode('md.maib.mobile', mode);
  return store;
}

ParsedNotice maib({
  String body = 'Achitare 300,00 MDL, card *1234, Linella. Disponibil: 4 512,30 MDL',
  int? at,
}) =>
    parseNotice(
      package: 'md.maib.mobile',
      title: 'maib',
      body: body,
      at: at ?? DateTime.utc(2026, 9, 12, 14, 30).millisecondsSinceEpoch,
    );

void main() {
  group('очередь уведомлений', () {
    test('в режиме «спросить» пуш ждёт человека, операции пока нет', () {
      final store = storeOf();
      final written = store.addNotice(maib());

      expect(written, isFalse);
      expect(store.pendingNotices, hasLength(1));
      expect(store.pendingNotices.first.amount, 300);
      expect(store.db.transactions, isEmpty);
    });

    test('повторный пуш той же траты в очередь не попадает', () {
      final store = storeOf();
      store.addNotice(maib());
      store.addNotice(maib());

      expect(store.pendingNotices, hasLength(1));
    });

    test('отклонённый пуш не возвращается следующим приходом', () {
      final store = storeOf();
      store.addNotice(maib());
      store.dismissNotice(store.pendingNotices.first);
      store.addNotice(maib());

      expect(store.pendingNotices, isEmpty);
      expect(store.db.transactions, isEmpty);
    });

    test('выключенный источник не читается вовсе', () {
      final store = storeOf(mode: NoticeMode.off);
      expect(store.addNotice(maib()), isFalse);
      expect(store.pendingNotices, isEmpty);
    });

    test('«записывать сразу» пишет трату на счёт с этими цифрами', () {
      final store = storeOf(mode: NoticeMode.auto);
      final written = store.addNotice(maib());

      expect(written, isTrue);
      expect(store.pendingNotices, isEmpty);
      final tx = store.db.transactions.single;
      expect(tx.account, 'Карта maib');
      expect(tx.amount, -300);
      expect(tx.kind, TxKind.expense);
      expect(tx.date, '2026-09-12');
      expect(tx.note, 'Linella');
    });

    test('плательщик берётся у владельца счёта, а не у того, кто смотрит', () {
      final store = storeOf(mode: NoticeMode.auto);
      store.viewer = me.uid;
      store.addNotice(maib(body: 'Achitare 120,00 MDL, card *9911, Kaufland'));

      expect(store.db.transactions.single.payer, 'u_you');
    });

    test('зачисление становится доходом', () {
      final store = storeOf(mode: NoticeMode.auto);
      store.addNotice(maib(body: 'Alimentare 5 000,00 MDL, card *1234. Disponibil: 9 512,30 MDL'));

      final tx = store.db.transactions.single;
      expect(tx.kind, TxKind.income);
      expect(tx.amount, 5000);
      expect(tx.split, SplitMode.none);
    });

    test('неуверенный разбор не пишется сам даже в режиме «сразу»', () {
      final store = storeOf(mode: NoticeMode.auto);
      final written = store.addNotice(maib(body: 'Credit pina la 100 000 MDL pentru tine!'));

      expect(written, isFalse);
      expect(store.db.transactions, isEmpty);
    });

    test('незнакомые цифры карты не пишутся сами: счёт неизвестен', () {
      final store = storeOf(mode: NoticeMode.auto);
      final written = store.addNotice(maib(body: 'Achitare 300,00 MDL, card *7777, Linella'));

      expect(written, isFalse);
      expect(store.pendingNotices, hasLength(1));
    });

    test('трата, записанная руками, не удваивается пушем', () {
      final store = storeOf(mode: NoticeMode.auto);
      store.saveOperation(const Transaction(
        id: 'hand',
        date: '2026-09-12',
        kind: TxKind.expense,
        account: 'Карта maib',
        currency: 'MDL',
        amount: -300,
        amountBase: -300,
        author: 'u_me',
        payer: 'u_me',
      ));

      final written = store.addNotice(maib());

      expect(written, isFalse);
      expect(store.db.transactions, hasLength(1));
      expect(store.pendingNotices, isEmpty);
    });
  });

  group('приложение помнит выбор человека', () {
    test('счёт, выбранный руками, подставляется в следующий раз сам', () {
      final store = storeOf(mode: NoticeMode.auto);
      // Первый пуш с незнакомыми цифрами: человек сам говорит, куда его.
      store.addNotice(maib(body: 'Achitare 80,00 MDL, card *7777, Darwin'));
      store.acceptNotice(
        store.pendingNotices.first,
        account: 'Общий кошелёк',
        category: 'Транспорт',
      );

      expect(store.pendingNotices, isEmpty);
      expect(store.db.transactions.single.account, 'Общий кошелёк');

      // Второй такой же — уже без вопросов.
      final written = store.addNotice(maib(
        body: 'Achitare 95,00 MDL, card *7777, Darwin',
        at: DateTime.utc(2026, 9, 12, 18).millisecondsSinceEpoch,
      ));

      expect(written, isTrue);
      expect(store.db.transactions.where((t) => t.amount == -95).single.account,
          'Общий кошелёк');
    });

    test('категория запоминается по магазину', () {
      final store = storeOf();
      store.addNotice(maib());
      store.acceptNotice(
        store.pendingNotices.first,
        account: 'Карта maib',
        category: 'Продукты',
      );

      expect(categoryForNotice('Linella', store.noticeCategories), 'Продукты');
      expect(categoryForNotice('linella', store.noticeCategories), 'Продукты');
      expect(categoryForNotice('Kaufland', store.noticeCategories), isNull);
    });

    test('привязка карты помнится по банку и четырём цифрам', () {
      final store = storeOf();
      store.addNotice(maib());
      store.acceptNotice(store.pendingNotices.first, account: 'Карта maib');

      expect(store.noticeAccounts[noticeKey('md.maib.mobile', '1234')], 'Карта maib');
    });
  });

  group('платёж телефоном через кошелёк', () {
    ParsedNotice wallet(String body) => parseNotice(
          package: 'com.google.android.apps.walletnfcrel',
          title: 'Google Pay',
          body: body,
          at: DateTime.utc(2026, 9, 12, 15).millisecondsSinceEpoch,
          fallbackCurrency: 'MDL',
        );

    test('кошелёк по умолчанию СПРАШИВАЕТ: банк присылает не всё', () {
      final store = Store()..importBackupForTest(sample());
      store.viewer = me.uid;

      // Выключенным он простоял до 14.09.2026, и это стоило траты: банк о
      // покупке не сказал ничего, кошелёк сказал — а приложение промолчало.
      expect(store.modeOf('com.google.android.apps.walletnfcrel'), NoticeMode.ask);
      expect(store.addNotice(wallet('Оплачено 249,00 MDL, Mastercard ••1234')), isFalse,
          reason: 'сама запись не пишется, трата ложится в разбор');
      expect(store.pendingNotices, hasLength(1));
    });

    test('включённый кошелёк разбирается и ложится на карту', () {
      final store = Store()..importBackupForTest(sample());
      store.viewer = me.uid;
      store.setSenderMode('com.google.android.apps.walletnfcrel', NoticeMode.auto);

      expect(store.addNotice(wallet('Оплачено 249,00 MDL, Mastercard ••1234')), isTrue);
      final tx = store.db.transactions.single;
      expect(tx.account, 'Карта maib');
      expect(tx.amount, -249);
    });

    test('вторая запись об одной покупке не появляется', () {
      final store = storeOf(mode: NoticeMode.auto);
      store.setSenderMode('com.google.android.apps.walletnfcrel', NoticeMode.auto);

      // Сперва кошелёк, через полминуты банк — та же покупка.
      store.addNotice(wallet('Оплачено 249,00 MDL, Mastercard ••1234'));
      store.addNotice(maib(
        body: 'Achitare 249,00 MDL, card *1234, LINELLA',
        at: DateTime.utc(2026, 9, 12, 15, 0, 30).millisecondsSinceEpoch,
      ));

      expect(store.db.transactions, hasLength(1));
      expect(store.pendingNotices, isEmpty);
    });

    test('«Карта использована» без суммы в очередь не попадает', () {
      final store = Store()..importBackupForTest(sample());
      store.viewer = me.uid;
      store.setSenderMode('com.google.android.apps.walletnfcrel', NoticeMode.ask);

      expect(store.addNotice(wallet('Карта использована. Mastercard ••1234')), isFalse);
      expect(store.pendingNotices, isEmpty);
    });
  });

  group('банк, которого нет в списке', () {
    test('читается и попадает в список источников сам', () {
      final store = Store()..importBackupForTest(sample());
      store.viewer = me.uid;

      final written = store.addNotice(parseNotice(
        package: 'com.bank.vanuatu.mobile',
        title: 'National Bank',
        body: 'Purchase 42.50 EUR at COFFEE HOUSE, card *1234',
        at: DateTime.utc(2026, 9, 12, 9).millisecondsSinceEpoch,
      ));

      expect(written, isFalse, reason: 'незнакомый банк спрашивает, а не пишет молча');
      expect(store.pendingNotices.single.amount, 42.5);
      // Источник запомнен: экран настроек покажет его без всякого списка.
      expect(store.noticeSenders, contains('com.bank.vanuatu.mobile'));
    });

    test('имя выводится из пакета осмысленно, пока его нет в списке', () {
      // Служебные части пакета пропускаются: «mobile» и «bank» есть у всех.
      expect(senderTitle('com.bank.vanuatu.mobile'), 'Vanuatu');
      expect(senderTitle('com.bancoexample.mobilebanking'), 'Bancoexample');
      expect(senderTitle('md.maib.mobile'), 'maib');
    });

    test('страна нигде не спрашивается: валюта берётся из текста', () {
      final n = parseNotice(
        package: 'com.bank.vanuatu.mobile',
        title: 'Bank',
        body: 'Purchase 42.50 EUR at COFFEE HOUSE',
        at: 0,
        fallbackCurrency: 'MDL',
      );
      expect(n.currency, 'EUR');
    });
  });

  group('выбор источника', () {
    const wallet = 'com.google.android.apps.walletnfcrel';

    test('по умолчанию читаются оба: и банк, и кошелёк', () {
      final store = Store()..importBackupForTest(sample());
      expect(store.noticeSource, NoticeSource.both,
          reason: 'кнопка не должна врать: кошелёк читается');
      expect(store.modeOf(wallet), NoticeMode.ask);
      expect(store.modeOf('md.maib.mobile'), NoticeMode.ask);
    });

    test('«Кошелёк» выключает банки и включает кошельки', () {
      final store = Store()..importBackupForTest(sample());
      store.setNoticeSource(NoticeSource.wallet);

      expect(store.noticeSource, NoticeSource.wallet);
      expect(store.modeOf(wallet), NoticeMode.ask);
      expect(store.modeOf('md.maib.mobile'), NoticeMode.off);
      expect(store.modeOf('ru.sberbankmobile'), NoticeMode.off);
    });

    test('«Оба» включает и банк, и кошелёк', () {
      final store = Store()..importBackupForTest(sample());
      store.setNoticeSource(NoticeSource.both);

      expect(store.noticeSource, NoticeSource.both);
      expect(store.modeOf(wallet), NoticeMode.ask);
      expect(store.modeOf('md.maib.mobile'), NoticeMode.ask);
    });

    test('«записывать сразу» у банка выбор источника не понижает', () {
      final store = Store()..importBackupForTest(sample());
      store.setSenderMode('md.maib.mobile', NoticeMode.auto);
      store.setNoticeSource(NoticeSource.both);

      expect(store.modeOf('md.maib.mobile'), NoticeMode.auto);
    });

    test('выключенный источник забирает свои уведомления из очереди', () {
      final store = Store()..importBackupForTest(sample());
      store.viewer = me.uid;
      store.setNoticeSource(NoticeSource.both);
      store.addNotice(parseNotice(
        package: wallet,
        title: 'Google Pay',
        body: 'Оплачено 249,00 MDL, Mastercard ••7777',
        at: DateTime.utc(2026, 9, 12, 15).millisecondsSinceEpoch,
        fallbackCurrency: 'MDL',
      ));
      expect(store.pendingNotices, hasLength(1));

      store.setNoticeSource(NoticeSource.bank);
      expect(store.pendingNotices, isEmpty);
    });

    test('ничего не включено — источника нет', () {
      final store = Store()..importBackupForTest(sample());
      for (final package in knownSenders.keys) {
        store.setSenderMode(package, NoticeMode.off);
      }
      expect(store.noticeSource, isNull);
    });
  });

  group('мусор в очередь не попадает', () {
    test('реклама с суммой', () {
      final store = storeOf();
      store.addNotice(maib(body: 'Credit pina la 100 000 MDL pentru tine!'));
      expect(store.pendingNotices, isEmpty);
    });

    test('код подтверждения', () {
      final store = storeOf();
      store.addNotice(maib(body: 'Cod de confirmare: 4821'));
      expect(store.pendingNotices, isEmpty);
    });
  });

  group('банк у счёта', () {
    /// Две карты с одинаковыми последними цифрами в разных банках — обычное
    /// дело, и без банка счёта разбор кладёт трату не туда.
    Database twins() => const Database(
          baseCurrency: 'MDL',
          pair: Pair(groupId: 'g1', members: [me, you], baseCurrency: 'MDL'),
          accounts: [
            Account(
              name: 'maib карта',
              currency: 'MDL',
              last4: '1234',
              bank: 'md.maib.mobile',
              owner: 'u_me',
            ),
            Account(
              name: 'Сбер карта',
              currency: 'RUB',
              last4: '1234',
              bank: 'ru.sberbankmobile',
              owner: 'u_you',
            ),
          ],
        );

    test('банк и цифры вместе решают, куда лечь', () {
      final db = twins();
      expect(
        accountForNotice(
          db,
          const ParsedNoticeRef(package: 'ru.sberbankmobile', last4: '1234'),
          learned: const {},
        ),
        'Сбер карта',
      );
      expect(
        accountForNotice(
          db,
          const ParsedNoticeRef(package: 'md.maib.mobile', last4: '1234'),
          learned: const {},
        ),
        'maib карта',
      );
    });

    test('без цифр помогает сам банк', () {
      expect(
        accountForNotice(
          twins(),
          const ParsedNoticeRef(package: 'ru.sberbankmobile'),
          learned: const {},
        ),
        'Сбер карта',
      );
    });

    test('плательщик берётся у владельца найденного счёта', () {
      final store = Store()..importBackupForTest(twins());
      store.viewer = me.uid;
      store.setSenderMode('ru.sberbankmobile', NoticeMode.auto);
      store.addNotice(parseNotice(
        package: 'ru.sberbankmobile',
        title: 'СберБанк',
        body: 'Покупка 450,00 ₽ Пятёрочка, карта *1234',
        at: DateTime.utc(2026, 9, 12, 11).millisecondsSinceEpoch,
        fallbackCurrency: 'RUB',
      ));

      final tx = store.db.transactions.single;
      expect(tx.account, 'Сбер карта');
      expect(tx.payer, 'u_you');
      expect(tx.currency, 'RUB');
    });

    test('банк счёта переживает поездку через сервер', () {
      final store = Store()..importBackupForTest(twins());
      store.viewer = me.uid;
      store.applyRemote({
        'accounts': [
          {
            'name': 'Карта Victoria',
            'currency': 'MDL',
            'last4': '5566',
            'bank': 'md.victoriabank.vbmobile',
            'brand': 'visa',
            'card_kind': 'card',
            'design': 2,
            'updated': 1,
          },
        ],
      });

      final acc = store.db.accounts.firstWhere((a) => a.name == 'Карта Victoria');
      expect(acc.bank, 'md.victoriabank.vbmobile');
      expect(acc.last4, '5566');
    });
  });

  group('след в ленте', () {
    test('операция из уведомления помечена номером', () {
      final store = storeOf(mode: NoticeMode.auto);
      store.addNotice(maib());

      final tx = store.db.transactions.single;
      expect(fromNotice(tx), isTrue);
      expect(tx.id, startsWith(noticePrefix));
    });

    test('операция, введённая руками, не помечена', () {
      const hand = Transaction(
        id: 'hand-1',
        date: '2026-09-12',
        kind: TxKind.expense,
        account: 'Карта maib',
        currency: 'MDL',
        amount: -50,
        amountBase: -50,
      );
      expect(fromNotice(hand), isFalse);
    });
  });

  group('счёт по уведомлению', () {
    final db = sample();

    test('по четырём цифрам', () {
      final at = accountForNotice(
        db,
        const ParsedNoticeRef(package: 'md.maib.mobile', last4: '9911'),
        learned: const {},
      );
      expect(at, 'Карта Линеллы');
    });

    test('по имени банка в названии счёта, когда цифр нет', () {
      final at = accountForNotice(
        db,
        const ParsedNoticeRef(package: 'md.maib.mobile'),
        learned: const {},
      );
      expect(at, 'Карта maib');
    });

    test('запомненная привязка сильнее догадки', () {
      final at = accountForNotice(
        db,
        const ParsedNoticeRef(package: 'md.maib.mobile', last4: '9911'),
        learned: {noticeKey('md.maib.mobile', '9911'): 'Общий кошелёк'},
      );
      expect(at, 'Общий кошелёк');
    });

    test('удалённый счёт из памяти не подставляется', () {
      final at = accountForNotice(
        db,
        const ParsedNoticeRef(package: 'md.maib.mobile', last4: '9911'),
        learned: {noticeKey('md.maib.mobile', '9911'): 'Закрытая карта'},
      );
      expect(at, 'Карта Линеллы');
    });

    /// Телефон тестировщика 22.09.2026: один счёт «Наличные», три карточки в
    /// разборе и серая кнопка «Записать» — счёт не подставился, а другого в
    /// приложении и нет. Человек решил, что списания не записываются вовсе.
    const single = Database(
      baseCurrency: 'MDL',
      accounts: [Account(name: 'Наличные', currency: 'MDL')],
    );

    test('единственный счёт подставляется, даже когда банк назвал чужую карту',
        () {
      final at = accountForNotice(
        single,
        const ParsedNoticeRef(package: 'md.maib.maibank', last4: '9010'),
        learned: const {},
      );
      expect(at, 'Наличные');
    });

    test('единственный счёт подставляется и незнакомому источнику', () {
      final at = accountForNotice(
        single,
        const ParsedNoticeRef(package: 'md.some.newbank'),
        learned: const {},
      );
      expect(at, 'Наличные');
    });

    test('служебный счёт единственным не считается', () {
      final at = accountForNotice(
        const Database(
          baseCurrency: 'MDL',
          accounts: [Account(name: 'Цель: Подушка', currency: 'MDL')],
        ),
        const ParsedNoticeRef(package: 'md.maib.maibank', last4: '9010'),
        learned: const {},
      );
      expect(at, isNull);
    });

    test('счетов несколько — догадки по-прежнему нет', () {
      final at = accountForNotice(
        db,
        const ParsedNoticeRef(package: 'md.maib.mobile', last4: '9010'),
        learned: const {},
      );
      expect(at, isNull, reason: 'это другая карта того же банка');
    });
  });
}
