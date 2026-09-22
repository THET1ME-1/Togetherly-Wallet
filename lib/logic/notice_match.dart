import 'notice_parse.dart';
import '../data/models.dart';
import 'money.dart';

/// Куда положить операцию из уведомления и кто её сделал.
///
/// Банк не говорит, кто держал телефон. Но он говорит КАРТУ, а карта в
/// приложении привязана к счёту, а счёт — к человеку: «личный счёт Саши»
/// значит, что платил Саша. Это единственный честный способ ответить «кто»,
/// и ровно поэтому у счёта есть последние четыре цифры.

/// Как обходиться с уведомлениями этого приложения.
enum NoticeMode {
  /// Не читать вовсе.
  off,

  /// Показать и спросить.
  ask,

  /// Записывать сразу, если разбор уверенный и счёт понятен.
  auto,
}

NoticeMode noticeModeOf(String? raw) => switch (raw) {
      'auto' => NoticeMode.auto,
      'off' => NoticeMode.off,
      _ => NoticeMode.ask,
    };

/// Известные банки: по пакету приложения подписываем источник по-человечески
/// и подсказываем валюту страны.
///
/// Список НЕ ограничивает чтение: уведомления идут от любого приложения,
/// незнакомый банк попадает в список сам после первого пуша, а знак ему
/// достаётся из самого уведомления. Список нужен ровно для трёх вещей:
/// человеческое имя, валюта по умолчанию, когда в тексте нет кода, и
/// видимость пакета для настоящего логотипа (она же заявлена в манифесте).
///
/// Страну приложение НЕ определяет и не спрашивает: какие банки у человека —
/// видно по тому, что стоит на телефоне, а валюту он задаёт сам.
const knownSenders = <String, ({String name, String currency})>{
  // Молдова
  'md.maib.mobile': (name: 'maib', currency: 'MDL'),
  'md.maib.maibank': (name: 'maibank', currency: 'MDL'),
  'com.maib.maibank': (name: 'maibank', currency: 'MDL'),
  'md.micb.mobile': (name: 'Moldindconbank', currency: 'MDL'),
  'md.micb.micbank': (name: 'MICB', currency: 'MDL'),
  'md.victoriabank.vbmobile': (name: 'Victoriabank', currency: 'MDL'),
  'md.victoriabank.mobile': (name: 'Victoriabank', currency: 'MDL'),
  'md.eximbank.mobile': (name: 'EximBank', currency: 'MDL'),
  'md.ecb.mobile': (name: 'Energbank', currency: 'MDL'),
  'com.otpbank.md': (name: 'OTP Bank', currency: 'MDL'),
  'md.otpbank.mobile': (name: 'OTP Bank', currency: 'MDL'),
  'md.comertbank.mobile': (name: 'Comerțbank', currency: 'MDL'),
  'md.fincombank.mobile': (name: 'FinComBank', currency: 'MDL'),
  'md.procredit.mobile': (name: 'ProCredit', currency: 'MDL'),
  'com.paynet.md': (name: 'Paynet', currency: 'MDL'),
  'md.runpay.app': (name: 'RunPay', currency: 'MDL'),
  // Россия
  'ru.sberbankmobile': (name: 'Сбербанк', currency: 'RUB'),
  'ru.sberbank.sbol': (name: 'Сбербанк', currency: 'RUB'),
  'com.idamob.tinkoff.android': (name: 'Т-Банк', currency: 'RUB'),
  'ru.tbank.mobile': (name: 'Т-Банк', currency: 'RUB'),
  'ru.alfabank.mobile.android': (name: 'Альфа-Банк', currency: 'RUB'),
  'ru.alfabank.oavdo.amc': (name: 'Альфа-Банк', currency: 'RUB'),
  'ru.vtb24.mobilebanking.android': (name: 'ВТБ', currency: 'RUB'),
  'ru.raiffeisennews': (name: 'Райффайзен', currency: 'RUB'),
  'ru.gazprombank.android.mobilebank.app': (name: 'Газпромбанк', currency: 'RUB'),
  'ru.rosbank.android': (name: 'Росбанк', currency: 'RUB'),
  'ru.psbank.mobile': (name: 'Промсвязьбанк', currency: 'RUB'),
  'ru.otpbank.mobile': (name: 'ОТП Банк', currency: 'RUB'),
  'ru.bspb': (name: 'Банк Санкт-Петербург', currency: 'RUB'),
  'ru.uralsib.mobile': (name: 'Уралсиб', currency: 'RUB'),
  'ru.sovcombank.halva': (name: 'Совкомбанк', currency: 'RUB'),
  'ru.mkb.mobile': (name: 'МКБ', currency: 'RUB'),
  'ru.akbars.mobile': (name: 'Ак Барс', currency: 'RUB'),
  'ru.rshb.mbank': (name: 'Россельхозбанк', currency: 'RUB'),
  'ru.dom.rf.mobile': (name: 'Банк ДОМ.РФ', currency: 'RUB'),
  'ru.mtsbank.mobile': (name: 'МТС Банк', currency: 'RUB'),
  'ru.yandex.bank': (name: 'Яндекс Банк', currency: 'RUB'),
  'ru.ozon.app.android': (name: 'Ozon', currency: 'RUB'),
  'ru.ozon.fintech.finance': (name: 'Ozon Банк', currency: 'RUB'),
  'com.vtb.mobilebank': (name: 'ВТБ', currency: 'RUB'),
  'ru.pochtabank.mobile': (name: 'Почта Банк', currency: 'RUB'),
  'ru.sbbol.mobile': (name: 'СберБизнес', currency: 'RUB'),
  // Румыния, Украина, Казахстан, Грузия, Турция
  'ro.btrl.mobile': (name: 'Banca Transilvania', currency: 'RON'),
  'ro.ing.mobile': (name: 'ING', currency: 'RON'),
  'ro.bcr.mobile': (name: 'BCR', currency: 'RON'),
  'com.revolut.revolut.ro': (name: 'Revolut', currency: 'RON'),
  'ua.privatbank.ap24': (name: 'Приват24', currency: 'UAH'),
  'ua.com.cs.android.mono': (name: 'monobank', currency: 'UAH'),
  'com.monobank': (name: 'monobank', currency: 'UAH'),
  'kz.kaspi.mobile': (name: 'Kaspi.kz', currency: 'KZT'),
  'kz.halykbank.mobile': (name: 'Halyk', currency: 'KZT'),
  'ge.bog.mobile': (name: 'Bank of Georgia', currency: 'GEL'),
  'ge.tbcbank.mobile': (name: 'TBC Bank', currency: 'GEL'),
  'com.garanti.cepsubesi': (name: 'Garanti BBVA', currency: 'TRY'),
  'com.ziraat.ziraatmobil': (name: 'Ziraat', currency: 'TRY'),
  // Кошельки и иностранные
  'com.payoneer.consumer': (name: 'Payoneer', currency: 'USD'),
  'com.payoneer.mobile': (name: 'Payoneer', currency: 'USD'),
  'com.revolut.revolut': (name: 'Revolut', currency: 'EUR'),
  'com.paypal.android.p2pmobile': (name: 'PayPal', currency: 'USD'),
  'com.transferwise.android': (name: 'Wise', currency: 'EUR'),
  'com.wise.android': (name: 'Wise', currency: 'EUR'),
  'com.binance.dev': (name: 'Binance', currency: 'USD'),
  'com.paysera.android': (name: 'Paysera', currency: 'EUR'),
  'com.n26.android': (name: 'N26', currency: 'EUR'),
  'com.google.android.apps.walletnfcrel': (name: 'Google Wallet', currency: 'USD'),
  'com.samsung.android.spay': (name: 'Samsung Wallet', currency: 'USD'),
};

