/// Справочник валют: код, имя и флаг.
///
/// Нужен поиску: девять пилюль в столбик — это не выбор валюты, а список
/// того, что успели вспомнить. Имена лежат здесь ДАННЫМИ (как корни разбора
/// уведомлений), поэтому файл перечислен в стороже словаря явно.
library;

/// Валюта: имя по-русски и по-английски.
class CurrencyInfo {
  final String code;
  final String ru;
  final String en;

  const CurrencyInfo(this.code, this.ru, this.en);
}

/// Флаг валюты одним эмодзи.
///
/// Считается из кода: первые две буквы валюты почти всегда код страны
/// (USD → US, MDL → MD, RUB → RU), а региональные индикаторы складываются из
/// латинских букв сдвигом. Картинок флагов в приложении нет и не нужно.
String flagOf(String code) {
  const special = <String, String>{
    'EUR': '🇪🇺',
    'XAF': '🌍',
    'XOF': '🌍',
    'XCD': '🌎',
    'XPF': '🌏',
    'XAU': '🪙',
    'XAG': '🪙',
    'XDR': '🏦',
    'BTC': '🪙',
    'USDT': '🪙',
  };
  final up = code.toUpperCase();
  final hit = special[up];
  if (hit != null) return hit;
  if (up.length < 2) return '🏳️';
  final a = up.codeUnitAt(0);
  final b = up.codeUnitAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🏳️';
  return String.fromCharCode(0x1F1E6 + a - 65) +
      String.fromCharCode(0x1F1E6 + b - 65);
}

/// Имя валюты на языке интерфейса; незнакомой — её же код.
String currencyName(String code, {bool russian = true}) {
  final hit = currencyTable[code.toUpperCase()];
  if (hit == null) return code.toUpperCase();
  return russian ? hit.ru : hit.en;
}

/// Поиск по коду и по имени: «доллар», «usd», «dollar».
List<CurrencyInfo> searchCurrencies(String query, {bool russian = true}) {
  final q = query.trim().toLowerCase();
  final all = currencyTable.values.toList();
  if (q.isEmpty) return all;
  return all
      .where((c) =>
          c.code.toLowerCase().contains(q) ||
          c.ru.toLowerCase().contains(q) ||
          c.en.toLowerCase().contains(q))
      .toList();
}

