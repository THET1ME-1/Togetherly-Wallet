// Настройки: разделы, строки, подписи состояния синхронизации.
const Map<String, Map<String, String>> settingsStrings = {
  'spaceAll': {
    'ru': 'Все пары',
    'en': 'All pairs',
  },
  'spaceAllNote': {
    'ru': 'Сводка по всем парам — только на этом телефоне',
    'en': 'A summary of every pair, on this phone only',
  },

  'spaceTitle': {
    'ru': 'С кем ведём деньги',
    'en': 'Whose money we keep',
  },
  'spaceText': {
    'ru': 'У каждой пары свои счета и записи. Партнёр видит только вашу общую пару',
    'en': 'Each pair keeps its own accounts and records. A partner only sees your shared pair',
  },
  'spaceSince': {
    'ru': 'Пара с %s',
    'en': 'Together since %s',
  },
  'spaceAlone': {
    'ru': 'Только я',
    'en': 'Just me',
  },

  'pairOthers': {
    'ru': 'Другие пары: %s',
    'en': 'Other pairs: %s',
  },
  'pairSwitchTitle': {
    'ru': 'Другая пара',
    'en': 'Another pair',
  },
  'pairSwitchText': {
    'ru': 'Деньги каждой пары ведутся отдельно. Партнёр видит только свою пару',
    'en': 'Each pair keeps its own money. A partner only ever sees their own pair',
  },

  'settingsTitle': {
    'ru': 'Настройки',
    'en': 'Settings',
  },
  'sectionTogether': {
    'ru': 'Профиль',
    'en': 'Profile',
  },
  'sectionLook': {
    'ru': 'Оформление',
    'en': 'Appearance',
  },
  'sectionMoney': {
    'ru': 'Деньги',
    'en': 'Money',
  },
  'sectionBudget': {
    'ru': 'Бюджет',
    'en': 'Budget',
  },
  'sectionData': {
    'ru': 'Данные',
    'en': 'Data',
  },
  'sectionAccount': {
    'ru': 'Аккаунт',
    'en': 'Account',
  },
  'sectionApp': {
    'ru': 'Приложение',
    'en': 'About',
  },
  'sectionDanger': {
    'ru': 'Опасное',
    'en': 'Dangerous',
  },
  'themeLight': {
    'ru': 'Светлая',
    'en': 'Light',
  },
  'themeAuto': {
    'ru': 'Авто',
    'en': 'Auto',
  },
  'themeDark': {
    'ru': 'Тёмная',
    'en': 'Dark',
  },
  'blackBackground': {
    'ru': 'Чёрный фон',
    'en': 'Pure black background',
  },
  'blackBackgroundNote': {
    'ru': 'На OLED-экране такой фон не светится',
    'en': 'On an OLED screen this background does not glow',
  },
  'currencyRow': {
    'ru': 'Валюта и курсы',
    'en': 'Currency and rates',
  },
  'currencyTotals': {
    'ru': 'Итоги считаются в %s',
    'en': 'Totals are counted in %s',
  },
  'ratesMissing': {
    'ru': '%s · курсов не хватает: %s',
    'en': '%s · rates missing: %s',
  },
  'ratesNone': {
    'ru': '%s · курсы не заданы, считаем один к одному',
    'en': '%s · no rates set, counting one to one',
  },
  'ratesSet': {
    'ru': '%s · курсы заданы (%s)',
    'en': '%s · rates set (%s)',
  },
  'categoriesRow': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'categoriesNote': {
    'ru': 'Имена, цвета, иконки и что к чему относится',
    'en': 'Names, colours, icons and what belongs where',
  },
  'rulesRow': {
    'ru': 'Правила',
    'en': 'Rules',
  },
  'rulesNote': {
    'ru': 'Как делим доход, округление, пересмотр, общий кошелёк',
    'en': 'How we split income, rounding, reviews, the shared wallet',
  },
  'recurringRow': {
    'ru': 'Регулярное',
    'en': 'Recurring',
  },
  'recurringNote': {
    'ru': 'Платежи, доходы и «заплати себе первым»',
    'en': 'Payments, income and “pay yourself first”',
  },
  'noticesRow': {
    'ru': 'Уведомления банков',
    'en': 'Bank notifications',
  },
  'noticesNote': {
    'ru': 'Записывать траты из пушей банка',
    'en': 'Record spending from bank pushes',
  },
  'noticesAndroidOnly': {
    'ru': 'Читать уведомления умеет только Android',
    'en': 'Only Android can read notifications',
  },
  'noticesSourcesOn': {
    'ru': 'Включено источников: %s',
    'en': 'Sources on: %s',
  },
  'noticesWaiting': {
    'ru': 'Ждут подтверждения: %s',
    'en': 'Waiting for you: %s',
  },
  'debtsRow': {
    'ru': 'Долги',
    'en': 'Debt',
  },
  'debtsNote': {
    'ru': 'Кредиты, карты, порядок погашения',
    'en': 'Loans, cards, repayment order',
  },
  'importRow': {
    'ru': 'Восстановить из копии',
    'en': 'Restore from a copy',
  },
  'importNote': {
    'ru': 'Файл .json, сохранённый этим приложением. Выписку банка приносите в чат — он разберёт любой формат',
    'en': 'A .json file saved by this app. Bank statements go to the chat — it reads any format',
  },
  'importDone': {
    'ru': 'Загружено операций: %s',
    'en': 'Operations loaded: %s',
  },
  'importFailed': {
    'ru': 'Файл не разобран',
    'en': 'The file could not be read',
  },
  'exportRow': {
    'ru': 'Сохранить копию',
    'en': 'Save a copy',
  },
  'backupsRow': {
    'ru': 'Копии на устройстве',
    'en': 'Copies on this device',
  },
  'backupsNone': {
    'ru': 'Копия делается сама раз в сутки',
    'en': 'A copy is made once a day on its own',
  },
  'backupsHave': {
    'ru': 'Последняя: %s · всего %s',
    'en': 'Latest: %s · %s in total',
  },
  'backupsSize': {
    'ru': '%s КБ',
    'en': '%s KB',
  },
  'backupsPick': {
    'ru': 'Из какой копии восстановить',
    'en': 'Which copy to restore from',
  },
  'backupsText': {
    'ru': 'Нынешние записи заменятся теми, что в копии',
    'en': 'Your current records will be replaced by the ones in the copy',
  },
  'exportNote': {
    'ru': 'Один файл .json: счета, операции, категории, бюджеты, цели и долги',
    'en': 'One .json file: accounts, operations, categories, budgets, goals and debts',
  },
  'accountShared': {
    'ru': 'Аккаунт общий с Togetherly',
    'en': 'The account is shared with Togetherly',
  },
  'accountNone': {
    'ru': 'Без аккаунта',
    'en': 'No account',
  },
  'signOutRow': {
    'ru': 'Выйти из аккаунта',
    'en': 'Sign out',
  },
  'signOutNote': {
    'ru': 'Записи останутся на устройстве и на сервере',
    'en': 'Records stay on the device and on the server',
  },
  'syncRetrying': {
    'ru': 'Связь оборвалась — пробуем ещё раз',
    'en': 'The connection dropped — trying again',
  },
  'pairFromTogetherly': {
    'ru': 'Пара приезжает из Togetherly. Если она есть там, войдите ТЕМ ЖЕ '
        'аккаунтом: вход другим заводит новую учётную запись, пустую.',
    'en': 'The pair comes from Togetherly. If you have one there, sign in with '
        'the SAME account: another one creates a new, empty record.',
  },
  'catResetRow': {
    'ru': 'Вернуть стандартные',
    'en': 'Restore the standard set',
  },
  'catResetNote': {
    'ru': 'Набор расходов и доходов с подкатегориями',
    'en': 'Expense and income set with subcategories',
  },
  'catResetTitle': {
    'ru': 'Вернуть стандартные категории?',
    'en': 'Restore the standard categories?',
  },
  'catResetText': {
    'ru': 'Положим набор из %s строк: расходы с подкатегориями и доходы '
        'отдельно. Заведённые вами останутся на месте, операции не '
        'тронутся.',
    'en': 'We will add %s entries: expenses with subcategories and income '
        'separately. Your own stay where they are, operations are not '
        'touched.',
  },
  'catResetDo': {
    'ru': 'Вернуть',
    'en': 'Restore',
  },
  'catWipeRow': {
    'ru': 'Удалить все категории',
    'en': 'Delete all categories',
  },
  'catWipeNote': {
    'ru': 'Операции останутся, но потеряют категорию',
    'en': 'Operations stay, but lose their category',
  },
  'catWipeTitle': {
    'ru': 'Удалить все категории?',
    'en': 'Delete all categories?',
  },
  'catWipeText': {
    'ru': 'Пропадут все категории и подкатегории, свои и стандартные. Деньги '
        'останутся: каждая трата сохранится, но перестанет числиться за '
        'категорией. Бюджеты по ним считать станет нечем.',
    'en': 'Every category and subcategory disappears, yours and the standard '
        'ones. The money stays: each operation survives but stops belonging '
        'to a category, and budgets lose what they counted.',
  },
  'catWipeDo': {
    'ru': 'Удалить',
    'en': 'Delete',
  },
  'catResetDone': {
    'ru': 'Стандартные категории на месте',
    'en': 'The standard categories are back',
  },
  'catWipeDone': {
    'ru': 'Категории удалены',
    'en': 'Categories deleted',
  },
  'supportRow': {
    'ru': 'Поддержка',
    'en': 'Support',
  },
  'supportNote': {
    'ru': 'support@togetherly.day — отвечает человек',
    'en': 'support@togetherly.day — a person answers',
  },
  'bugBotRow': {
    'ru': 'Сообщить об ошибке',
    'en': 'Report a problem',
  },
  'bugBotNote': {
    'ru': 'Бот в Telegram: опишите, что пошло не так',
    'en': 'A Telegram bot: tell us what went wrong',
  },
  'channelRow': {
    'ru': 'Канал в Telegram',
    'en': 'Telegram channel',
  },
  'channelNote': {
    'ru': 'Что нового и что чиним прямо сейчас',
    'en': 'What is new and what we are fixing right now',
  },
  'tiktokRow': {
    'ru': 'TikTok',
    'en': 'TikTok',
  },
  'tiktokNote': {
    'ru': 'Короткие ролики про приложения S&T',
    'en': 'Short videos about S&T apps',
  },
  'privacyRow': {
    'ru': 'Как мы обходимся с данными',
    'en': 'How we treat your data',
  },
  'privacyNote': {
    'ru': 'Уведомления банков остаются на телефоне',
    'en': 'Bank notifications stay on the phone',
  },
  'versionRow': {
    'ru': 'Версия',
    'en': 'Version',
  },
  'wipeRow': {
    'ru': 'Стереть всё',
    'en': 'Erase everything',
  },
  'wipeRowNote': {
    'ru': 'Данные исчезнут с устройства без возврата',
    'en': 'Data disappears from the device for good',
  },
  'wipeDone': {
    'ru': 'Стёрто',
    'en': 'Erased',
  },
  'linkFailed': {
    'ru': 'Ссылка не открылась',
    'en': 'The link did not open',
  },
  'pairWith': {
    'ru': 'В паре с %s',
    'en': 'Paired with %s',
  },
  'pairNone': {
    'ru': 'Пары нет: деньги видите только вы',
    'en': 'No pair: only you see the money',
  },
  'pairInvite': {
    'ru': 'Позвать партнёра',
    'en': 'Invite your partner',
  },
  'pairCode': {
    'ru': 'Код и QR',
    'en': 'Code and QR',
  },
  'pairRefresh': {
    'ru': 'Обновить',
    'en': 'Refresh',
  },
  'syncRunning': {
    'ru': 'Синхронизация…',
    'en': 'Syncing…',
  },
  'syncPending': {
    'ru': 'Ждёт отправки: %s',
    'en': 'Waiting to send: %s',
  },
  'syncDone': {
    'ru': 'Всё уехало на сервер',
    'en': 'Everything is on the server',
  },
  'splitRow': {
    'ru': 'Как делим общие траты',
    'en': 'How we split shared spending',
  },
  'splitNone': {
    'ru': 'Не делим',
    'en': 'We don’t split',
  },
  'splitPayerPays': {
    'ru': 'Платит тот, кто платил',
    'en': 'Whoever paid, paid',
  },
  'splitEvenly': {
    'ru': 'Поровну',
    'en': 'Evenly',
  },
  'splitByShares': {
    'ru': 'По долям у каждой траты',
    'en': 'By shares on each expense',
  },
  'aiKeysRow': {
    'ru': 'Ключи моделей',
    'en': 'Model keys',
  },
  'aiKeysNote': {
    'ru': 'Ключ лежит на устройстве и уходит только когда вы нажали '
        '«спросить» в чате.',
    'en': 'The key stays on the device and leaves only when you press “ask” '
        'in the chat.',
  },
  'aiKeysNoteFull': {
    'ru': 'Ключ лежит на устройстве и уходит только когда вы нажали '
        '«спросить» в чате.',
    'en': 'The key stays on the device and leaves only when you press “ask” '
        'in the chat.',
  },
  'notSet': {
    'ru': 'Не задан',
    'en': 'Not set',
  },
  'noticesRead': {
    'ru': 'Читаем: %s %s',
    'en': 'Reading: %s %s',
  },
  'source.one': {
    'ru': 'источник',
    'en': 'source',
  },
  'source.few': {
    'ru': 'источника',
    'en': 'sources',
  },
  'source.many': {
    'ru': 'источников',
    'en': 'sources',
  },
  'source.other': {
    'ru': 'источников',
    'en': 'sources',
  },

  // Замок на вход: код и отпечаток.
  'lockRow': {
    'ru': 'Замок на вход',
    'en': 'App lock',
  },
  'lockRowOff': {
    'ru': 'Выключен',
    'en': 'Off',
  },
  'lockRowOn': {
    'ru': 'Код из четырёх цифр',
    'en': 'A four-digit code',
  },
  'lockRowBoth': {
    'ru': 'Код и отпечаток',
    'en': 'Code and fingerprint',
  },
  'lockTitle': {
    'ru': 'Введите код',
    'en': 'Enter your code',
  },
  'lockWrong': {
    'ru': 'Код не подошёл',
    'en': 'Wrong code',
  },
  'lockNewTitle': {
    'ru': 'Придумайте код',
    'en': 'Pick a code',
  },
  'lockRepeatTitle': {
    'ru': 'Повторите код',
    'en': 'Repeat the code',
  },
  'lockMismatch': {
    'ru': 'Коды не совпали, начнём сначала',
    'en': 'The codes did not match, let us start over',
  },
  'lockBiometrics': {
    'ru': 'Открывать отпечатком',
    'en': 'Unlock with a fingerprint',
  },
  'lockBiometricsNote': {
    'ru': 'Код остаётся: им открывают, когда отпечаток не сработал',
    'en': 'The code stays: it opens the app when the fingerprint fails',
  },
  'lockChange': {
    'ru': 'Сменить код',
    'en': 'Change the code',
  },
  'lockRemove': {
    'ru': 'Снять замок',
    'en': 'Remove the lock',
  },
  'lockRemoveText': {
    'ru': 'Приложение перестанет спрашивать код при запуске.',
    'en': 'The app will stop asking for the code at launch.',
  },

  // Снимки базы за каждый день: «возврат к любому дню».
  'snapshotRow': {
    'ru': 'Возврат к любому дню',
    'en': 'Roll back to any day',
  },
  'snapshotRowOff': {
    'ru': 'Выключено',
    'en': 'Off',
  },
  'snapshotRowOn': {
    'ru': 'Снимок раз в сутки, 30 дней',
    'en': 'A snapshot a day, 30 days',
  },
  'snapshotTitle': {
    'ru': 'Снимки базы',
    'en': 'Database snapshots',
  },
  'snapshotIntroTitle': {
    'ru': 'Вернуться к любому дню',
    'en': 'Roll back to any day',
  },
  'snapshotIntroText': {
    'ru': 'Раз в сутки приложение делает снимок базы, шифрует его прямо здесь '
        'и кладёт на сервер. Хранится тридцать последних дней: удалили что-то '
        'лишнее неделю назад — вернётесь к тому дню одним касанием.',
    'en': 'Once a day the app snapshots your database, encrypts it right here '
        'and stores it on the server. The last thirty days are kept: delete '
        'something by mistake and you are one tap from that day.',
  },
  'snapshotIntroKey': {
    'ru': 'Ключ остаётся у вас: мы храним снимок и прочитать его не можем. '
        'Поэтому нужна фраза восстановления — без неё снимки не открыть на '
        'новом телефоне. Запишите её на бумагу.',
    'en': 'The key stays with you: we keep the snapshot and cannot read it. '
        'That is why there is a recovery phrase — without it the snapshots '
        'will not open on a new phone. Write it down on paper.',
  },
  'snapshotStart': {
    'ru': 'Включить и показать фразу',
    'en': 'Turn on and show the phrase',
  },
  'snapshotKeySection': {
    'ru': 'Ключ',
    'en': 'Key',
  },
  'snapshotDaysSection': {
    'ru': 'Дни',
    'en': 'Days',
  },
  'snapshotPhraseRow': {
    'ru': 'Фраза восстановления',
    'en': 'Recovery phrase',
  },
  'snapshotPhraseNote': {
    'ru': 'Шесть слов, которыми открываются снимки',
    'en': 'Six words that open your snapshots',
  },
  'snapshotPhraseTitle': {
    'ru': 'Ваша фраза',
    'en': 'Your phrase',
  },
  'snapshotPhraseWarn': {
    'ru': 'Перепишите слова по порядку и держите их отдельно от телефона. '
        'Потеряете фразу вместе с телефоном — снимки останутся закрытыми '
        'навсегда, у нас ключа нет.',
    'en': 'Write the words down in order and keep them away from your phone. '
        'Lose the phrase along with the phone and the snapshots stay closed '
        'forever: we do not hold the key.',
  },
  'snapshotPhraseCopy': {
    'ru': 'Скопировать',
    'en': 'Copy',
  },
  'snapshotPhraseWrote': {
    'ru': 'Записал',
    'en': 'Written down',
  },
  'snapshotEmpty': {
    'ru': 'Снимков пока нет',
    'en': 'No snapshots yet',
  },
  'snapshotEmptyNote': {
    'ru': 'Нажмите, чтобы снять первый прямо сейчас',
    'en': 'Tap to take the first one right now',
  },
  'snapshotSize': {
    'ru': '%s КБ',
    'en': '%s KB',
  },
  'snapshotRestoreTitle': {
    'ru': 'Вернуться к %s',
    'en': 'Roll back to %s',
  },
  'snapshotRestoreText': {
    'ru': 'Нынешние записи заменятся теми, что были в этот день. Всё, что '
        'записано позже, с устройства исчезнет.',
    'en': 'Your current records will be replaced with that day’s. Everything '
        'recorded later disappears from this device.',
  },
  'snapshotRestore': {
    'ru': 'Вернуть',
    'en': 'Roll back',
  },
  'snapshotRestored': {
    'ru': 'Вернули состояние на выбранный день',
    'en': 'Rolled back to the chosen day',
  },
  'snapshotNoPhrase': {
    'ru': 'Сперва заведите фразу восстановления',
    'en': 'Set up the recovery phrase first',
  },
  'snapshotWrongPhrase': {
    'ru': 'Снимок не открылся: фраза не та',
    'en': 'The snapshot did not open: wrong phrase',
  },
  'snapshotBroken': {
    'ru': 'Снимок повреждён, база не тронута',
    'en': 'The snapshot is damaged, your database is untouched',
  },
  'snapshotFailed': {
    'ru': 'Снимок не приехал. Попробуйте ещё раз',
    'en': 'The snapshot did not arrive. Try again',
  },
  'snapshotNeedPlus': {
    'ru': 'Снимки базы открывает Wallet+',
    'en': 'Database snapshots come with Wallet+',
  },

};