/// Кошельки-посредники: платишь телефоном, а деньги всё равно снимает банк, и
/// уведомление приходит ДВАЖДЫ — от кошелька и от банка. Банковское точнее:
/// в нём есть валюта счёта и остаток.
///
/// Слушаем их всё равно. Выключенными они простояли до 14.09.2026, и стоило
/// это пропущенной траты: у человека банк уведомление не прислал вовсе, а
/// Google Кошелёк прислал — «USM CONTABILITATEA · 4 500,00 MDL с карты Visa
/// Classic ••0354», — и в приложении её не оказалось. Двойник глушится там,
/// где ему место: одна покупка — одна карточка в разборе (`sameCharge`).
const twinSenders = <String>{
  'com.google.android.apps.walletnfcrel',
  'com.samsung.android.spay',
};

/// Приложения, которые про деньги НЕ говорят, хотя суммы в их уведомлениях
/// есть всегда: почта, мессенджеры, доски объявлений.
///
/// «И нафиг оно с почты берёт, если ещё не платил» (22.09.2026). В разбор
/// попали письмо о выставленном счёте провайдера («plata 1 153,00 MDL» —
/// счёт выставлен, деньги никуда не ушли) и объявление с 999.md —
/// «Apartament cu camere» на 65 000 €, которое приложение записало расходом.
///
/// Правило «читаем любое приложение» это не отменяет: незнакомый банк
/// по-прежнему проходит сам. Здесь перечислено то, что банком не станет
/// никогда. Источник виден в списке и включается руками — банк действительно
/// может слать выписку письмом, и это выбор человека, а не умолчание.
const nonMoneySenders = <String>{
  // Почта
  'com.google.android.gm',
  'com.google.android.apps.inbox',
  'com.microsoft.office.outlook',
  'com.android.email',
  'com.samsung.android.email.provider',
  'ru.mail.mailapp',
  'com.my.mail',
  'com.yandex.mail',
  'ru.yandex.mail',
  'ch.protonmail.android',
  'me.proton.android.mail',
  'com.fsck.k9',
  'org.kman.AquaMail',
  'com.zoho.mail',
  'com.readdle.spark',
  'com.yahoo.mobile.client.android.mail',
  // Мессенджеры и соцсети
  'org.telegram.messenger',
  'org.telegram.plus',
  'com.whatsapp',
  'com.whatsapp.w4b',
  'com.viber.voip',
  'com.facebook.orca',
  'com.facebook.katana',
  'com.instagram.android',
  'com.vkontakte.android',
  'ru.ok.android',
  'com.twitter.android',
  'com.discord',
  'com.Slack',
  'com.skype.raider',
  'org.thoughtcrime.securesms',
  // Доски объявлений и барахолки
  'com.avito.android',
  'com.olx.pl',
  'ua.slando',
};

