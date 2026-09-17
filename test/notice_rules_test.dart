import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';
import 'package:togetherly_money/logic/notice_rules.dart';

/// Свои правила разбора списаний: «Tucano → Продукты · Кофе, счёт Карта»,
/// «больше 2000 — спроси», «комиссия — не читать».
///
/// Память магазинов работает без подписки и остаётся бесплатной. Правила —
/// надстройка: они действуют ДО первого подтверждения, различают суммы и дни
/// и умеют остановить разбор совсем.

const maib = 'md.maib.mobile';

ParsedNotice notice({
  String title = 'maib',
  required String body,
  DateTime? at,
}) =>
    parseNotice(
      package: maib,
      title: title,
      body: body,
      at: (at ?? DateTime(2026, 9, 14, 12)).millisecondsSinceEpoch,
      fallbackCurrency: 'MDL',
    );

Store storeOf({bool plus = true, List<NoticeRule> rules = const []}) {
  final store = Store()
    ..importBackupForTest(const Database(
      baseCurrency: 'MDL',
      accounts: [
        Account(name: 'Карта Salut', currency: 'MDL', last4: '1234'),
        Account(name: 'Наличные', currency: 'MDL'),
      ],
      categories: [
        Category(name: 'Продукты'),
        Category(name: 'Кофе', parent: 'Продукты'),
        Category(name: 'Еда вне дома'),
      ],
    ))
    ..plusActive = plus;
  for (final r in rules.reversed) {
    store.saveNoticeRule(r);
  }
  return store;
}

NoticeRule rule(
  String id,
  NoticeWhen when, {
  NoticeDo act = NoticeDo.ask,
  String? category,
  String? subcategory,
  String? account,
  SplitMode? split,
  String? note,
  bool on = true,
}) =>
    NoticeRule(
      id: id,
      when: when,
      act: act,
      category: category,
      subcategory: subcategory,
      account: account,
      split: split,
      note: note,
      on: on,
    );