/// Ходовые валюты мира. Полный список ISO-4217 сюда не нужен: в нём сотня
/// валют, которых человек не увидит никогда, а свою он всегда может завести
/// кодом.
const currencyTable = <String, CurrencyInfo>{
  'MDL': CurrencyInfo('MDL', 'Молдавский лей', 'Moldovan leu'),
  'RON': CurrencyInfo('RON', 'Румынский лей', 'Romanian leu'),
  'EUR': CurrencyInfo('EUR', 'Евро', 'Euro'),
  'USD': CurrencyInfo('USD', 'Доллар США', 'US dollar'),
  'RUB': CurrencyInfo('RUB', 'Российский рубль', 'Russian ruble'),
  'UAH': CurrencyInfo('UAH', 'Украинская гривна', 'Ukrainian hryvnia'),
  'BYN': CurrencyInfo('BYN', 'Белорусский рубль', 'Belarusian ruble'),
  'KZT': CurrencyInfo('KZT', 'Казахский тенге', 'Kazakhstani tenge'),
  'GEL': CurrencyInfo('GEL', 'Грузинский лари', 'Georgian lari'),
  'AMD': CurrencyInfo('AMD', 'Армянский драм', 'Armenian dram'),
  'AZN': CurrencyInfo('AZN', 'Азербайджанский манат', 'Azerbaijani manat'),
  'TRY': CurrencyInfo('TRY', 'Турецкая лира', 'Turkish lira'),
  'GBP': CurrencyInfo('GBP', 'Фунт стерлингов', 'Pound sterling'),
  'CHF': CurrencyInfo('CHF', 'Швейцарский франк', 'Swiss franc'),
  'PLN': CurrencyInfo('PLN', 'Польский злотый', 'Polish zloty'),
  'CZK': CurrencyInfo('CZK', 'Чешская крона', 'Czech koruna'),
  'HUF': CurrencyInfo('HUF', 'Венгерский форинт', 'Hungarian forint'),
  'BGN': CurrencyInfo('BGN', 'Болгарский лев', 'Bulgarian lev'),
  'RSD': CurrencyInfo('RSD', 'Сербский динар', 'Serbian dinar'),
  'SEK': CurrencyInfo('SEK', 'Шведская крона', 'Swedish krona'),
  'NOK': CurrencyInfo('NOK', 'Норвежская крона', 'Norwegian krone'),
  'DKK': CurrencyInfo('DKK', 'Датская крона', 'Danish krone'),
  'ISK': CurrencyInfo('ISK', 'Исландская крона', 'Icelandic krona'),
  'CAD': CurrencyInfo('CAD', 'Канадский доллар', 'Canadian dollar'),
  'AUD': CurrencyInfo('AUD', 'Австралийский доллар', 'Australian dollar'),
  'NZD': CurrencyInfo('NZD', 'Новозеландский доллар', 'New Zealand dollar'),
  'JPY': CurrencyInfo('JPY', 'Японская иена', 'Japanese yen'),
  'CNY': CurrencyInfo('CNY', 'Китайский юань', 'Chinese yuan'),
  'HKD': CurrencyInfo('HKD', 'Гонконгский доллар', 'Hong Kong dollar'),
  'SGD': CurrencyInfo('SGD', 'Сингапурский доллар', 'Singapore dollar'),
  'KRW': CurrencyInfo('KRW', 'Южнокорейская вона', 'South Korean won'),
  'INR': CurrencyInfo('INR', 'Индийская рупия', 'Indian rupee'),
  'IDR': CurrencyInfo('IDR', 'Индонезийская рупия', 'Indonesian rupiah'),
  'THB': CurrencyInfo('THB', 'Тайский бат', 'Thai baht'),
  'VND': CurrencyInfo('VND', 'Вьетнамский донг', 'Vietnamese dong'),
  'PHP': CurrencyInfo('PHP', 'Филиппинское песо', 'Philippine peso'),
  'MYR': CurrencyInfo('MYR', 'Малайзийский ринггит', 'Malaysian ringgit'),
  'AED': CurrencyInfo('AED', 'Дирхам ОАЭ', 'UAE dirham'),
  'SAR': CurrencyInfo('SAR', 'Саудовский риял', 'Saudi riyal'),
  'QAR': CurrencyInfo('QAR', 'Катарский риал', 'Qatari riyal'),
  'ILS': CurrencyInfo('ILS', 'Израильский шекель', 'Israeli shekel'),
  'EGP': CurrencyInfo('EGP', 'Египетский фунт', 'Egyptian pound'),
  'MAD': CurrencyInfo('MAD', 'Марокканский дирхам', 'Moroccan dirham'),
  'TND': CurrencyInfo('TND', 'Тунисский динар', 'Tunisian dinar'),
  'ZAR': CurrencyInfo('ZAR', 'Южноафриканский рэнд', 'South African rand'),
  'NGN': CurrencyInfo('NGN', 'Нигерийская найра', 'Nigerian naira'),
  'KES': CurrencyInfo('KES', 'Кенийский шиллинг', 'Kenyan shilling'),
  'BRL': CurrencyInfo('BRL', 'Бразильский реал', 'Brazilian real'),
  'ARS': CurrencyInfo('ARS', 'Аргентинское песо', 'Argentine peso'),
  'MXN': CurrencyInfo('MXN', 'Мексиканское песо', 'Mexican peso'),
  'CLP': CurrencyInfo('CLP', 'Чилийское песо', 'Chilean peso'),
  'COP': CurrencyInfo('COP', 'Колумбийское песо', 'Colombian peso'),
  'PEN': CurrencyInfo('PEN', 'Перуанский соль', 'Peruvian sol'),
  'UYU': CurrencyInfo('UYU', 'Уругвайское песо', 'Uruguayan peso'),
  'UZS': CurrencyInfo('UZS', 'Узбекский сум', 'Uzbekistani sum'),
  'KGS': CurrencyInfo('KGS', 'Киргизский сом', 'Kyrgyzstani som'),
  'TJS': CurrencyInfo('TJS', 'Таджикский сомони', 'Tajikistani somoni'),
  'TMT': CurrencyInfo('TMT', 'Туркменский манат', 'Turkmenistani manat'),
  'MNT': CurrencyInfo('MNT', 'Монгольский тугрик', 'Mongolian tugrik'),
  'PKR': CurrencyInfo('PKR', 'Пакистанская рупия', 'Pakistani rupee'),
  'BDT': CurrencyInfo('BDT', 'Бангладешская така', 'Bangladeshi taka'),
  'LKR': CurrencyInfo('LKR', 'Шри-ланкийская рупия', 'Sri Lankan rupee'),
  'NPR': CurrencyInfo('NPR', 'Непальская рупия', 'Nepalese rupee'),
  'IQD': CurrencyInfo('IQD', 'Иракский динар', 'Iraqi dinar'),
  'IRR': CurrencyInfo('IRR', 'Иранский риал', 'Iranian rial'),
  'JOD': CurrencyInfo('JOD', 'Иорданский динар', 'Jordanian dinar'),
  'KWD': CurrencyInfo('KWD', 'Кувейтский динар', 'Kuwaiti dinar'),
  'BHD': CurrencyInfo('BHD', 'Бахрейнский динар', 'Bahraini dinar'),
  'OMR': CurrencyInfo('OMR', 'Оманский риал', 'Omani rial'),
  'LBP': CurrencyInfo('LBP', 'Ливанский фунт', 'Lebanese pound'),
  'SYP': CurrencyInfo('SYP', 'Сирийский фунт', 'Syrian pound'),
  'AFN': CurrencyInfo('AFN', 'Афгани', 'Afghan afghani'),
  'ALL': CurrencyInfo('ALL', 'Албанский лек', 'Albanian lek'),
  'MKD': CurrencyInfo('MKD', 'Македонский денар', 'Macedonian denar'),
  'BAM': CurrencyInfo('BAM', 'Боснийская марка', 'Bosnian mark'),
  'HRK': CurrencyInfo('HRK', 'Хорватская куна', 'Croatian kuna'),
  'TWD': CurrencyInfo('TWD', 'Тайваньский доллар', 'Taiwan dollar'),
  'ETB': CurrencyInfo('ETB', 'Эфиопский быр', 'Ethiopian birr'),
  'GHS': CurrencyInfo('GHS', 'Ганский седи', 'Ghanaian cedi'),
  'TZS': CurrencyInfo('TZS', 'Танзанийский шиллинг', 'Tanzanian shilling'),
  'UGX': CurrencyInfo('UGX', 'Угандийский шиллинг', 'Ugandan shilling'),
  'DZD': CurrencyInfo('DZD', 'Алжирский динар', 'Algerian dinar'),
  'LYD': CurrencyInfo('LYD', 'Ливийский динар', 'Libyan dinar'),
  'CUP': CurrencyInfo('CUP', 'Кубинское песо', 'Cuban peso'),
  'DOP': CurrencyInfo('DOP', 'Доминиканское песо', 'Dominican peso'),
  'GTQ': CurrencyInfo('GTQ', 'Гватемальский кетсаль', 'Guatemalan quetzal'),
  'CRC': CurrencyInfo('CRC', 'Костариканский колон', 'Costa Rican colon'),
  'PAB': CurrencyInfo('PAB', 'Панамский бальбоа', 'Panamanian balboa'),
  'BOB': CurrencyInfo('BOB', 'Боливийский боливиано', 'Bolivian boliviano'),
  'PYG': CurrencyInfo('PYG', 'Парагвайский гуарани', 'Paraguayan guarani'),
  'VES': CurrencyInfo('VES', 'Венесуэльский боливар', 'Venezuelan bolivar'),
  'XAU': CurrencyInfo('XAU', 'Золото, унция', 'Gold, ounce'),
  'BTC': CurrencyInfo('BTC', 'Биткойн', 'Bitcoin'),
  'USDT': CurrencyInfo('USDT', 'Тезер', 'Tether'),
};