/// Целые семейства приложений одного издателя: у Simpals это 999.md, point.md
/// и остальное молдавское хозяйство — ни одно из них не банк.
const nonMoneyPrefixes = <String>{'md.simpals.', 'com.olx.'};

/// Говорит ли приложение о ДЕНЬГАХ вообще. Всё неизвестное — говорит: список
/// банков не ограничивает чтение, ограничивает только этот запрет.
bool isMoneyBlind(String package) =>
    nonMoneySenders.contains(package) ||
    nonMoneyPrefixes.any(package.startsWith);

/// Режим источника по умолчанию.
///
/// Без выбора человека спрашивают ВСЕ — и банк, и кошелёк: пропущенная трата
/// хуже лишней карточки в разборе, а лишней карточки и не будет. Выбор
/// сделан — он и решает, и решает СРАЗУ для всех, не заводя записи каждому из
/// шести десятков приложений справочника.
NoticeMode defaultModeFor(String package, [NoticeSource? source]) {
  // Почта и объявления молчат, пока человек сам их не включит.
  if (isMoneyBlind(package)) return NoticeMode.off;
  final wallet = twinSenders.contains(package);
  if (source == null) return NoticeMode.ask;
  final want = wallet
      ? source != NoticeSource.bank
      : source != NoticeSource.wallet;
  return want ? NoticeMode.ask : NoticeMode.off;
}

/// Пакет, записанный в отпечатке уведомления.
String senderOfFingerprint(String fingerprint) {
  final at = fingerprint.indexOf('|');
  return at <= 0 ? '' : fingerprint.substring(0, at);
}

