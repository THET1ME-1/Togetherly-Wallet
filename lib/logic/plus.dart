/// Wallet+: своя подписка приложения денег.
///
/// Отдельная от Togetherly+ — решение человека 14.09.2026. Учётка общая на всю
/// экосистему, а касса своя: месяц и год, три магазина.
///
/// Что подписка открывает и чего НЕ открывает, решается здесь одним местом.
/// Правило простое: платят за то, что стоит нам денег (модель, разбор файлов,
/// наше хранилище) или работает вместо человека. Сам учёт, пара, отчёты,
/// офлайн и выгрузка базы бесплатны навсегда — трекер, который держит записи
/// в заложниках, второй раз никому не продашь.
library;

/// Откуда пришёл талон.
enum PlusSource {
  /// Google Play.
  play,

  /// App Store.
  appStore,

  /// Витрина lava.
  lava,

  /// Оплатил партнёр: подписка одна на пару.
  partner,

  /// Выдано руками (поддержка, тестер, автор).
  grant,
}

PlusSource? plusSourceOf(String? raw) => switch (raw) {
      'play' => PlusSource.play,
      'appstore' => PlusSource.appStore,
      'lava' => PlusSource.lava,
      'partner' => PlusSource.partner,
      'grant' => PlusSource.grant,
      _ => null,
    };

String plusSourceName(PlusSource s) => switch (s) {
      PlusSource.play => 'play',
      PlusSource.appStore => 'appstore',
      PlusSource.lava => 'lava',
      PlusSource.partner => 'partner',
      PlusSource.grant => 'grant',
    };

/// Талон подписки: до какого момента оплачено и когда мы это в последний раз
/// сверяли с сервером.
class PlusPass {
  const PlusPass({
    required this.until,
    required this.source,
    required this.checkedAt,
    this.fromPartner = false,
  });

  /// До какого момента оплачено, миллисекунды.
  final int until;

  /// Какая касса выдала.
  final PlusSource source;

  /// Когда талон в последний раз сверяли с сервером, миллисекунды.
  final int checkedAt;

  /// Подписку купил партнёр. Показываем это словами: иначе человек не поймёт,
  /// почему после роспуска пары платное закрылось.
  final bool fromPartner;

  /// Сколько дней талон живёт без единой сверки.
  ///
  /// Тридцать, а не три: человек уезжает в отпуск без сети, и выключать то,
  /// за что он заплатил, ровно в поездке — худшее, что можно сделать. Дольше
  /// месяца держать нельзя, иначе отменивший подписку пользуется ей год.
  static const offlineDays = 30;

  /// Грейс после неудачного списания, дни. Банк отклоняет платёж чаще, чем
  /// человек передумывает.
  static const graceDays = 3;

  bool activeAt(DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    final stale = ms - checkedAt > offlineDays * 86400000;
    if (stale) return false;
    return ms <= until + graceDays * 86400000;
  }

  /// Сколько дней осталось (с грейсом). Отрицательное — уже кончилась.
  int daysLeftAt(DateTime now) {
    final ms = until + graceDays * 86400000 - now.millisecondsSinceEpoch;
    return (ms / 86400000).ceil();
  }

  Map<String, dynamic> toJson() => {
        'until': until,
        'source': plusSourceName(source),
        'checkedAt': checkedAt,
        if (fromPartner) 'fromPartner': true,
      };

  static PlusPass? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final until = j['until'] is num ? (j['until'] as num).toInt() : null;
    final checked =
        j['checkedAt'] is num ? (j['checkedAt'] as num).toInt() : null;
    final source = plusSourceOf('${j['source'] ?? ''}');
    if (until == null || checked == null || source == null) return null;
    return PlusPass(
      until: until,
      source: source,
      checkedAt: checked,
      fromPartner: j['fromPartner'] == true,
    );
  }
}

/// Что в бесплатной версии ограничено числом.
///
/// Только планирование. Счета, категории, операции и история не режутся
/// НИКОГДА: это собственные записи человека, и потолок на них читается как
/// выкуп. У конвертов и целей потолок работает иначе — это инструменты
/// планирования, пяти конвертов хватает на быт, а кому мало, тот уже всерьёз
/// ведёт бюджет.
class PlusLimits {
  /// Конверты-бюджеты.
  static const envelopes = 5;

  /// Цели вместе с подушкой.
  static const goals = 2;

  /// Долги.
  static const debts = 2;

  /// Регулярные платежи.
  static const recurring = 3;

  /// Вопросов к модели в сутки без подписки (считает сервер).
  static const asksPerDay = 3;

  /// Файлов и чеков в месяц без подписки (считает сервер).
  static const filesPerMonth = 5;
}

/// Что закрыто без подписки.
enum PlusGate {
  /// Ещё один вопрос к модели сверх дневных.
  ///
  /// Счёт ведёт СЕРВЕР: потолок, который считает телефон, снимается
  /// переустановкой приложения.
  chat,

  /// Ещё один файл или чек сверх месячных. Тоже счёт сервера.
  files,

  /// Ещё один конверт сверх бесплатных.
  envelope,

  /// Ещё одна цель.
  goal,

  /// Ещё один долг.
  debt,

  /// Ещё одно регулярное.
  recurring,

  /// План на месяц, кроме текущего.
  planAhead,

  /// Записывать траты из уведомлений молча.
  autoNotices,

  /// Свои правила разбора уведомлений.
  noticeRules,

  /// Замок на вход.
  lock,

  /// Отчёт за период файлом.
  report,

  /// Разбор месяца от модели.
  monthReview,

  /// Премиальные оформления карт и иконка приложения.
  looks,

