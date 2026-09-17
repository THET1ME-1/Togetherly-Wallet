// Слова, которые живут вне экранов: навигация, даты, порядок сортировки,
// ошибки входа, канал уведомлений, строка долга.
const Map<String, Map<String, String>> coreStrings = {
  // ── нижняя навигация ──
  'navHome': {
    'ru': 'Главная',
    'en': 'Home',
  },
  'navCategories': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'navStats': {
    'ru': 'Статистика',
    'en': 'Stats',
  },
  'navLedger': {
    'ru': 'Транзакции',
    'en': 'Operations',
  },
  'navAdd': {
    'ru': 'Записать операцию',
    'en': 'Record an operation',
  },
  // ── месяцы ──
  // Два набора: в дате нужен родительный падеж («12 сентября»), в заголовке
  // именительный («Сентябрь»). У английского форма одна, поэтому колонки
  // совпадают.
  'monthOf1': {'ru': 'января', 'en': 'January'},
  'monthOf2': {'ru': 'февраля', 'en': 'February'},
  'monthOf3': {'ru': 'марта', 'en': 'March'},
  'monthOf4': {'ru': 'апреля', 'en': 'April'},
  'monthOf5': {'ru': 'мая', 'en': 'May'},
  'monthOf6': {'ru': 'июня', 'en': 'June'},
  'monthOf7': {'ru': 'июля', 'en': 'July'},
  'monthOf8': {'ru': 'августа', 'en': 'August'},
  'monthOf9': {'ru': 'сентября', 'en': 'September'},
  'monthOf10': {'ru': 'октября', 'en': 'October'},
  'monthOf11': {'ru': 'ноября', 'en': 'November'},
  'monthOf12': {'ru': 'декабря', 'en': 'December'},
  'month1': {'ru': 'Январь', 'en': 'January'},
  'month2': {'ru': 'Февраль', 'en': 'February'},
  'month3': {'ru': 'Март', 'en': 'March'},
  'month4': {'ru': 'Апрель', 'en': 'April'},
  'month5': {'ru': 'Май', 'en': 'May'},
  'month6': {'ru': 'Июнь', 'en': 'June'},
  'month7': {'ru': 'Июль', 'en': 'July'},
  'month8': {'ru': 'Август', 'en': 'August'},
  'month9': {'ru': 'Сентябрь', 'en': 'September'},
  'month10': {'ru': 'Октябрь', 'en': 'October'},
  'month11': {'ru': 'Ноябрь', 'en': 'November'},
  'month12': {'ru': 'Декабрь', 'en': 'December'},
  // Короткие имена дней. Обрезать длинные по двум буквам нельзя: выходит
  // «Че» вместо «Чт» и «Су» вместо «Сб» (поймано на живом эмуляторе
  // 17.09.2026).
  'weekdayShort1': {'ru': 'Пн', 'en': 'Mon'},
  'weekdayShort2': {'ru': 'Вт', 'en': 'Tue'},
  'weekdayShort3': {'ru': 'Ср', 'en': 'Wed'},
  'weekdayShort4': {'ru': 'Чт', 'en': 'Thu'},
  'weekdayShort5': {'ru': 'Пт', 'en': 'Fri'},
  'weekdayShort6': {'ru': 'Сб', 'en': 'Sat'},
  'weekdayShort7': {'ru': 'Вс', 'en': 'Sun'},
  'weekday1': {'ru': 'Понедельник', 'en': 'Monday'},
  'weekday2': {'ru': 'Вторник', 'en': 'Tuesday'},
  'weekday3': {'ru': 'Среда', 'en': 'Wednesday'},
  'weekday4': {'ru': 'Четверг', 'en': 'Thursday'},
  'weekday5': {'ru': 'Пятница', 'en': 'Friday'},
  'weekday6': {'ru': 'Суббота', 'en': 'Saturday'},
  'weekday7': {'ru': 'Воскресенье', 'en': 'Sunday'},
  'periodKindDay': {
    'ru': 'Сегодня',
    'en': 'Today',
  },
  'periodKindWeek': {
    'ru': 'На этой неделе',
    'en': 'This week',
  },
  'periodKindMonth': {
    'ru': 'В этом месяце',
    'en': 'This month',
  },
  'periodKindYear': {
    'ru': 'В этом году',
    'en': 'This year',
  },
  'periodKindAll': {
    'ru': 'Всё время',
    'en': 'All time',
  },
  'periodKindCustom': {
    'ru': 'Свой отрезок',
    'en': 'Custom period',
  },
  // ── порядок в списках ──
  'sortNewest': {
    'ru': 'Сначала новые',
    'en': 'Newest first',
  },
  'sortOldest': {
    'ru': 'Сначала старые',
    'en': 'Oldest first',
  },
  'sortBiggest': {
    'ru': 'Сначала крупные',
    'en': 'Biggest first',
  },
  'sortSmallest': {
    'ru': 'Сначала мелкие',
    'en': 'Smallest first',
  },
  'sortByAmount': {
    'ru': 'По сумме',
    'en': 'By amount',
  },
  'sortByName': {
    'ru': 'По названию',
    'en': 'By name',
  },
  'sortByCount': {
    'ru': 'По числу операций',
    'en': 'By number of operations',
  },
  // ── сальдо ──
  'settleEven': {
    'ru': 'Вы в расчёте',
    'en': 'You are even',
  },
  'settleTheyOwe': {
    'ru': 'Вам должны %s',
    'en': 'You are owed %s',
  },
  'settleYouOwe': {
    'ru': 'Вы должны %s',
    'en': 'You owe %s',
  },
  'settleWith': {
    'ru': 'Сальдо с %s',
    'en': 'Balance with %s',
  },
  'settlePartner': {
    'ru': 'партнёром',
    'en': 'your partner',
  },
  'settlePartnerDative': {
    'ru': 'партнёру',
    'en': 'your partner',
  },
  // ── почему не пустило ──
  'authWrongPair': {
    'ru': 'Почта или пароль не подошли',
    'en': 'That email and password do not match',
  },
  'authEmailTaken': {
    'ru': 'На эту почту уже есть аккаунт. Войдите в него',
    'en': 'There is already an account on this email. Sign in to it',
  },
  'authEmailTypo': {
    'ru': 'Проверьте почту: похоже, в адресе опечатка',
    'en': 'Check the email: the address looks like a typo',
  },
  'authWeakPassword': {
    'ru': 'Пароль короче восьми знаков',
    'en': 'The password is shorter than eight characters',
  },
  'authEmptyFields': {
    'ru': 'Заполните почту и пароль',
    'en': 'Fill in the email and the password',
  },
  'authTooMany': {
    'ru': 'Слишком много попыток. Подождите минуту',
    'en': 'Too many attempts. Wait a minute',
  },
  'authBlocked': {
    'ru': 'Соединению мешает провайдер. Попробуйте другую сеть',
    'en': 'Your provider is blocking the connection. Try another network',
  },
  'authNoServer': {
    'ru': 'Сервер не отвечает. Проверьте сеть',
    'en': 'The server is not answering. Check your network',
  },
  'authUnknown': {
    'ru': 'Не получилось войти. Попробуйте ещё раз',
    'en': 'Signing in did not work. Try again',
  },
  // ── канал уведомлений ──
  'pushChannelName': {
    'ru': 'Записи партнёра',
    'en': 'Partner records',
  },
  'pushChannelNote': {
    'ru': 'Партнёр записал операцию или поправил вашу',
    'en': 'Your partner recorded an operation or edited yours',
  },
  'pushPartnerWrote': {
    'ru': 'Партнёр записал операцию',
    'en': 'Your partner recorded an operation',
  },
  'pushNewFrom': {
    'ru': 'Новая запись от %s',
    'en': 'New record from %s',
  },
  // ── отмена и прочее ──
  'storeRestored': {
    'ru': 'Восстановлено из копии',
    'en': 'Restored from a copy',
  },
  'storeSavedMany': {
    'ru': 'Записано: %s',
    'en': 'Saved: %s',
  },
  'storeDeletedMany': {
    'ru': 'Удалено: %s',
    'en': 'Deleted: %s',
  },
  'storeMovedMany': {
    'ru': 'Изменено: %s',
    'en': 'Changed: %s',
  },
  'settleNote': {
    'ru': 'Рассчитались',
    'en': 'Settled up',
  },
  'settleDone': {
    'ru': 'Долг закрыт',
    'en': 'Debt cleared',
  },
  'storeShared': {
    'ru': 'Разделено',
    'en': 'Shared',
  },
  'storeMoved': {
    'ru': 'Перенесено',
    'en': 'Moved',
  },
  'storeDisbanded': {
    'ru': 'Пара распущена',
    'en': 'The pair is broken up',
  },
};
