import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';

/// Платёж телефоном приходит ДВАЖДЫ, и до 14.09.2026 приложение решало это
/// молчанием: кошелёк-посредник стоял выключенным. Молчание стоило траты —
/// «USM CONTABILITATEA · 4 500,00 MDL с карты Visa Classic ••0354» пришло от
/// Google Кошелька, банк не прислал ничего, и в приложении покупки не было
/// («мне пришло уведомление, а где оно в приложении?»).

const gwallet = 'com.google.android.apps.walletnfcrel';
const maib = 'md.maib.mobile';

int minuteAt(int minutes) =>
    DateTime(2026, 9, 14, 12, minutes).millisecondsSinceEpoch;

ParsedNotice wallet({int at = 4, double amount = 4500}) => parseNotice(
      package: gwallet,
      title: 'USM CONTABILITATEA',
      body: '${amount.toStringAsFixed(0)} MDL с карты Visa Classic ••0354',
      at: minuteAt(at),
    );

ParsedNotice bank({int at = 4, double amount = 4500}) => parseNotice(
      package: maib,
      title: 'maib',
      body: 'Achitare ${amount.toStringAsFixed(2)} MDL la USM CONTABILITATEA. '
          'Card 1234. Disponibil 8241,25 MDL',
      at: minuteAt(at),
    );

Store storeOf() => Store()
  ..importBackupForTest(const Database(
    baseCurrency: 'MDL',
    accounts: [Account(name: 'Карта', currency: 'MDL', last4: '0354')],
  ));

void main() {
  test('уведомление кошелька разбирается целиком', () {
    final n = wallet();
    expect(n.amount, 4500);
    expect(n.currency, 'MDL');
    expect(n.kind, TxKind.expense);
    expect(n.last4, '0354');
    expect(n.merchant, 'USM CONTABILITATEA');
    // Слова направления в тексте нет ни на одном языке — но сумма, карта и
    // магазин вместе это операция, а не реклама.
    expect(n.ok, isTrue, reason: 'разбор должен считать это тратой');
    expect(n.confidence, lessThan(0.7),
        reason: 'молча такое не записывается, подтверждает человек');
  });

  // Служба подбирает шторку при каждом пробуждении, и одно и то же
  // уведомление может прийти в разбор второй раз (15.09.2026).
  test('магазин с цифрами в имени и копейки, повтор из шторки не двоит', () {
    ParsedNotice linella() => parseNotice(
          package: gwallet,
          title: 'LINELLA 81',
          body: '59,55 MDL с карты Visa Classic ••0354',
          at: minuteAt(44),
        );
    final n = linella();
    expect(n.amount, 59.55);
    expect(n.currency, 'MDL');
    expect(n.last4, '0354');
    expect(n.merchant, 'LINELLA 81');
    expect(n.ok, isTrue);

    final store = storeOf();
    store.addNotice(n);
    store.addNotice(linella());
    expect(store.pendingNotices, hasLength(1));
    expect(store.pendingNotices.single.merchant, 'LINELLA 81');
  });

  test('кошелёк по умолчанию СПРАШИВАЕТ, а не молчит', () {
    expect(defaultModeFor(gwallet), NoticeMode.ask);
    expect(defaultModeFor(maib), NoticeMode.ask);
  });

  test('выбор «только банк» по-прежнему глушит кошелёк', () {
    expect(defaultModeFor(gwallet, NoticeSource.bank), NoticeMode.off);
    expect(defaultModeFor(gwallet, NoticeSource.both), NoticeMode.ask);
    expect(defaultModeFor(maib, NoticeSource.wallet), NoticeMode.off);
  });

  test('трата из кошелька доходит до разбора', () {
    final store = storeOf();
    store.addNotice(wallet());
    expect(store.pendingNotices, hasLength(1));
    expect(store.pendingNotices.single.merchant, 'USM CONTABILITATEA');
  });

  test('банк первый — кошелёк молчит', () {
    final store = storeOf();
    store.addNotice(bank(at: 4));
    store.addNotice(wallet(at: 5));
    expect(store.pendingNotices, hasLength(1));
    expect(store.pendingNotices.single.package, maib);
  });

  test('кошелёк первый — банк вытесняет его карточку', () {
    final store = storeOf();
    store.addNotice(wallet(at: 4));
    store.addNotice(bank(at: 5));
    expect(store.pendingNotices, hasLength(1),
        reason: 'одна покупка — одна карточка');
    expect(store.pendingNotices.single.package, maib,
        reason: 'банковское точнее: там валюта счёта и остаток');
  });

  test('две покупки на одну сумму в разное время остаются двумя', () {
    final store = storeOf();
    store.addNotice(wallet(at: 4));
    store.addNotice(bank(at: 40));
    expect(store.pendingNotices, hasLength(2));
  });

  test('разные суммы в одну минуту не считаются одним платежом', () {
    final store = storeOf();
    store.addNotice(wallet(at: 4, amount: 4500));
    store.addNotice(bank(at: 4, amount: 120));
    expect(store.pendingNotices, hasLength(2));
  });

  test('банк не двоит покупку, уже записанную из кошелька', () {
    final store = storeOf();
    store.addNotice(wallet(at: 4));
    store.acceptNotice(store.pendingNotices.single, account: 'Карта');
    expect(store.pendingNotices, isEmpty);

    store.addNotice(bank(at: 5));
    expect(store.pendingNotices, isEmpty,
        reason: 'та же покупка уже записана кошельковой карточкой');
    expect(store.db.transactions, hasLength(1));
  });
}