/// Тот же платёж, о котором уже сказал ДРУГОЙ источник.
///
/// Платёж телефоном приходит дважды: от банка и от кошелька-посредника. Текст
/// у них разный, платёж один, и совпадают у него сумма, валюта и минута.
/// Номер карты НЕ сравниваем: кошелёк называет свою карту, банк свою — у
/// платежа телефоном они законно разные, а покупка всё та же.
bool sameCharge(String fingerprint, ParsedNotice notice, {int minutes = 3}) {
  final parts = fingerprint.split('|');
  if (parts.length != 5) return false;
  if (parts[0] == notice.package) return false;
  if (parts[1] != notice.amount.toStringAsFixed(2)) return false;
  if (parts[2] != notice.currency) return false;
  final minute = int.tryParse(parts[4]);
  if (minute == null) return false;
  return (minute - notice.at ~/ 60000).abs() <= minutes;
}

/// Откуда брать траты: от банка, от кошелька или от обоих.
///
/// Разом, а не перещёлкиванием двадцати банков: человек думает «читай из
/// банка», а не «включи maib, Victoriabank, MICB…».
enum NoticeSource { bank, wallet, both }

/// Кошелёк ли это. Всё, что не кошелёк-посредник, считается банком — включая
/// приложения, которых нет в списке.
bool isWalletSender(String package) => twinSenders.contains(package);

/// Имя источника для человека: известное — словом, незнакомое — пакетом.
/// Служебные части имени пакета: они есть у всех и ничего не говорят.
const _packageNoise = {
  'com', 'org', 'net', 'ru', 'md', 'ua', 'kz', 'ge', 'ro', 'tr', 'app',
  'apps', 'android', 'mobile', 'mobilebank', 'mobilebanking', 'client',
  'dev', 'release', 'prod', 'bank', 'banking', 'wallet', 'pay',
};

/// Как подписать источник.
///
/// Знакомый банк — своим именем. Незнакомый — самой содержательной частью
/// пакета: «com.bank.vanuatu.mobile» это «Vanuatu», а не «mobile». Человек
/// увидит осмысленное слово ещё до того, как банк попадёт в наш список.
String senderTitle(String package) {
  final known = knownSenders[package];
  if (known != null) return known.name;

  final parts = package
      .split('.')
      .where((p) => p.isNotEmpty && !_packageNoise.contains(p.toLowerCase()))
      .toList();
  if (parts.isEmpty) return package;

  parts.sort((a, b) => b.length.compareTo(a.length));
  final word = parts.first;
  return word[0].toUpperCase() + word.substring(1);
}

/// Счёт, на который ложится операция.
///
/// Порядок: запомненная привязка, потом четыре цифры, потом имя банка в имени
/// счёта. Не нашли — спрашиваем человека один раз и запоминаем.
String? accountForNotice(
  Database db,
  ParsedNoticeRef notice, {
  Map<String, String> learned = const {},
}) {
  final remembered = learned[noticeKey(notice.package, notice.last4)];
  if (remembered != null && db.accounts.any((a) => a.name == remembered)) {
    return remembered;
  }

  // Счёт в приложении ОДИН — выбирать не из чего, и спрашивать не о чем.
  // У тестировщика 22.09.2026 были «Наличные», карточки из банка с чужими
  // цифрами и серая кнопка «Записать»: счёт не подставился, а другого и не
  // было. Служебные счета (цель, долг, расчёт) за счёт не считаются.
  final real = db.accounts.where((a) => !isVirtualAccount(a.name)).toList();
  if (real.length == 1) return real.first.name;

  final digits = notice.last4;
  if (digits != null && digits.isNotEmpty) {
    // Банк и цифры вместе: самый точный случай. Две карты с одинаковыми
    // последними цифрами в разных банках — не редкость.
    for (final a in db.accounts) {
      if (a.last4 == digits && a.bank == notice.package) return a.name;
    }
    for (final a in db.accounts) {
      if (a.last4 == digits) return a.name;
    }
    // Банк назвал карту, а такой карты в приложении нет. Значит это ДРУГАЯ
    // карта того же банка: догадка по имени положила бы чужую трату на наш
    // счёт. Лучше спросить один раз и запомнить.
    return null;
  }

  // Цифр в уведомлении нет. Счёт, помеченный этим банком, — прямой ответ.
  final byBank = db.accounts.where((a) => a.bank == notice.package).toList();
  if (byBank.length == 1) return byBank.first.name;

  final bank = knownSenders[notice.package]?.name.toLowerCase();
  if (bank != null) {
    for (final a in db.accounts) {
      if (a.name.toLowerCase().contains(bank)) return a.name;
    }
  }
  return null;
}

