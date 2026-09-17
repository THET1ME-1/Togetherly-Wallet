// Модель данных. Формат тот же, что у веб-версии и у файла бэкапа: между
// приложениями ходит один и тот же JSON, и переезд не требует миграции.

/// Платёжная система карты. Нужна только для вида: по ней рисуется знак в
/// углу, и счёт перестаёт быть безымянной строкой.
enum CardBrand { none, visa, mastercard, mir, maestro, amex, unionpay }

CardBrand cardBrandOf(String? raw) => switch (raw) {
  'visa' => CardBrand.visa,
  'mastercard' => CardBrand.mastercard,
  'mir' => CardBrand.mir,
  'maestro' => CardBrand.maestro,
  'amex' => CardBrand.amex,
  'unionpay' => CardBrand.unionpay,
  _ => CardBrand.none,
};

String cardBrandName(CardBrand b) => switch (b) {
  CardBrand.visa => 'visa',
  CardBrand.mastercard => 'mastercard',
  CardBrand.mir => 'mir',
  CardBrand.maestro => 'maestro',
  CardBrand.amex => 'amex',
  CardBrand.unionpay => 'unionpay',
  CardBrand.none => '',
};

/// Что это за счёт: карта, наличные, накопительный, кредитный.
enum AccountKind { card, credit, cash, savings }

AccountKind accountKindOf(String? raw) => switch (raw) {
  'credit' => AccountKind.credit,
  'cash' => AccountKind.cash,
  'savings' => AccountKind.savings,
  _ => AccountKind.card,
};

String accountKindName(AccountKind k) => switch (k) {
  AccountKind.credit => 'credit',
  AccountKind.cash => 'cash',
  AccountKind.savings => 'savings',
  AccountKind.card => 'card',
};

String accountKindTitle(AccountKind k) => switch (k) {
  AccountKind.credit => 'Кредитная карта',
  AccountKind.cash => 'Наличные',
  AccountKind.savings => 'Накопительный',
  AccountKind.card => 'Дебетовая карта',
};

/// Чем занята пустая часть карты.
///
/// У настоящего пластика фон не пустой, и человек выбирает, чем занять свой:
/// имя повторами, сетка линий или ленты. Объём при этом по-прежнему без теней
/// и градиентов — только тональная фактура поверх заливки.
enum CardTexture { watermark, guilloche, stripes }

CardTexture cardTextureOf(String? raw) => switch (raw) {
  'guilloche' => CardTexture.guilloche,
  'stripes' => CardTexture.stripes,
  _ => CardTexture.watermark,
};

String cardTextureName(CardTexture t) => switch (t) {
  CardTexture.guilloche => 'guilloche',
  CardTexture.stripes => 'stripes',
  CardTexture.watermark => 'watermark',
};

class Account {
  final String name;
  final String currency;
  final int? color; // ARGB; пусто — берётся по порядку из палитры
  final String? icon;

  /// Чей счёт. Пусто — общий: видят и правят оба. Иначе личный, и остаток
  /// чужого личного счёта второму участнику не показывается вовсе.
  final String? owner;

  /// Общий кошелёк пары: в него скидываются и из него платят общее.
  final bool isPot;

  /// Последние четыре цифры настоящей карты. Больше не храним и не спрашиваем:
  /// полный номер приложению не нужен ни для чего, а утечь может.
  final String? last4;

  /// Платёжная система — для знака в углу карточки.
  final CardBrand brand;

  /// Карта, наличные, накопительный или кредитная.
  final AccountKind kind;

  /// Оформление карточки: номер в наборе `cardDesigns`. Пусто — подбирается
  /// по имени, чтобы две карты не вышли одного цвета.
  final int? design;

  /// Фактура фона карты. По умолчанию имя повторами — так было с начала, и
  /// у заведённых раньше счетов вид не меняется сам собой.
  final CardTexture texture;

  /// Банк счёта — ПАКЕТ его приложения (`md.maib.mobile`).
  ///
  /// Хранится пакет, а не название: по нему Android отдаёт настоящий логотип с
  /// этого телефона, и он же связывает счёт с уведомлениями банка. Картинку не
  /// храним ни у себя, ни на сервере — чужие знаки нам возить незачем.
  final String? bank;

  const Account({
    required this.name,
    required this.currency,
    this.color,
    this.icon,
    this.owner,
    this.isPot = false,
    this.last4,
    this.brand = CardBrand.none,
    this.kind = AccountKind.card,
    this.design,
    this.texture = CardTexture.watermark,
    this.bank,
  });

  bool get isShared => owner == null || owner!.isEmpty;

