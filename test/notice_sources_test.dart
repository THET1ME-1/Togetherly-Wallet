import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/notice_match.dart';
import 'package:togetherly_money/logic/notice_parse.dart';

const wallet = 'com.google.android.apps.walletnfcrel';
const maib = 'md.maib.mobile';
const sber = 'ru.sberbankmobile';

Store bare() => Store()
  ..importBackupForTest(const Database(baseCurrency: 'MDL'));

void main() {
  group('чужие приложения не лезут в список', () {
    test('выбор источника не заводит записи всему справочнику', () {
      final store = bare()..installedSenders = {maib};
      store.setNoticeSource(NoticeSource.bank);

      // Раньше здесь появлялось шесть десятков записей — по одной на каждое
      // приложение справочника, и экран показывал их все («мне сразу
      // отобразился ВЕСЬ список приложений, которых у меня нет»).
      expect(store.senders, isEmpty);
      // При этом выбор работает: кошелёк молчит, банк спрашивает.
      expect(store.modeOf(wallet), NoticeMode.off);
      expect(store.modeOf(maib), NoticeMode.ask);
      expect(store.modeOf(sber), NoticeMode.ask);
      expect(store.noticeSource, NoticeSource.bank);
    });

    test('«Кошелёк» переворачивает умолчание без единой записи', () {
      final store = bare()..installedSenders = {wallet};
      store.setNoticeSource(NoticeSource.wallet);

      expect(store.senders, isEmpty);
      expect(store.modeOf(wallet), NoticeMode.ask);
      expect(store.modeOf(maib), NoticeMode.off);
      expect(store.noticeSource, NoticeSource.wallet);
    });

    test('«записывать сразу» у банка переживает смену выбора', () {
      final store = bare()..installedSenders = {maib};
      store.setSenderMode(maib, NoticeMode.auto);
      store.setNoticeSource(NoticeSource.both);

      expect(store.modeOf(maib), NoticeMode.auto);
    });

    test('выбор переживает перезапуск и не спорит со старыми записями', () {
      final store = bare();
      store.setSenderMode(maib, NoticeMode.off);
      store.setNoticeSource(NoticeSource.bank);

      // Запись «не читаем» лишь повторяла прежнее умолчание и снята: иначе она
      // пережила бы смену настройки и спорила с ней.
      expect(store.senders.containsKey(maib), isFalse);
      expect(store.modeOf(maib), NoticeMode.ask);
    });

    test('свои источники — это установленные, виденные и включённые', () {
      final store = bare()..installedSenders = {maib};
      expect(store.installedSenders, contains(maib));
      // Ничего не выбирали руками — список пуст, и в нём нет чужих банков.
      expect(store.chosenSenders, isEmpty);
    });
  });

  /// Жалоба тестировщика 22.09.2026: «И нафиг оно с почты берёт, если ещё не
  /// платил». В разборе висели письмо о счёте провайдера, пришедшее в Gmail, и
  /// объявление с 999.md — «Apartament cu camere, EUR 65 000».
  group('почта и объявления — не банк', () {
    const gmail = 'com.google.android.gm';
    const simpals = 'md.simpals.md999';

    test('письмо о выставленном счёте в разбор не идёт', () {
      final store = bare();
      final written = store.addNotice(parseNotice(
        package: gmail,
        title: 'Darwin',
        body: 'Factura pentru luna septembrie: plata 1 153,00 MDL '
            'pina la 25.09.2026',
        at: DateTime.utc(2026, 9, 21, 21, 7).millisecondsSinceEpoch,
      ));

      expect(written, isFalse);
      expect(store.pendingNotices, isEmpty);
      expect(store.db.transactions, isEmpty);
    });

    test('объявление с доски в разбор не идёт', () {
      final store = bare();
      store.addNotice(parseNotice(
        package: simpals,
        title: 'Simpals',
        body: 'Apartament cu camere, 65 000 €',
        at: DateTime.utc(2026, 9, 22, 9, 48).millisecondsSinceEpoch,
      ));

      expect(store.pendingNotices, isEmpty);
    });

    test('источник всё же виден в списке — включить можно руками', () {
      final store = bare();
      store.addNotice(parseNotice(
        package: gmail,
        title: 'Darwin',
        body: 'Plata 1 153,00 MDL',
        at: DateTime.utc(2026, 9, 21, 21, 7).millisecondsSinceEpoch,
      ));

      expect(store.modeOf(gmail), NoticeMode.off);
      expect(store.noticeCountOf(gmail), greaterThan(0),
          reason: 'человек должен видеть, что почта присылала');
    });

    test('включённая руками почта читается как раньше', () {
      final store = bare()..setSenderMode(gmail, NoticeMode.ask);
      store.addNotice(parseNotice(
        package: gmail,
        title: 'Darwin',
        body: 'Achitare 1 153,00 MDL, card *9010',
        at: DateTime.utc(2026, 9, 21, 21, 7).millisecondsSinceEpoch,
      ));

      expect(store.pendingNotices, hasLength(1));
    });

    test('карточка, повисшая до запрета, уходит из разбора', () {
      final store = bare()..setSenderMode(simpals, NoticeMode.ask);
      store.addNotice(parseNotice(
        package: simpals,
        title: 'Simpals',
        body: 'Apartament cu camere, 65 000 €',
        at: DateTime.utc(2026, 9, 22, 9, 48).millisecondsSinceEpoch,
      ));
      expect(store.pendingNotices, hasLength(1));

      // Обновление закрывает источник — старая карточка уходит с ним.
      store.setSenderMode(simpals, NoticeMode.off);
      store.dropBlindNotices();

      expect(store.pendingNotices, isEmpty);
    });

    test('карточка включённого руками источника остаётся', () {
      final store = bare()..setSenderMode(simpals, NoticeMode.ask);
      store.addNotice(parseNotice(
        package: simpals,
        title: 'Simpals',
        body: 'Apartament cu camere, 65 000 €',
        at: DateTime.utc(2026, 9, 22, 9, 48).millisecondsSinceEpoch,
      ));

      store.dropBlindNotices();

      expect(store.pendingNotices, hasLength(1));
    });

    test('банки и кошельки правило не задевает', () {
      final store = bare();
      expect(store.modeOf(maib), NoticeMode.ask);
      expect(store.modeOf(wallet), NoticeMode.ask);
      expect(store.modeOf('md.some.newbank'), NoticeMode.ask);
    });
  });
}