/// Курс единицы валюты в ДОЛЛАРАХ на день сборки (13.09.2026, open.er-api.com).
///
/// Нужен, чтобы курс был ВСЕГДА: до этого чужая валюта без сети и до первого
/// обновления считалась один к одному, и зарплата в долларах превращалась в
/// такую же сумму леев. Свежий курс с сервера всегда сильнее этой таблицы —
/// она только не даёт приложению врать в разы.
const usdPrice = <String, double>{
  'MDL': 0.05792696,
  'RON': 0.22101577,
  'EUR': 1.16031087,
  'USD': 1.0,
  'RUB': 0.01185465,
  'UAH': 0.022431,
  'BYN': 0.32922418,
  'KZT': 0.00221773,
  'GEL': 0.38358693,
  'AMD': 0.00275076,
  'AZN': 0.5880779,
  'TRY': 0.02057692,
  'GBP': 1.35235831,
  'CHF': 1.22544064,
  'PLN': 0.26855176,
  'CZK': 0.04785657,
  'HUF': 0.00318956,
  'BGN': 0.5932581,
  'RSD': 0.0098947,
  'SEK': 0.10310749,
  'NOK': 0.10765027,
  'DKK': 0.15510508,
  'ISK': 0.00829922,
  'CAD': 0.72162412,
  'AUD': 0.71675442,
  'NZD': 0.58158741,
  'JPY': 0.00650204,
  'CNY': 0.14856936,
  'HKD': 0.12751449,
  'SGD': 0.78920058,
  'KRW': 0.00074458,
  'INR': 0.01046253,
  'IDR': 5.681e-05,
  'THB': 0.03027834,
  'VND': 3.865e-05,
  'PHP': 0.0159565,
  'MYR': 0.24580835,
  'AED': 0.27229408,
  'SAR': 0.26666667,
  'QAR': 0.27472527,
  'ILS': 0.32905431,
  'EGP': 0.01947717,
  'MAD': 0.10645705,
  'TND': 0.3439304,
  'ZAR': 0.06196319,
  'NGN': 0.00075359,
  'KES': 0.00772476,
  'BRL': 0.19587361,
  'ARS': 0.00066229,
  'MXN': 0.05894882,
  'CLP': 0.00106578,
  'COP': 0.00032198,
  'PEN': 0.29759708,
  'UYU': 0.02483193,
  'UZS': 8.495e-05,
  'KGS': 0.01143001,
  'TJS': 0.1083073,
  'TMT': 0.28564761,
  'MNT': 0.00027571,
  'PKR': 0.00360112,
  'BDT': 0.00812024,
  'LKR': 0.00304697,
  'NPR': 0.0065391,
  'IQD': 0.00076279,
  'IRR': 6.6e-07,
  'JOD': 1.41043724,
  'KWD': 3.24481479,
  'BHD': 2.65957447,
  'OMR': 2.60080053,
  'LBP': 1.117e-05,
  'SYP': 0.00819955,
  'AFN': 0.01552347,
  'ALL': 0.01263484,
  'MKD': 0.01887334,
  'BAM': 0.5932581,
  'HRK': 0.15399985,
  'TWD': 0.03168097,
  'ETB': 0.00619539,
  'GHS': 0.08763369,
  'TZS': 0.0003778,
  'UGX': 0.00026632,
  'DZD': 0.00751225,
  'LYD': 0.15804779,
  'CUP': 0.04166667,
  'DOP': 0.01699949,
  'GTQ': 0.13085361,
  'CRC': 0.00220085,
  'PAB': 1.0,
  'BOB': 0.07945507,
  'PYG': 0.00016938,
  'VES': 0.00118736,
};

/// Курс [code] к [base] по встроенной таблице. Ноль — валюты в ней нет.
double fallbackRate(String code, String base) {
  if (code == base) return 1;
  final a = usdPrice[code.toUpperCase()];
  final b = usdPrice[base.toUpperCase()];
  if (a == null || b == null || b <= 0) return 0;
  return a / b;
}