void main() {
  group('условие', () {
    test('магазин ловится куском имени', () {
      const when = NoticeWhen(merchant: 'tucano');
      expect(
        when.matches(notice(body: 'Achitare 57,00 MDL la SC TUCANO SRL')),
        isTrue,
        reason: 'банк пишет полное имя фирмы, человек помнит одно слово',
      );
      expect(when.matches(notice(body: 'Achitare 57,00 MDL la LINELLA')),
          isFalse);
    });

    test('границы суммы', () {
      const over = NoticeWhen(min: 2000);
      expect(over.matches(notice(body: 'Achitare 2500,00 MDL la X')), isTrue);
      expect(over.matches(notice(body: 'Achitare 1999,00 MDL la X')), isFalse);

      const small = NoticeWhen(max: 100);
      expect(small.matches(notice(body: 'Achitare 57,00 MDL la X')), isTrue);
      expect(small.matches(notice(body: 'Achitare 570,00 MDL la X')), isFalse);
    });

    test('дни недели', () {
      const weekdays = NoticeWhen(merchant: 'wolt', weekdays: {1, 2, 3, 4, 5});
      // 14 сентября 2026 — понедельник, 19-е — суббота.
      expect(
        weekdays.matches(notice(
          body: 'Achitare 200,00 MDL la WOLT',
          at: DateTime(2026, 9, 14, 13),
        )),
        isTrue,
      );
      expect(
        weekdays.matches(notice(
          body: 'Achitare 200,00 MDL la WOLT',
          at: DateTime(2026, 9, 19, 13),
        )),
        isFalse,
      );
    });

    test('направление и карта', () {
      const income = NoticeWhen(income: true);
      expect(income.matches(notice(body: 'Suplinire 5000,00 MDL')), isTrue);
      expect(income.matches(notice(body: 'Achitare 57,00 MDL la X')), isFalse);

      const card = NoticeWhen(last4: '1234');
      expect(
        card.matches(notice(body: 'Achitare 57,00 MDL, card *1234, X')),
        isTrue,
      );
      expect(
        card.matches(notice(body: 'Achitare 57,00 MDL, card *9999, X')),
        isFalse,
      );
    });

    test('пустое условие не подходит ни к чему', () {
      // Иначе первое же пустое правило съело бы все уведомления разом.
      final rules = [rule('r1', const NoticeWhen(), act: NoticeDo.skip)];
      expect(ruleFor(notice(body: 'Achitare 57,00 MDL la X'), rules), isNull);
    });
  });

  group('порядок', () {
    test('выигрывает первое подошедшее', () {
      final rules = [
        rule('частное', const NoticeWhen(merchant: 'tucano'),
            category: 'Продукты'),
        rule('общее', const NoticeWhen(min: 1), category: 'Еда вне дома'),
      ];
      final hit = ruleFor(notice(body: 'Achitare 57,00 MDL la TUCANO'), rules);
      expect(hit?.id, 'частное');
    });

    test('выключенное правило пропускается', () {
      final rules = [
        rule('выкл', const NoticeWhen(merchant: 'tucano'), on: false),
        rule('вкл', const NoticeWhen(merchant: 'tucano'), category: 'Продукты'),
      ];
      expect(ruleFor(notice(body: 'Achitare 57,00 MDL la TUCANO'), rules)?.id,
          'вкл');
    });

    test('новое правило встаёт первым', () {
      final store = storeOf(rules: [
        rule('старое', const NoticeWhen(min: 1)),
      ]);
      store.saveNoticeRule(rule('новое', const NoticeWhen(merchant: 'wolt')));
      expect(store.noticeRules.first.id, 'новое');
    });

    test('правило двигается по списку', () {
      final store = storeOf(rules: [
        rule('a', const NoticeWhen(merchant: 'a')),
        rule('b', const NoticeWhen(merchant: 'b')),
        rule('c', const NoticeWhen(merchant: 'c')),
      ]);
      store.moveNoticeRule(0, 2);
      expect([for (final r in store.noticeRules) r.id], ['b', 'c', 'a']);
    });
  });

  group('разбор', () {
    test('правило записывает трату сразу и заполняет поля', () {
      final store = storeOf(rules: [
        rule(
          'tucano',
          const NoticeWhen(merchant: 'tucano'),
          act: NoticeDo.record,
          category: 'Продукты',
          subcategory: 'Кофе',
          account: 'Карта Salut',
          note: 'Кофе с собой',
        ),
      ]);

      final written = store.addNotice(
          notice(body: 'Achitare 57,00 MDL la SC TUCANO SRL'));

      expect(written, isTrue, reason: 'правило сказало «записывать сразу»');
      expect(store.pendingNotices, isEmpty);
      final tx = store.db.transactions.single;
      expect(tx.account, 'Карта Salut');
      expect(tx.category, 'Продукты');
      expect(tx.subcategory, 'Кофе');
      expect(tx.note, 'Кофе с собой');
      expect(tx.amount, -57);
    });

    test('«спросить» кладёт в разбор даже при уверенном разборе', () {
      final store = storeOf(rules: [
        rule('крупное', const NoticeWhen(min: 2000), act: NoticeDo.ask),
      ]);
      store.setSenderMode(maib, NoticeMode.auto);

      final written = store.addNotice(notice(
        body: 'Achitare 2500,00 MDL, card *1234, la MAGAZIN',
      ));

      expect(written, isFalse, reason: 'крупное человек подтверждает сам');
      expect(store.pendingNotices, hasLength(1));
      expect(store.db.transactions, isEmpty);
    });

    test('«не читать» выбрасывает молча', () {
      final store = storeOf(rules: [
        rule('комиссия', const NoticeWhen(merchant: 'comision'),
            act: NoticeDo.skip),
      ]);

      final written =
          store.addNotice(notice(body: 'Comision 5,00 MDL, card *1234'));

      expect(written, isFalse);
      expect(store.pendingNotices, isEmpty, reason: 'в очередь не попало');
      expect(store.db.transactions, isEmpty);
    });

    test('без подписки правила молчат, но не пропадают', () {
      final store = storeOf(plus: false, rules: [
        rule('tucano', const NoticeWhen(merchant: 'tucano'),
            act: NoticeDo.record, category: 'Продукты', account: 'Карта Salut'),
      ]);

      final written =
          store.addNotice(notice(body: 'Achitare 57,00 MDL la TUCANO'));

      expect(written, isFalse, reason: 'автоматика — часть подписки');
      expect(store.pendingNotices, hasLength(1));
      expect(store.noticeRules, hasLength(1),
          reason: 'работу человека не отбираем: правила остаются в списке',);
    });

    test('правило с несуществующим счётом не роняет разбор', () {
      final store = storeOf(rules: [
        rule('старый счёт', const NoticeWhen(merchant: 'tucano'),
            act: NoticeDo.record, account: 'Карта, которую удалили'),
      ]);

      store.addNotice(notice(body: 'Achitare 57,00 MDL, card *1234, TUCANO'));
      // Счёт подобран обычным путём — по четырём цифрам.
      expect(store.db.transactions.single.account, 'Карта Salut');
    });
  });

  group('память магазинов', () {
    test('подкатегория помнится вместе с категорией', () {
      final store = storeOf();
      store.addNotice(notice(body: 'Achitare 57,00 MDL la TUCANO'));
      store.acceptNotice(
        store.pendingNotices.single,
        account: 'Карта Salut',
        category: 'Продукты',
        subcategory: 'Кофе',
      );

      final learned = store.noticeCategories;
      expect(categoryForNotice('Tucano', learned), 'Продукты');
      expect(subcategoryForNotice('Tucano', learned), 'Кофе',
          reason: 'до правки уточнение сбрасывалось на каждом списании');
    });

    test('старая память без подкатегории читается как прежде', () {
      const learned = {'tucano': 'Продукты'};
      expect(categoryForNotice('Tucano', learned), 'Продукты');
      expect(subcategoryForNotice('Tucano', learned), isNull);
    });
  });

  test('правило переживает запись и чтение', () {
    final source = rule(
      'r1',
      const NoticeWhen(
        merchant: 'wolt',
        min: 100,
        max: 900,
        weekdays: {1, 2, 3, 4, 5},
        income: false,
      ),
      act: NoticeDo.record,
      category: 'Еда вне дома',
      split: SplitMode.equal,
    );
    final back = NoticeRule.fromJson(source.toJson());
    expect(back.id, 'r1');
    expect(back.when.merchant, 'wolt');
    expect(back.when.min, 100);
    expect(back.when.weekdays, {1, 2, 3, 4, 5});
    expect(back.when.income, isFalse);
    expect(back.act, NoticeDo.record);
    expect(back.split, SplitMode.equal);
  });
}