/// Приставка к номеру операции, записанной из уведомления. Отдельного поля в
/// базе нет и не нужно: приставка уезжает на сервер вместе с номером и
/// работает у партнёра без миграции.
const noticePrefix = 'ntf-';

/// Записана ли операция из банковского уведомления.
bool fromNotice(Transaction op) => op.id.startsWith(noticePrefix);

/// Ключ запомненной привязки: банк плюс четыре цифры. Без цифр — на весь банк.
String noticeKey(String package, String? last4) =>
    '$package|${(last4 ?? '').isEmpty ? '*' : last4}';

/// Кто сделал операцию: владелец счёта, а если счёт общий — тот, у кого в
/// руках телефон.
String? payerForNotice(Database db, String? account, String viewer) {
  if (account == null) return viewer.isEmpty ? null : viewer;
  final at = db.accounts.indexWhere((a) => a.name == account);
  if (at < 0) return viewer.isEmpty ? null : viewer;
  final owner = db.accounts[at].owner;
  if (owner != null && owner.isNotEmpty) return owner;
  return viewer.isEmpty ? null : viewer;
}

/// Категория по магазину: та, которую человек сам поставил в прошлый раз.
/// Приложение не угадывает наперёд — оно помнит.
String? categoryForNotice(String? merchant, Map<String, String> learned) {
  final key = (merchant ?? '').trim().toLowerCase();
  if (key.isEmpty) return null;
  final raw = learned[key];
  if (raw == null) return null;
  final at = raw.indexOf(noticeCategorySep);
  return at < 0 ? raw : raw.substring(0, at);
}

/// Разделитель категории и подкатегории в памяти магазинов. Отдельного поля
/// заводить не стали: строка едет в те же настройки, а старые записи без
/// разделителя читаются как одна категория.
const noticeCategorySep = ' · ';

/// Подкатегория, запомненная магазину. До 14.09.2026 её не помнили вовсе:
/// человек ставил «Продукты · Кофе», а со следующего списания получал просто
/// «Продукты» и поправлял это каждый раз заново.
String? subcategoryForNotice(String? merchant, Map<String, String> learned) {
  final key = (merchant ?? '').trim().toLowerCase();
  if (key.isEmpty) return null;
  final raw = learned[key];
  if (raw == null) return null;
  final at = raw.indexOf(noticeCategorySep);
  return at < 0 ? null : raw.substring(at + noticeCategorySep.length);
}

/// Не записана ли уже эта трата руками. Человек мог ввести её до того, как
/// пришёл пуш, и вторая такая же строка — худшее, что может сделать трекер.
bool alreadyRecorded(
  Database db, {
  required double amount,
  required String currency,
  required String date,
  String? account,
  int minutes = 0,
}) {
  final target = (convert(db, amount, currency) * 100).round();
  for (final t in db.transactions) {
    if (t.date != date) continue;
    if (account != null && t.account != account) continue;
    final value = (convert(db, t.amount, t.currency).abs() * 100).round();
    if (value == target) return true;
  }
  return false;
}

/// Минимум, который нужен разбору, чтобы его вообще показывать.
///
/// Отдельный тип, чтобы правила привязки не зависели от разбора текста: их
/// проверяют по отдельности.
class ParsedNoticeRef {
  final String package;
  final String? last4;
  const ParsedNoticeRef({required this.package, this.last4});
}
