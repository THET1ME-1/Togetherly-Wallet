import 'package:flutter_test/flutter_test.dart';
import 'package:togetherly_money/data/models.dart';
import 'package:togetherly_money/data/store.dart';
import 'package:togetherly_money/logic/notice_match.dart';

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
}