  factory Account.fromJson(Map<String, dynamic> j) => Account(
    name: j['name'] as String,
    currency: j['currency'] as String? ?? 'MDL',
    color: _colorOf(j['color']),
    icon: j['icon'] as String?,
    owner: (j['owner'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['owner'] as String,
    isPot: j['isPot'] == true,
    last4: (j['last4'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${j['last4']}',
    brand: cardBrandOf(j['brand'] as String?),
    kind: accountKindOf((j['kind'] ?? j['card_kind']) as String?),
    design: (j['design'] as num?)?.toInt(),
    texture: cardTextureOf(j['texture'] as String?),
    bank: (j['bank'] as String?)?.trim().isEmpty ?? true
        ? null
        : '${j['bank']}',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'currency': currency,
    if (color != null)
      'color':
          '#${(color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    if (icon != null) 'icon': icon,
    if (owner != null) 'owner': owner,
    if (isPot) 'isPot': true,
    if (last4 != null) 'last4': last4,
    if (brand != CardBrand.none) 'brand': cardBrandName(brand),
    if (kind != AccountKind.card) 'kind': accountKindName(kind),
    if (texture != CardTexture.watermark) 'texture': cardTextureName(texture),
    if (design != null) 'design': design,
    if (bank != null) 'bank': bank,
  };

  Account copyWith({
    String? name,
    String? currency,
    int? color,
    String? icon,
    String? owner,
    bool? isPot,
    String? last4,
    CardBrand? brand,
    AccountKind? kind,
    int? design,
    CardTexture? texture,
    String? bank,
    bool clearOwner = false,
    bool clearLast4 = false,
    bool clearBank = false,
    bool clearIcon = false,
  }) => Account(
    name: name ?? this.name,
    currency: currency ?? this.currency,
    color: color ?? this.color,
    icon: clearIcon ? null : (icon ?? this.icon),
    owner: clearOwner ? null : (owner ?? this.owner),
    isPot: isPot ?? this.isPot,
    last4: clearLast4 ? null : (last4 ?? this.last4),
    brand: brand ?? this.brand,
    kind: kind ?? this.kind,
    design: design ?? this.design,
    texture: texture ?? this.texture,
    bank: clearBank ? null : (bank ?? this.bank),
  );
}

/// Цвет в бэкапе лежит строкой «#E8452B».
int? _colorOf(Object? raw) {
  if (raw is! String) return null;
  final hex = raw.replaceAll('#', '');
  final full = hex.length == 3 ? hex.split('').map((c) => '$c$c').join() : hex;
  final n = int.tryParse(full, radix: 16);
  return n == null ? null : 0xFF000000 | n;
}

/// Участник пары — АККАУНТ TOGETHERLY, а не своя запись в базе Money.
///
/// Человек входит почтой Togetherly, сервер отдаёт его пару из `groups`, и
/// участники приезжают оттуда уже собранными: приглашений, кодов и QR в Money
/// нет вовсе. Здесь лежит лишь кэш профиля, чтобы лента показывала имя и
/// аватар без сети; источник правды — сервер.
class Member {
  /// uid аккаунта Togetherly. По нему ссылаются счета, операции и дележ.
  final String uid;
  final String name;
  final String? avatarUrl;
  final int? color;

  /// Доля в общих тратах при дележе «по доходу», базисные пункты (сумма 10000).
  /// Договорённость пары, живёт на сервере; здесь копия для расчёта офлайн.
  final int incomeShareBp;

  const Member({
    required this.uid,
    required this.name,
    this.avatarUrl,
    this.color,
    this.incomeShareBp = 5000,
  });

  factory Member.fromJson(Map<String, dynamic> j) => Member(
    uid: '${j['uid'] ?? j['id'] ?? ''}',
    name: j['name'] as String? ?? '',
    avatarUrl: j['avatarUrl'] as String?,
    color: _colorOf(j['color']),
    incomeShareBp: (j['incomeShareBp'] as num?)?.toInt() ?? 5000,
  );

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'name': name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (color != null)
      'color':
          '#${(color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    'incomeShareBp': incomeShareBp,
  };

  Member copyWith({
    String? name,
    String? avatarUrl,
    int? color,
    int? incomeShareBp,
  }) => Member(
    uid: uid,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    color: color ?? this.color,
    incomeShareBp: incomeShareBp ?? this.incomeShareBp,
  );
}

/// Пара из Togetherly: id группы и её участники. Приезжает с сервера целиком,
/// локально лежит кэшем — чтобы приложение открывалось без сети тем же видом.
class Pair {
  final String groupId;
  final List<Member> members;
  final String baseCurrency;

  /// Правило дележа по умолчанию, о котором пара договорилась.
  final SplitMode defaultSplit;

  /// Когда пара началась, «ГГГГ-ММ-ДД». Приходит с сервера и в базу не
  /// сохраняется: нужно ровно для того, чтобы различить две пары с ОДНИМ
  /// человеком — так бывает, когда старую группу не распустили (13.09.2026).
  final String since;

  const Pair({
    this.groupId = '',
    this.members = const [],
    this.baseCurrency = 'MDL',
    this.defaultSplit = SplitMode.equal,
    this.since = '',
  });

  bool get isPaired => groupId.isNotEmpty && members.length > 1;

  Member? byUid(String? uid) {
    if (uid == null || uid.isEmpty) return null;
    for (final m in members) {
      if (m.uid == uid) return m;
    }
    return null;
  }

  Member? other(String uid) {
    for (final m in members) {
      if (m.uid != uid) return m;
    }
    return null;
  }

  Pair copyWith({
    String? groupId,
    List<Member>? members,
    String? baseCurrency,
    SplitMode? defaultSplit,
  }) => Pair(
    groupId: groupId ?? this.groupId,
    members: members ?? this.members,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    defaultSplit: defaultSplit ?? this.defaultSplit,
  );

  factory Pair.fromJson(Map<String, dynamic> j) => Pair(
    groupId: j['groupId'] as String? ?? '',
    members: _list(j['members'], Member.fromJson),
    baseCurrency: j['baseCurrency'] as String? ?? 'MDL',
    defaultSplit: splitModeOf(j['defaultSplit'] as String?),
  );

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'members': members.map((m) => m.toJson()).toList(),
    'baseCurrency': baseCurrency,
    'defaultSplit': defaultSplit.name,
  };
}

/// Как делится трата между участниками.
enum SplitMode {
  /// Никак: трата целиком того, кто платил. Так живут все операции одиночки.
  none,

  /// Поровну между участниками пары.
  equal,

  /// По долям дохода из [Member.incomeShareBp].
  income,

  /// Платил один, пользуется он же, но из общего кошелька.
  payerOnly,

  /// Доли заданы руками.
  custom,
}

SplitMode splitModeOf(String? raw) => switch (raw) {
  'equal' => SplitMode.equal,
  'income' => SplitMode.income,
  'payerOnly' => SplitMode.payerOnly,
  'custom' => SplitMode.custom,
  _ => SplitMode.none,
};

enum TxKind { expense, income, transfer, opening }

TxKind kindOf(String? raw) => switch (raw) {
  'income' => TxKind.income,
  'transfer' => TxKind.transfer,
  'opening' => TxKind.opening,
  _ => TxKind.expense,
};

class Transaction {
  final String id;
  final String date; // YYYY-MM-DD

  /// Время операции, ЧЧ:ММ. Пусто — время не записывали.
  ///
  /// Отдельным полем, а не внутри `date`: дата — ключ группировки по всему
  /// приложению (лента, бюджеты, отрезки, план), и превращать её в метку
  /// времени значило бы переписать половину расчётов ради минут.
  ///
  /// Заказчик попросил прямо: «в транзакции также добавь поддержку времени, а
  /// не только даты» (13.09.2026). Две покупки в один день выстраиваются по
  /// времени, а не по случайности.
  final String? time;
  final TxKind kind;
  final String account;
  final String currency;

  /// В валюте счёта, знак несёт направление.
  final double amount;

  /// В базовой валюте на момент операции.
  final double amountBase;
  final String? category;
  final String? subcategory;
  final String? note;

  /// Выравнивание остатка, спрятанное из списка. В сумму счёта входит всегда.
  final bool hidden;

  /// Кто записал операцию. Пусто — записи одиночки, сделанные до пары.
  final String? author;

  /// Кто платил. Отдельно от [author]: записать может и второй.
  final String? payer;

  /// Как делится между участниками.
  final SplitMode split;

  /// Доли в базисных пунктах при [SplitMode.custom]: {id участника: 6000}.
  final Map<String, int>? shares;

  /// Сюрприз: партнёр видит сумму и дату, но не видит сути. Сумма скрытой
  /// траты из баланса НЕ исчезает — иначе общий остаток врёт, а врущий
  /// остаток хуже скрытой детали.
  final bool secret;

  /// Когда сюрприз раскроется сам, ГГГГ-ММ-ДД.
  final String? revealAt;

  const Transaction({
    required this.id,
    required this.date,
    required this.kind,
    required this.account,
    required this.currency,
    required this.amount,
    required this.amountBase,
    this.category,
    this.subcategory,
    this.note,
    this.hidden = false,
    this.author,
    this.payer,
    this.split = SplitMode.none,
    this.shares,
    this.secret = false,
    this.revealAt,
    this.time,
  });

  /// Дата и время вместе. Без времени — полночь: так операция без него стоит
  /// в начале дня и не перескакивает через записи со временем.
  DateTime get at {
    final day = DateTime.tryParse(date) ?? DateTime(2000);
    final parts = (time ?? '').split(':');
    if (parts.length != 2) return day;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: '${j['id']}',
    date: j['date'] as String,
    kind: kindOf(j['kind'] as String?),
    account: j['account'] as String? ?? '',
    currency: j['currency'] as String? ?? 'MDL',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    amountBase: (j['amountBase'] as num?)?.toDouble() ?? 0,
    category: j['category'] as String?,
    subcategory: j['subcategory'] as String?,
    note: j['note'] as String?,
    hidden: j['hidden'] == true,
    author: j['author'] as String?,
    payer: j['payer'] as String?,
    split: splitModeOf(j['split'] as String?),
    shares: (j['shares'] as Map?)?.map(
      (k, v) => MapEntry('$k', (v as num).toInt()),
    ),
    secret: j['secret'] == true,
    revealAt: j['revealAt'] as String?,
    time: (j['time'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['time'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'kind': kind.name,
    'account': account,
    'currency': currency,
    'amount': amount,
    'amountBase': amountBase,
    if (category != null) 'category': category,
    if (subcategory != null) 'subcategory': subcategory,
    if (note != null) 'note': note,
    if (hidden) 'hidden': true,
    if (author != null) 'author': author,
    if (payer != null) 'payer': payer,
    if (split != SplitMode.none) 'split': split.name,
    if (shares != null) 'shares': shares,
    if (secret) 'secret': true,
    if (revealAt != null) 'revealAt': revealAt,
    if (time != null) 'time': time,
  };

  Transaction copyWith({
    /// Другой номер: нужен копии записи, которая уезжает в другую пару
    /// расчётом. Обычной правке он не нужен — id у записи один на всю жизнь.
    String? id,
    String? date,
    TxKind? kind,
    String? account,
    String? currency,
    double? amount,
    double? amountBase,
    String? category,
    String? subcategory,
    String? note,
    String? author,
    String? payer,
    SplitMode? split,
    Map<String, int>? shares,
    bool? secret,
    String? revealAt,
    String? time,

    /// Подкатегорию убрали: `subcategory: null` в copyWith неотличим от
    /// «не меняем», поэтому снятие просят отдельным флагом.
    bool clearSubcategory = false,
  }) => Transaction(
    id: id ?? this.id,
    date: date ?? this.date,
    kind: kind ?? this.kind,
    account: account ?? this.account,
    currency: currency ?? this.currency,
    amount: amount ?? this.amount,
    amountBase: amountBase ?? this.amountBase,
    category: category ?? this.category,
    subcategory: clearSubcategory ? null : (subcategory ?? this.subcategory),
    note: note ?? this.note,
    hidden: hidden,
    author: author ?? this.author,
    payer: payer ?? this.payer,
    split: split ?? this.split,
    shares: shares ?? this.shares,
    secret: secret ?? this.secret,
    revealAt: revealAt ?? this.revealAt,
    time: time ?? this.time,
  );
}

/// Вид расхода: нужда, желание или сбережение.
///
/// Без этой разметки правило распределения дохода (50/30/20 и любое другое)
/// считать не из чего: «продукты» — нужда, «кафе» — желание, «в подушку» —
/// сбережение. Пустое значение значит «не разметили», такие траты честно
/// показываются отдельной долей, а не приписываются к нуждам.
/// Расход категория или доход.
///
/// Раньше приложение это УГАДЫВАЛО по операциям: категория без единой траты не
/// принадлежала никуда, и на чистом устройстве оба списка стояли пустыми
/// («я не знаю, куда пишу категорию» — 13.09.2026). Теперь вид задаётся.
///
/// Поле необязательное НАРОЧНО: `null` значит «вид не задан», и такие
/// категории по-прежнему судятся по операциям. Иначе все заведённые до этой
/// правки разом стали бы расходными, включая зарплату.
enum CatKind { expense, income }

CatKind? catKindOf(String? raw) => switch (raw) {
  'expense' => CatKind.expense,
  'income' => CatKind.income,
  _ => null,
};

String catKindName(CatKind k) => k == CatKind.income ? 'income' : 'expense';

enum Bucket { none, needs, wants, savings }

Bucket bucketOf(String? raw) => switch (raw) {
  'needs' => Bucket.needs,
  'wants' => Bucket.wants,
  'savings' => Bucket.savings,
  _ => Bucket.none,
};

String bucketName(Bucket b) => switch (b) {
  Bucket.needs => 'needs',
  Bucket.wants => 'wants',
  Bucket.savings => 'savings',
  Bucket.none => '',
};

class Category {
  final String name;
  final String? parent;
  final int? color;
  final String? icon;

  /// Нужда, желание или сбережение. У подкатегории своего вида нет: она
  /// наследует вид родителя, иначе одна трата попадала бы в две доли.
  final Bucket bucket;

  /// Расход или доход. `null` — вид не задан, судим по операциям.
  final CatKind? kind;

  /// Счета, на которых эта категория показывается. Пусто — везде.
  ///
  /// Категория остаётся ОДНОЙ на пару: «Еда» в отчётах не распадается на
  /// «Еду карты» и «Еду наличных». Здесь только видимость на экране записи —
  /// у счёта «Яндекс Реклама» нет продуктов, а у карты нет рекламных
  /// поступлений, и предлагать их друг другу незачем.
  final List<String> accounts;

  const Category({
    required this.name,
    this.parent,
    this.color,
    this.icon,
    this.bucket = Bucket.none,
    this.accounts = const [],
    this.kind,
  });

  /// Считать ли категорию доходной. Задан вид — верим ему; не задан — прежнее
  /// правило по операциям решает снаружи.
  bool get isIncome => kind == CatKind.income;

  /// Показывать ли категорию на этом счёте.
  bool fitsAccount(String? account) =>
      accounts.isEmpty || account == null || accounts.contains(account);

  factory Category.fromJson(Map<String, dynamic> j) => Category(
    name: j['name'] as String,
    parent: j['parent'] as String?,
    color: _colorOf(j['color']),
    icon: j['icon'] as String?,
    bucket: bucketOf(j['bucket'] as String?),
    kind: catKindOf(j['kind'] as String?),
    accounts: [
      for (final a in (j['accounts'] as List?) ?? const [])
        if ('$a'.trim().isNotEmpty) '$a',
    ],
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    if (parent != null) 'parent': parent,
    if (color != null)
      'color':
          '#${(color! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
    if (icon != null) 'icon': icon,
    if (bucket != Bucket.none) 'bucket': bucketName(bucket),
    if (kind != null) 'kind': catKindName(kind!),
    if (accounts.isNotEmpty) 'accounts': accounts,
  };

  Category copyWith({
    String? name,
    String? parent,
    int? color,
    String? icon,
    Bucket? bucket,
    List<String>? accounts,
    CatKind? kind,
  }) => Category(
    name: name ?? this.name,
    parent: parent ?? this.parent,
    color: color ?? this.color,
    icon: icon ?? this.icon,
    bucket: bucket ?? this.bucket,
    accounts: accounts ?? this.accounts,
    kind: kind ?? this.kind,
  );
}

/// Конверт считается за день, неделю или месяц. Личные траты пара
/// договаривается держать в дневном или недельном пределе, а квартплату — в
/// месячном: один период на всё не годится.
/// Как часто предел обнуляется. `custom` — свой отрезок в днях, `once` —
/// не обнуляется вовсе: предел на ремонт это сумма на весь ремонт.
enum BudgetPeriod { daily, weekly, monthly, custom, once }

BudgetPeriod budgetPeriodOf(String? raw) => switch (raw) {
  'daily' => BudgetPeriod.daily,
  'weekly' => BudgetPeriod.weekly,
  'custom' => BudgetPeriod.custom,
  'once' => BudgetPeriod.once,
  _ => BudgetPeriod.monthly,
};

String budgetPeriodName(BudgetPeriod p) => switch (p) {
  BudgetPeriod.daily => 'daily',
  BudgetPeriod.weekly => 'weekly',
  BudgetPeriod.monthly => 'monthly',
  BudgetPeriod.custom => 'custom',
  BudgetPeriod.once => 'once',
};

class Budget {
  final String category;
  final String? subcategory;
  final double limit;
  final String currency;
  final String period;

  /// Неизрасходованный остаток переносится на следующий период. Без этого
  /// лимит — месячный потолок, а не конверт: сэкономил в марте, в апреле это
  /// ничего не значит.
  final bool rollover;

  /// Длина своего отрезка в днях. Нужна только периоду `custom`: «каждые
  /// десять дней» не выражается ни днём, ни неделей, ни месяцем.
  final int? days;

  /// С какого дня бюджет живёт. У `custom` от него отсчитываются отрезки, у
  /// `once` — с него считаются траты: предел на ремонт не должен вбирать в
  /// себя прошлогоднюю плитку.
  final String? startDate;

  /// Своё имя, значок и цвет — как у цели и счёта.
  ///
  /// Пусто — бюджет зовётся своей категорией и берёт её знак: «Зал» и так
  /// понятнее, чем «Бюджет №2». Имя нужно, когда категорий несколько:
  /// «Машина» из бензина, мойки и страховки одним именем не назовёшь.
  final String? name;
  final String? icon;
  final int? color;

  /// Ещё категории, кроме главной. Бюджет на машину — это бензин, мойка и
  /// страховка вместе: по отдельности человек их не планирует.
  final List<String> extraCategories;

  /// Считать только по этим счетам. Пусто — по всем: у бюджета на еду нет
  /// причины отличать карту от наличных, а у бюджета на командировки — есть.
  final List<String> accounts;

  const Budget({
    required this.category,
    this.subcategory,
    required this.limit,
    required this.currency,
    required this.period,
    this.rollover = false,
    this.days,
    this.startDate,
    this.name,
    this.icon,
    this.color,
    this.extraCategories = const [],
    this.accounts = const [],
  });

  /// Все категории бюджета: главная и дополнительные.
  List<String> get categories => [category, ...extraCategories];

  /// Как бюджет зовётся на экране.
  String get title => (name ?? '').trim().isNotEmpty
      ? name!.trim()
      : (subcategory == null ? category : '$category · $subcategory');

  BudgetPeriod get periodKind => budgetPeriodOf(period);

  factory Budget.fromJson(Map<String, dynamic> j) => Budget(
    category: j['category'] as String? ?? '',
    subcategory: j['subcategory'] as String?,
    limit: (j['limit'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'MDL',
    period: j['period'] as String? ?? 'monthly',
    rollover: j['rollover'] == true,
    days: (j['days'] as num?)?.toInt(),
    startDate: (j['start_date'] ?? j['startDate']) as String?,
    name: (j['name'] as String?)?.trim().isEmpty ?? true
        ? null
        : (j['name'] as String).trim(),
    icon: (j['icon'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['icon'] as String,
    color: (j['color'] as num?)?.toInt(),
    extraCategories: [
      for (final c
          in (j['extra_categories'] ?? j['extraCategories'] ?? const [])
              as List)
        '$c',
    ],
    accounts: [for (final a in (j['accounts'] ?? const []) as List) '$a'],
  );

  Map<String, dynamic> toJson() => {
    'category': category,
    if (subcategory != null) 'subcategory': subcategory,
    'limit': limit,
    'currency': currency,
    'period': period,
    if (rollover) 'rollover': true,
    if (days != null) 'days': days,
    if (startDate != null) 'start_date': startDate,
    if (name != null) 'name': name,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
    if (extraCategories.isNotEmpty) 'extra_categories': extraCategories,
    if (accounts.isNotEmpty) 'accounts': accounts,
  };

  Budget copyWith({
    double? limit,
    String? currency,
    String? period,
    bool? rollover,
    int? days,
    String? startDate,
    String? name,
    String? icon,
    int? color,
    List<String>? extraCategories,
    List<String>? accounts,
  }) => Budget(
    category: category,
    subcategory: subcategory,
    limit: limit ?? this.limit,
    currency: currency ?? this.currency,
    period: period ?? this.period,
    rollover: rollover ?? this.rollover,
    days: days ?? this.days,
    startDate: startDate ?? this.startDate,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    extraCategories: extraCategories ?? this.extraCategories,
    accounts: accounts ?? this.accounts,
  );
}

/// Обычная цель или резерв. У резерва сумма не задаётся руками: она считается
/// из собственных расходов, потому что «шесть месяцев» остаётся верным и когда
/// траты выросли, а «60 000» устаревает молча.
enum GoalKind { plain, reserve }

GoalKind goalKindOf(String? raw) =>
    raw == 'reserve' ? GoalKind.reserve : GoalKind.plain;

class Goal {
  final String name;
  final double target;
  final String currency;
  final String? deadline;
  final GoalKind kind;

  /// Сколько месяцев своих расходов должен покрывать резерв. Статьи советуют
  /// от четырёх до шести.
  final int months;

  /// Значок цели. Пусто — подбирается по имени, как у счёта.
  final String? icon;

  /// Цвет цели. Пусто — берётся по имени из палитры меток.
  final int? color;

  const Goal({
    required this.name,
    required this.target,
    required this.currency,
    this.deadline,
    this.kind = GoalKind.plain,
    this.months = 0,
    this.icon,
    this.color,
  });

  bool get isReserve => kind == GoalKind.reserve;

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
    name: j['name'] as String? ?? '',
    target: (j['target'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'MDL',
    deadline: j['deadline'] as String?,
    kind: goalKindOf(j['kind'] as String?),
    months: (j['months'] as num?)?.toInt() ?? 0,
    icon: (j['icon'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['icon'] as String,
    color: (j['color'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'target': target,
    'currency': currency,
    if (deadline != null) 'deadline': deadline,
    if (kind != GoalKind.plain) 'kind': 'reserve',
    if (months > 0) 'months': months,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
  };

  Goal copyWith({
    double? target,
    String? currency,
    String? deadline,
    GoalKind? kind,
    int? months,
    String? icon,
    int? color,
    bool clearIcon = false,
    bool clearColor = false,
  }) => Goal(
    name: name,
    icon: clearIcon ? null : (icon ?? this.icon),
    color: clearColor ? null : (color ?? this.color),
    target: target ?? this.target,
    currency: currency ?? this.currency,
    deadline: deadline ?? this.deadline,
    kind: kind ?? this.kind,
    months: months ?? this.months,
  );
}

/// Как часто повторяется платёж. Недели тут нет намеренно: регулярное в
/// семейном бюджете привязано к зарплате и счетам, а они приходят раз в месяц
/// или раз в год.
/// Как часто запись срабатывает. `custom` — каждые N дней, `once` — один раз
/// и всё: у платежа по рассрочке последний взнос ничем не отличается от
/// первого, а вот у брони билета повтора нет вовсе.
enum RecurringEvery { weekly, monthly, quarterly, yearly, custom, once }

RecurringEvery recurringEveryOf(String? raw) => switch (raw) {
  'weekly' => RecurringEvery.weekly,
  'quarterly' => RecurringEvery.quarterly,
  'yearly' => RecurringEvery.yearly,
  'custom' => RecurringEvery.custom,
  'once' => RecurringEvery.once,
  _ => RecurringEvery.monthly,
};

String recurringEveryName(RecurringEvery e) => switch (e) {
  RecurringEvery.weekly => 'weekly',
  RecurringEvery.monthly => 'monthly',
  RecurringEvery.quarterly => 'quarterly',
  RecurringEvery.yearly => 'yearly',
  RecurringEvery.custom => 'custom',
  RecurringEvery.once => 'once',
};

/// Что делает регулярная запись: платит наружу, приносит доход, откладывает в
/// цель или гасит долг.
///
/// `goal` — это и есть «заплати себе первым»: взнос уходит сразу после дохода,
/// а не из того, что осталось к концу месяца.
enum RecurringKind { expense, income, goal, debt }

RecurringKind recurringKindOf(String? raw) => switch (raw) {
  'income' => RecurringKind.income,
  'goal' => RecurringKind.goal,
  'debt' => RecurringKind.debt,
  _ => RecurringKind.expense,
};

String recurringKindName(RecurringKind k) => switch (k) {
  RecurringKind.income => 'income',
  RecurringKind.goal => 'goal',
  RecurringKind.debt => 'debt',
  RecurringKind.expense => 'expense',
};

class Recurring {
  final String id;
  final String name;
  final double amount;
  final String currency;
  final String account;
  final String? category;
  final String interval;
  final String nextDate;
  final String kind;
  final bool active;

  /// Куда откладывать или какой долг гасить: имя цели или долга.
  final String target;

  /// Когда сработало в последний раз, ГГГГ-ММ-ДД. По нему видно, что запись
  /// уже отработала этот срок, и повторного списания не будет.
  final String lastRun;

  /// Чья запись. Пусто — общая для пары.
  final String? owner;

  /// Длина своего интервала в днях. Нужна только `custom`.
  final int? days;

  /// Свой значок и цвет — как у бюджета и цели: подписка узнаётся знаком
  /// раньше, чем читается имя. Пусто — подбираются по имени и виду.
  final String? icon;
  final int? color;

  const Recurring({
    required this.id,
    required this.name,
    required this.amount,
    required this.currency,
    required this.account,
    this.category,
    required this.interval,
    required this.nextDate,
    required this.kind,
    required this.active,
    this.target = '',
    this.lastRun = '',
    this.owner,
    this.days,
    this.icon,
    this.color,
  });

  RecurringKind get kindOf => recurringKindOf(kind);
  RecurringEvery get every => recurringEveryOf(interval);

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
    id: '${j['id']}',
    name: j['name'] as String? ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    currency: j['currency'] as String? ?? 'MDL',
    account: j['account'] as String? ?? '',
    category: j['category'] as String?,
    interval:
        j['interval'] as String? ?? j['interval_rule'] as String? ?? 'monthly',
    nextDate: j['nextDate'] as String? ?? j['next_date'] as String? ?? '',
    kind: j['kind'] as String? ?? 'expense',
    active: j['active'] != false,
    target: j['target'] as String? ?? j['goal'] as String? ?? '',
    lastRun: j['lastRun'] as String? ?? j['last_run'] as String? ?? '',
    owner: (j['owner'] ?? j['owner_uid']) as String?,
    days: (j['days'] as num?)?.toInt(),
    icon: (j['icon'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['icon'] as String,
    color: (j['color'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amount': amount,
    'currency': currency,
    'account': account,
    if (category != null) 'category': category,
    'interval': interval,
    'nextDate': nextDate,
    'kind': kind,
    'active': active,
    if (target.isNotEmpty) 'target': target,
    if (lastRun.isNotEmpty) 'lastRun': lastRun,
    if ((owner ?? '').isNotEmpty) 'owner': owner,
    if (days != null) 'days': days,
    if (icon != null) 'icon': icon,
    if (color != null) 'color': color,
  };

  Recurring copyWith({
    String? name,
    double? amount,
    String? currency,
    String? account,
    String? category,
    String? interval,
    String? nextDate,
    String? kind,
    bool? active,
    String? target,
    String? lastRun,
    String? owner,
    int? days,
    String? icon,
    int? color,
  }) => Recurring(
    id: id,
    name: name ?? this.name,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    account: account ?? this.account,
    category: category ?? this.category,
    interval: interval ?? this.interval,
    nextDate: nextDate ?? this.nextDate,
    kind: kind ?? this.kind,
    active: active ?? this.active,
    target: target ?? this.target,
    lastRun: lastRun ?? this.lastRun,
    owner: owner ?? this.owner,
    days: days ?? this.days,
    icon: icon ?? this.icon,
    color: color ?? this.color,
  );
}

/// Долг: кредит, карта, микрозайм, ипотека.
///
/// Остаток не хранится числом — он считается из платежей, как накопленное у
/// цели: иначе «осталось» разойдётся с историей на первом же платеже. Здесь
/// лежат условия, по которым считается порядок погашения: ставка для «лавины»
/// и остаток для «снежного кома».
enum DebtKind { loan, card, microloan, mortgage }

DebtKind debtKindOf(String? raw) => switch (raw) {
  'card' => DebtKind.card,
  'microloan' => DebtKind.microloan,
  'mortgage' => DebtKind.mortgage,
  _ => DebtKind.loan,
};

String debtKindName(DebtKind k) => switch (k) {
  DebtKind.card => 'card',
  DebtKind.microloan => 'microloan',
  DebtKind.mortgage => 'mortgage',
  DebtKind.loan => 'loan',
};

String debtKindTitle(DebtKind k) => switch (k) {
  DebtKind.card => 'Кредитная карта',
  DebtKind.microloan => 'Микрозайм',
  DebtKind.mortgage => 'Ипотека',
  DebtKind.loan => 'Кредит',
};

class Debt {
  /// Имя — ключ: по нему живёт и счёт долга.
  final String name;
  final DebtKind kind;

  /// Сколько всего предстоит вернуть.
  final double principal;

  /// Годовая ставка в процентах.
  final double rate;

  /// Минимальный платёж в месяц.
  final double minPayment;
  final String currency;
  final String? opened;

  /// Число месяца, когда платить. 0 — не задано.
  final int dueDay;

  /// Чей долг. Пусто — общий долг пары; личный долг партнёра на устройство не
  /// приезжает вовсе, как и личный счёт.
  final String? owner;

  const Debt({
    required this.name,
    this.kind = DebtKind.loan,
    required this.principal,
    this.rate = 0,
    this.minPayment = 0,
    required this.currency,
    this.opened,
    this.dueDay = 0,
    this.owner,
  });

  bool get isShared => (owner ?? '').isEmpty;

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
    name: '${j['name'] ?? ''}',
    kind: debtKindOf(j['kind'] as String?),
    principal: (j['principal'] as num?)?.toDouble() ?? 0,
    rate: (j['rate'] as num?)?.toDouble() ?? 0,
    minPayment: _dbl(j['minPayment'] ?? j['min_payment']),
    currency: j['currency'] as String? ?? 'MDL',
    opened: j['opened'] as String?,
    dueDay:
        (j['dueDay'] as num?)?.toInt() ?? (j['due_day'] as num?)?.toInt() ?? 0,
    owner: (j['owner'] ?? j['owner_uid']) as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': debtKindName(kind),
    'principal': principal,
    'rate': rate,
    'minPayment': minPayment,
    'currency': currency,
    if (opened != null) 'opened': opened,
    if (dueDay > 0) 'dueDay': dueDay,
    if ((owner ?? '').isNotEmpty) 'owner': owner,
  };

  Debt copyWith({
    DebtKind? kind,
    double? principal,
    double? rate,
    double? minPayment,
    String? currency,
    String? opened,
    int? dueDay,
    String? owner,
  }) => Debt(
    name: name,
    kind: kind ?? this.kind,
    principal: principal ?? this.principal,
    rate: rate ?? this.rate,
    minPayment: minPayment ?? this.minPayment,
    currency: currency ?? this.currency,
    opened: opened ?? this.opened,
    dueDay: dueDay ?? this.dueDay,
    owner: owner ?? this.owner,
  );
}

/// Строка плана на месяц: «каждый рубль имеет работу».
///
/// План задаётся по категориям, целям и долгам; остаток нераспределённого
/// обязан сойтись в ноль — в этом весь смысл бюджета с нулевым балансом.
enum PlanItemKind { category, goal, debt }

PlanItemKind planItemKindOf(String? raw) => switch (raw) {
  'goal' => PlanItemKind.goal,
  'debt' => PlanItemKind.debt,
  _ => PlanItemKind.category,
};

String planItemKindName(PlanItemKind k) => switch (k) {
  PlanItemKind.goal => 'goal',
  PlanItemKind.debt => 'debt',
  PlanItemKind.category => 'category',
};

class PlanItem {
  /// ГГГГ-ММ.
  final String month;
  final PlanItemKind kind;
  final String name;
  final double amount;

  const PlanItem({
    required this.month,
    required this.kind,
    required this.name,
    required this.amount,
  });

  String get key => '$month|${planItemKindName(kind)}|$name';

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
    month: '${j['month'] ?? ''}',
    kind: planItemKindOf((j['kind'] ?? j['item_kind']) as String?),
    name: '${j['name'] ?? j['item_name'] ?? ''}',
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'month': month,
    'kind': planItemKindName(kind),
    'name': name,
    'amount': amount,
  };
}

/// О чём пара договорилась: лимит на категорию, правило дележа, взнос в общий
/// кошелёк. Меняется ПРЕДЛОЖЕНИЕМ, а не молча: общий бюджет — это договор
/// двоих, и один человек не переписывает его в одиночку.
enum AgreementKind { limit, splitDefault, potTransfer }

AgreementKind agreementKindOf(String? raw) => switch (raw) {
  'splitDefault' => AgreementKind.splitDefault,
  'potTransfer' => AgreementKind.potTransfer,
  _ => AgreementKind.limit,
};

enum AgreementStatus { proposed, active, declined }

AgreementStatus agreementStatusOf(String? raw) => switch (raw) {
  'active' => AgreementStatus.active,
  'declined' => AgreementStatus.declined,
  _ => AgreementStatus.proposed,
};

class Agreement {
  final String id;
  final AgreementKind kind;
  final Map<String, dynamic> payload;
  final AgreementStatus status;
  final String proposedBy;
  final String acceptedBy;
  final String effectiveFrom;

  const Agreement({
    required this.id,
    this.kind = AgreementKind.limit,
    this.payload = const {},
    this.status = AgreementStatus.proposed,
    this.proposedBy = '',
    this.acceptedBy = '',
    this.effectiveFrom = '',
  });

  /// Категория предложенного бюджета — по ней экран строит заголовок. Само
  /// слово («Бюджет на «Зал»») собирается в экране: модель языка не знает, а
  /// заголовок на экране бывает на семи.
  String get category => '${payload['category'] ?? ''}';

  /// Бюджет целиком, как его задал человек.
  ///
  /// Раньше в предложении ехали только категория и сумма, и согласие партнёра
  /// собирало из них МЕСЯЧНЫЙ бюджет: подкатегория, недельный период, перенос
  /// остатка и своя валюта пропадали по дороге. Человек выбирал одно, а пара
  /// получала другое.
  Budget? get budget {
    final raw = payload['budget'];
    if (raw is! Map) return null;
    return Budget.fromJson(raw.cast<String, dynamic>());
  }

  double get amount => (payload['amount'] as num?)?.toDouble() ?? 0;
  double get oldAmount => (payload['was'] as num?)?.toDouble() ?? 0;
  String get note => (payload['note'] as String?) ?? '';

  factory Agreement.fromJson(Map<String, dynamic> j) => Agreement(
    id: '${j['id']}',
    kind: agreementKindOf(j['kind'] as String?),
    payload: ((j['payload'] as Map?) ?? const {}).cast<String, dynamic>(),
    status: agreementStatusOf(j['status'] as String?),
    proposedBy: j['proposed_by'] as String? ?? j['proposedBy'] as String? ?? '',
    acceptedBy: j['accepted_by'] as String? ?? j['acceptedBy'] as String? ?? '',
    effectiveFrom:
        j['effective_from'] as String? ?? j['effectiveFrom'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'payload': payload,
    'status': status.name,
    'proposed_by': proposedBy,
    'accepted_by': acceptedBy,
    'effective_from': effectiveFrom,
  };

  Agreement copyWith({AgreementStatus? status, String? acceptedBy}) =>
      Agreement(
        id: id,
        kind: kind,
        payload: payload,
        status: status ?? this.status,
        proposedBy: proposedBy,
        acceptedBy: acceptedBy ?? this.acceptedBy,
        effectiveFrom: effectiveFrom,
      );
}

/// Правила, о которых пара договорилась один раз и живёт по ним.
///
/// Держатся вместе, а не пятью полями базы: это один разговор — «как мы
/// обращаемся с деньгами», и уезжают они на сервер одной правкой настроек.
class Rules {
  /// Куда уходит доход: доли в базисных пунктах (сумма 10000). По умолчанию
  /// 50/30/20 — правило из обеих статей про семейный бюджет.
  final int needsBp;
  final int wantsBp;
  final int savingsBp;

  /// Округлять покупку вверх до кратного и разницу класть в цель. 0 —
  /// выключено. Значение в единицах валюты: 10, 50, 100.
  final int roundUpStep;
  final String roundUpGoal;

  /// Раз во сколько месяцев пересматривать бюджет. 0 — не напоминать.
  final int reviewMonths;

  /// Когда пересматривали в последний раз, ГГГГ-ММ-ДД.
  final String reviewAt;

  /// Предупреждать партнёра о снятии из общего кошелька.
  final bool potNotice;

  /// Больше этой суммы из общего кошелька за раз не берут без разговора.
  /// Ноль — без предела.
  final double potMaxOnce;

  /// Когда пара села говорить о деньгах, ГГГГ-ММ-ДД. Пусто — не назначено.
  ///
  /// «Money date» из Zeta: разговор о деньгах назначают заранее, как встречу,
  /// иначе он не случается никогда. Отличается от `reviewAt` тем, что это
  /// БУДУЩЕЕ свидание, а не отметка «сверились».
  final String moneyDate;

  /// О трате крупнее этой пара договорилась предупреждать друг друга — с
  /// ЛЮБОГО счёта, не только из общего кошелька. Ноль — не предупреждать.
  ///
  /// Приём из Honeydue (spending alerts): «мы договорились говорить друг другу
  /// про покупки дороже пяти тысяч» — обычная семейная договорённость, и
  /// приложение напоминает о ней в момент записи, а не в отчёте через месяц.
  final double bigSpend;

  const Rules({
    this.needsBp = 5000,
    this.wantsBp = 3000,
    this.savingsBp = 2000,
    this.roundUpStep = 0,
    this.roundUpGoal = '',
    this.bigSpend = 0,
    this.moneyDate = '',
    this.reviewMonths = 0,
    this.reviewAt = '',
    this.potNotice = false,
    this.potMaxOnce = 0,
  });

  factory Rules.fromJson(Map<String, dynamic> j) {
    final targets = (j['plan_targets'] ?? j['planTargets']) as Map?;
    final pot = (j['pot_rules'] ?? j['potRules']) as Map?;
    int bp(String key, int fallback) {
      final v = targets?[key];
      return v is num && v > 0 ? v.toInt() : fallback;
    }

    return Rules(
      needsBp: bp('needs', 5000),
      wantsBp: bp('wants', 3000),
      savingsBp: bp('savings', 2000),
      roundUpStep: ((j['round_up'] ?? j['roundUpStep']) as num?)?.toInt() ?? 0,
      roundUpGoal: '${j['round_up_goal'] ?? j['roundUpGoal'] ?? ''}',
      reviewMonths:
          ((j['review_months'] ?? j['reviewMonths']) as num?)?.toInt() ?? 0,
      reviewAt: '${j['review_at'] ?? j['reviewAt'] ?? ''}',
      potNotice: (pot?['notice'] ?? false) == true,
      potMaxOnce: _dbl(pot?['max_once'] ?? pot?['maxOnce']),
      bigSpend: _dbl(pot?['big_spend'] ?? pot?['bigSpend']),
      moneyDate: '${pot?['money_date'] ?? pot?['moneyDate'] ?? ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'planTargets': {'needs': needsBp, 'wants': wantsBp, 'savings': savingsBp},
    'roundUpStep': roundUpStep,
    'roundUpGoal': roundUpGoal,
    'reviewMonths': reviewMonths,
    'reviewAt': reviewAt,
    'potRules': {
      'notice': potNotice,
      'maxOnce': potMaxOnce,
      'bigSpend': bigSpend,
      'moneyDate': moneyDate,
    },
  };

  /// Тело для сервера: там имена полей в змеиной нотации.
  Map<String, dynamic> toServer() => {
    'plan_targets': {'needs': needsBp, 'wants': wantsBp, 'savings': savingsBp},
    'round_up': roundUpStep,
    'round_up_goal': roundUpGoal,
    'review_months': reviewMonths,
    'review_at': reviewAt,
    'pot_rules': {
      'notice': potNotice,
      'max_once': potMaxOnce,
      'big_spend': bigSpend,
      'money_date': moneyDate,
    },
  };

  Rules copyWith({
    int? needsBp,
    int? wantsBp,
    int? savingsBp,
    int? roundUpStep,
    String? roundUpGoal,
    int? reviewMonths,
    String? reviewAt,
    bool? potNotice,
    double? potMaxOnce,
    double? bigSpend,
    String? moneyDate,
  }) => Rules(
    needsBp: needsBp ?? this.needsBp,
    wantsBp: wantsBp ?? this.wantsBp,
    savingsBp: savingsBp ?? this.savingsBp,
    roundUpStep: roundUpStep ?? this.roundUpStep,
    roundUpGoal: roundUpGoal ?? this.roundUpGoal,
    reviewMonths: reviewMonths ?? this.reviewMonths,
    reviewAt: reviewAt ?? this.reviewAt,
    potNotice: potNotice ?? this.potNotice,
    potMaxOnce: potMaxOnce ?? this.potMaxOnce,
    bigSpend: bigSpend ?? this.bigSpend,
    moneyDate: moneyDate ?? this.moneyDate,
  );
}

/// Реплика под операцией.
///
/// Половина ссор о деньгах начинается с непонятного списания, и вопрос
/// задаётся прямо здесь — иначе он уходит в мессенджер, где нет ни суммы, ни
/// даты, ни счёта.
class Comment {
  final String id;
  final String txId;

  /// Кто сказал. Пусто не бывает: автора ставит сервер по сессии.
  final String uid;
  final String text;

  /// Короткий отклик вместо слов: «понял», «а это что?». Хранится отдельно от
  /// текста, чтобы отклик можно было поставить, ничего не печатая.
  final String emoji;

  /// Когда сказано, миллисекунды. У сервера это `updated`: реплику не правят,
  /// её добавляют и удаляют, поэтому одно поле отвечает за оба смысла.
  final int created;

  const Comment({
    required this.id,
    required this.txId,
    required this.uid,
    this.text = '',
    this.emoji = '',
    this.created = 0,
  });

  bool get isEmpty => text.trim().isEmpty && emoji.isEmpty;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: '${j['id'] ?? ''}',
    txId: '${j['tx_id'] ?? j['txId'] ?? ''}',
    uid: '${j['uid'] ?? ''}',
    text: j['text'] as String? ?? '',
    emoji: j['emoji'] as String? ?? '',
    created:
        (j['created'] as num?)?.toInt() ?? (j['updated'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tx_id': txId,
    'uid': uid,
    if (text.isNotEmpty) 'text': text,
    if (emoji.isNotEmpty) 'emoji': emoji,
    'created': created,
  };

  Comment copyWith({String? text, String? emoji}) => Comment(
    id: id,
    txId: txId,
    uid: uid,
    text: text ?? this.text,
    emoji: emoji ?? this.emoji,
    created: created,
  );
}

class Database {
  final String baseCurrency;
  final Map<String, double> rates;
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Category> categories;
  final List<Budget> budgets;
  final List<Goal> goals;
  final List<Recurring> recurring;

  /// Пара из Togetherly: кто в ней и на каком правиле дележа сошлись.
  /// Приезжает с сервера вместе с сессией, здесь лежит кэшем.
  final Pair pair;

  /// О чём договорились и что ещё обсуждается.
  final List<Agreement> agreements;

  /// Разговор под операциями.
  final List<Comment> comments;

  /// Долги пары: кредиты, карты, микрозаймы, ипотека.
  final List<Debt> debts;

  /// План по месяцам: сколько на что отведено.
  final List<PlanItem> plan;

  /// Правила, о которых пара договорилась.
  final Rules rules;

  const Database({
    this.baseCurrency = 'MDL',
    this.rates = const {},
    this.accounts = const [],
    this.transactions = const [],
    this.categories = const [],
    this.budgets = const [],
    this.goals = const [],
    this.recurring = const [],
    this.pair = const Pair(),
    this.agreements = const [],
    this.comments = const [],
    this.debts = const [],
    this.plan = const [],
    this.rules = const Rules(),
  });

  factory Database.fromJson(Map<String, dynamic> j) => Database(
    baseCurrency: j['baseCurrency'] as String? ?? 'MDL',
    rates: ((j['rates'] as Map?) ?? const {}).map(
      (k, v) => MapEntry('$k', (v as num).toDouble()),
    ),
    accounts: _list(j['accounts'], Account.fromJson),
    transactions: _list(j['transactions'], Transaction.fromJson),
    categories: _list(j['categories'], Category.fromJson),
    budgets: _list(j['budgets'], Budget.fromJson),
    goals: _list(j['goals'], Goal.fromJson),
    recurring: _list(j['recurring'], Recurring.fromJson),
    comments: _list(j['comments'], Comment.fromJson),
    debts: _list(j['debts'], Debt.fromJson),
    plan: _list(j['plan'], PlanItem.fromJson),
    rules: Rules.fromJson(
      ((j['rules'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    pair: Pair.fromJson(
      ((j['pair'] as Map?) ?? const {}).cast<String, dynamic>(),
    ),
    agreements: _list(j['agreements'], Agreement.fromJson),
  );

  Map<String, dynamic> toJson() => {
    'baseCurrency': baseCurrency,
    'rates': rates,
    'accounts': accounts.map((a) => a.toJson()).toList(),
    'transactions': transactions.map((t) => t.toJson()).toList(),
    'categories': categories.map((c) => c.toJson()).toList(),
    'budgets': budgets.map((b) => b.toJson()).toList(),
    'goals': goals.map((g) => g.toJson()).toList(),
    'recurring': recurring.map((r) => r.toJson()).toList(),
    'pair': pair.toJson(),
    'agreements': agreements.map((a) => a.toJson()).toList(),
    'comments': comments.map((c) => c.toJson()).toList(),
    'debts': debts.map((d) => d.toJson()).toList(),
    'plan': plan.map((x) => x.toJson()).toList(),
    'rules': rules.toJson(),
  };

  Database copyWith({
    String? baseCurrency,
    Map<String, double>? rates,
    List<Account>? accounts,
    List<Transaction>? transactions,
    List<Category>? categories,
    List<Budget>? budgets,
    List<Goal>? goals,
    List<Recurring>? recurring,
    Pair? pair,
    List<Agreement>? agreements,
    List<Comment>? comments,
    List<Debt>? debts,
    List<PlanItem>? plan,
    Rules? rules,
  }) => Database(
    baseCurrency: baseCurrency ?? this.baseCurrency,
    rates: rates ?? this.rates,
    accounts: accounts ?? this.accounts,
    transactions: transactions ?? this.transactions,
    categories: categories ?? this.categories,
    budgets: budgets ?? this.budgets,
    goals: goals ?? this.goals,
    recurring: recurring ?? this.recurring,
    pair: pair ?? this.pair,
    agreements: agreements ?? this.agreements,
    comments: comments ?? this.comments,
    debts: debts ?? this.debts,
    plan: plan ?? this.plan,
    rules: rules ?? this.rules,
  );

  bool get isEmpty => accounts.isEmpty && transactions.isEmpty;
}

double _dbl(Object? raw) => raw is num ? raw.toDouble() : 0;

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) make) =>
    (raw as List?)
        ?.whereType<Map>()
        .map((m) => make(m.cast<String, dynamic>()))
        .toList() ??
    [];