  /// Вернуться к состоянию базы на прошлый день.
  ///
  /// Данные пары лежат на сервере ВСЕГДА и бесплатно — иначе общих счетов бы
  /// не было. Платное здесь другое: снимки за каждый день, по которым можно
  /// откатиться. Первая формулировка («копии на сервере») читалась так, будто
  /// без подписки на сервере ничего нет, и человек справедливо спросил, где
  /// тогда живут общие счета (14.09.2026).
  cloudBackups,
}

/// Ключ строки, объясняющей, за что тут просят денег. Один ключ на калитку:
/// «Оформите подписку» без причины злит, а причина у каждой калитки своя.
String plusGateKey(PlusGate gate) => switch (gate) {
      PlusGate.chat => 'plusGateChat',
      PlusGate.files => 'plusGateFiles',
      PlusGate.envelope => 'plusGateEnvelope',
      PlusGate.goal => 'plusGateGoal',
      PlusGate.debt => 'plusGateDebt',
      PlusGate.recurring => 'plusGateRecurring',
      PlusGate.planAhead => 'plusGatePlanAhead',
      PlusGate.autoNotices => 'plusGateAutoNotices',
      PlusGate.noticeRules => 'plusGateRules',
      PlusGate.lock => 'plusGateLock',
      PlusGate.report => 'plusGateReport',
      PlusGate.monthReview => 'plusGateReview',
      PlusGate.looks => 'plusGateLooks',
      PlusGate.cloudBackups => 'plusGateBackups',
    };

/// Потолок для калитки с числом. `null` — калитка без счёта.
int? plusLimitOf(PlusGate gate) => switch (gate) {
      PlusGate.chat => PlusLimits.asksPerDay,
      PlusGate.files => PlusLimits.filesPerMonth,
      PlusGate.envelope => PlusLimits.envelopes,
      PlusGate.goal => PlusLimits.goals,
      PlusGate.debt => PlusLimits.debts,
      PlusGate.recurring => PlusLimits.recurring,
      _ => null,
    };

/// Считает ли потолок СЕРВЕР. Такие числа на устройстве не хранятся: расход
/// вопросов и файлов переживает переустановку и общий на все телефоны
/// человека.
bool plusCountedByServer(PlusGate gate) =>
    gate == PlusGate.chat || gate == PlusGate.files;

/// Можно ли завести ещё одну штуку.
///
/// Считается ровно по числу УЖЕ заведённых, и это важно: у человека, который
/// вёл семь конвертов до появления потолка, они остаются все. Отобрать
/// выданное нельзя — он просто не заведёт восьмой, пока не уберёт лишние или
/// не оформит подписку.
bool canAddMore({
  required bool plus,
  required int have,
  required int limit,
}) =>
    plus || have < limit;

/// Цены.
///
/// Пять долларов в месяц — нижняя граница, а не желаемая наценка. Считать
/// надо не по чату: у DeepSeek Flash вопрос стоит около двух десятых цента, и
/// сотня вопросов в месяц не дотягивает до четверти доллара. Дорого стоит
/// остальное — зрячая модель на чеках, разбор выписок на сервере, наше
/// хранилище под шифрованные копии и трафик. Человек, который пользуется
/// автоматикой всерьёз, за месяц съедает доллары, и подписка за двести рублей
/// работала бы в минус ровно на тех, ради кого она сделана.
///
/// Год дешевле месяца на 37%: при меньшей разнице годовой никто не берёт,
/// при большей теряются деньги на тех, кто остался бы на месяце.
class PlusPrice {
  const PlusPrice({
    required this.month,
    required this.quarter,
    required this.year,
  });

  final String month;
  final String quarter;
  final String year;

  String of(PlusPlan plan) => switch (plan) {
        PlusPlan.month => month,
        PlusPlan.quarter => quarter,
        PlusPlan.year => year,
      };

  /// Рубли витрины lava и Google Play для России и СНГ.
  static const rub = PlusPrice(month: '799 ₽', quarter: '1990 ₽', year: '5490 ₽');

  /// Доллары App Store и Play для остального мира.
  static const usd = PlusPrice(month: r'$7.99', quarter: r'$19.99', year: r'$54.99');

  /// Евро для Европы.
  static const eur = PlusPrice(month: '7,99 €', quarter: '19,99 €', year: '54,99 €');
}

/// Тариф подписки.
///
/// Три, а не два: месяц для «попробовать», год для тех, кто решил, и квартал
/// между ними — он снимает страх годового платежа, не обрушивая счёт.
enum PlusPlan {
  month,
  quarter,
  year;

  /// Как тариф называется на сервере и в кассе.
  String get code => switch (this) {
        PlusPlan.month => 'month',
        PlusPlan.quarter => 'quarter',
        PlusPlan.year => 'year',
      };

  /// Сколько месяцев в тарифе: из этого считается выгода.
  int get months => switch (this) {
        PlusPlan.month => 1,
        PlusPlan.quarter => 3,
        PlusPlan.year => 12,
      };

  static PlusPlan? byCode(String? raw) => switch (raw) {
        'month' => PlusPlan.month,
        'quarter' => PlusPlan.quarter,
        'year' => PlusPlan.year,
        _ => null,
      };
}

/// Выгода тарифа против месячного, в процентах. Ноль — выгоды нет.
///
/// Считается из САМИХ цен, а не пишется руками: цены меняются, а подпись
/// «выгода 43%» остаётся на экране и начинает врать.
int plusSaving(PlusPlan plan, {PlusPrice price = PlusPrice.rub}) {
  double? number(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
    return double.tryParse(digits);
  }

  final month = number(price.month);
  final mine = number(price.of(plan));
  if (month == null || mine == null || month <= 0 || plan == PlusPlan.month) {
    return 0;
  }
  final full = month * plan.months;
  if (full <= 0) return 0;
  final save = (1 - mine / full) * 100;
  return save <= 0 ? 0 : save.round();
}
