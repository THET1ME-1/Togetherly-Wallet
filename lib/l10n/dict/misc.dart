// Правила пары, статистика, приглашение партнёра.
const Map<String, Map<String, String>> miscStrings = {
  'askReadReceipt': {
    'ru': 'Разбери чек и запиши трату',
    'en': 'Read the receipt and record the expense',
  },

  'agentApply': {
    'ru': 'Сделать',
    'en': 'Do it',
  },
  'agentApplied': {
    'ru': 'Готово',
    'en': 'Done',
  },
  'agentSkip': {
    'ru': 'Не надо',
    'en': 'Skip',
  },
  'agentFailed': {
    'ru': 'Не получилось: не хватает данных',
    'en': 'It did not work: some data is missing',
  },
  'agentAnyway': {
    'ru': 'Всё равно продолжить',
    'en': 'Go ahead anyway',
  },
  'agentPhoto': {
    'ru': 'Снимок',
    'en': 'Photo',
  },
  'agentPhotoAdd': {
    'ru': 'Прикрепить чек или файл',
    'en': 'Attach a receipt or a file',
  },
  'agentReconciled': {
    'ru': '«%s»: сошлось %s, поправлено %s, добавлено %s, только у вас %s',
    'en': '“%s”: matched %s, fixed %s, added %s, only yours %s',
  },
  'agentChecked': {
    'ru': 'Сверено с выпиской',
    'en': 'Checked against the statement',
  },
  'agentImported': {
    'ru': 'Из «%s» записано операций: %s',
    'en': 'From “%s” recorded: %s',
  },
  'agentNeedAccount': {
    'ru': 'Сначала заведите счёт — записывать некуда',
    'en': 'Create an account first — there is nowhere to record',
  },
  'agentAddMany': {
    'ru': 'Записать операций: %s',
    'en': 'Record operations: %s',
  },
  'agentUpdateTx': {
    'ru': 'Поправить запись %s',
    'en': 'Fix record %s',
  },
  'agentDeleteTx': {
    'ru': 'Удалить запись %s',
    'en': 'Delete record %s',
  },
  'agentDeleteLast': {
    'ru': 'Удалить последние записи: %s',
    'en': 'Delete the last records: %s',
  },
  'agentAddAccount': {
    'ru': 'Завести счёт «%s»',
    'en': 'Create account “%s”',
  },
  'agentAddCategory': {
    'ru': 'Завести категорию «%s»',
    'en': 'Create category “%s”',
  },
  'agentAddSub': {
    'ru': 'Завести «%s» внутри «%s»',
    'en': 'Create “%s” inside “%s”',
  },
  'agentSetBudget': {
    'ru': 'Лимит на «%s» — %s',
    'en': 'Cap on “%s” — %s',
  },
  'agentDeleteBudget': {
    'ru': 'Убрать лимит на «%s»',
    'en': 'Remove the cap on “%s”',
  },
  'agentAddRecurring': {
    'ru': 'Регулярно: «%s» по %s',
    'en': 'Recurring: “%s” of %s',
  },
  'agentDeleteRecurring': {
    'ru': 'Убрать регулярное «%s»',
    'en': 'Remove recurring “%s”',
  },
  'agentPlanItem': {
    'ru': 'В план: «%s» — %s',
    'en': 'To the plan: “%s” — %s',
  },
  'agentAddGoal': {
    'ru': 'Цель «%s» на %s',
    'en': 'Goal “%s” of %s',
  },

  // ── правила ──
  'rulesTitle': {
    'ru': 'Правила',
    'en': 'Rules',
  },
  'rulesSplitIncome': {
    'ru': 'Как делим доход',
    'en': 'How we split income',
  },
  'rulesSplitNote': {
    'ru': 'Нужды %s% · желания %s% · сбережения и долги %s%. Считается сама: '
        'три доли обязаны давать сто процентов.',
    'en': 'Needs %s% · wants %s% · savings and debt %s%. The last one counts '
        'itself: the three shares must add up to a hundred.',
  },
  'rulesSplitAdvice': {
    'ru': 'Совет из разборов семейного бюджета — 50/30/20, но это отправная '
        'точка, а не закон.',
    'en': 'Household budget guides suggest 50/30/20, but that is a starting '
        'point, not a law.',
  },
  'rulesSplitOver': {
    'ru': 'Нужды и желания вместе больше ста процентов — на сбережения не '
        'остаётся ничего.',
    'en': 'Needs and wants together pass a hundred percent — nothing is left '
        'for savings.',
  },
  'rulesRoundUp': {
    'ru': 'Округлять покупки в копилку',
    'en': 'Round purchases up into savings',
  },
  'rulesRoundUpNote': {
    'ru': 'Приложение добавит к трате разницу до кратного и переведёт её в '
        'цель — отдельной записью, которую видно в истории.',
    'en': 'The app adds the difference up to the step and moves it into a '
        'goal — as a separate record you can see in history.',
  },
  'rulesRoundUpNeedGoal': {
    'ru': 'Сначала заведите цель — округление должно куда-то складываться.',
    'en': 'Create a goal first — the rounding needs somewhere to go.',
  },
  'rulesRoundUpNone': {
    'ru': 'Не округлять',
    'en': 'No rounding',
  },
  'rulesRoundUpTo': {
    'ru': 'До %s',
    'en': 'To %s',
  },
  'rulesReview': {
    'ru': 'Пересматривать бюджет',
    'en': 'Review the budget',
  },
  'rulesReviewNote': {
    'ru': 'Раз в месяц или квартал стоит сесть и свериться: цифры меняются '
        'быстрее решений. Приложение напомнит на главной.',
    'en': 'Once a month or a quarter it pays to sit down and check: the '
        'numbers change faster than the decisions. The app reminds you on the '
        'home screen.',
  },
  'rulesReviewNever': {
    'ru': 'Не напоминать',
    'en': 'No reminders',
  },
  'rulesReviewMonth': {
    'ru': 'Раз в месяц',
    'en': 'Every month',
  },
  'rulesReviewQuarter': {
    'ru': 'Раз в квартал',
    'en': 'Every quarter',
  },
  'rulesReviewHalfYear': {
    'ru': 'Раз в полгода',
    'en': 'Every six months',
  },
  'rulesPot': {
    'ru': 'Общий кошелёк',
    'en': 'Shared wallet',
  },
  'rulesPotWarn': {
    'ru': 'Предупреждать о снятии',
    'en': 'Warn when taking money out',
  },
  'rulesPotWarnNote': {
    'ru': 'Приложение напомнит сказать партнёру, когда берёте из общего '
        'кошелька',
    'en': 'The app reminds you to tell your partner when you take from the '
        'shared wallet',
  },
  'rulesPotWhy': {
    'ru': 'Из общих денег берут двое, и договориться об этом дешевле, чем '
        'разбираться потом.',
    'en': 'Two people take from shared money, and agreeing up front is '
        'cheaper than sorting it out later.',
  },
  'rulesPotMax': {
    'ru': 'Больше этого — только с разговором, %s',
    'en': 'More than this needs a conversation, %s',
  },
  'rulesEmptyOk': {
    'ru': 'Можно оставить пустым',
    'en': 'You can leave this empty',
  },
  'rulesSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  // ── статистика ──
  'statsFlow': {
    'ru': 'Денежный поток',
    'en': 'Cash flow',
  },
  'statsIncome': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'statsSpending': {
    'ru': 'Расходы',
    'en': 'Spending',
  },
  'statsNet': {
    'ru': 'Итого',
    'en': 'Net',
  },
  'statsAverage': {
    'ru': 'Среднее',
    'en': 'Average',
  },
  'statsNoData': {
    'ru': 'Нет данных',
    'en': 'No data',
  },
  'statsNothingToCount': {
    'ru': 'Пока не из чего считать',
    'en': 'Nothing to count yet',
  },
  'statsCompare': {
    'ru': 'Сравнить',
    'en': 'Compare',
  },
  'statsCompareWith': {
    'ru': 'С отрезком «%s»',
    'en': 'With “%s”',
  },
  'statsCompareNone': {
    'ru': 'Для этого отрезка сравнивать не с чем',
    'en': 'There is nothing to compare this period with',
  },
  'statsPrevEmpty': {
    'ru': 'В прошлом отрезке операций не было',
    'en': 'The previous period had no operations',
  },
  'statsScopeAll': {
    'ru': 'Всё',
    'en': 'Everything',
  },
  'statsScopeShared': {
    'ru': 'Общее',
    'en': 'Shared',
  },
  'statsScopeMine': {
    'ru': 'Моё личное',
    'en': 'My own',
  },
  'statsForDays': {
    'ru': 'За %s %s',
    'en': 'Over %s %s',
  },
  'statsDay': {
    'ru': 'День',
    'en': 'Day',
  },
  'statsWeek': {
    'ru': 'Неделя',
    'en': 'Week',
  },
  'statsMonth': {
    'ru': 'Месяц',
    'en': 'Month',
  },
  // ── пара ──
  'pairInviteTitle': {
    'ru': 'Позвать партнёра',
    'en': 'Invite your partner',
  },
  'pairYourCode': {
    'ru': 'Ваш код',
    'en': 'Your code',
  },
  'pairCodeCopied': {
    'ru': 'Код скопирован',
    'en': 'Code copied',
  },
  'pairCopy': {
    'ru': 'Скопировать',
    'en': 'Copy',
  },
  'pairShowQr': {
    'ru': 'Показать QR',
    'en': 'Show the QR',
  },
  'pairHideQr': {
    'ru': 'Скрыть QR',
    'en': 'Hide the QR',
  },
  'pairQrNote': {
    'ru': 'Партнёр наводит камеру: ссылка откроет приложение с кодом',
    'en': 'Your partner points the camera: the link opens the app with the '
        'code',
  },
  'pairNewCode': {
    'ru': 'Выпустить новый код',
    'en': 'Issue a new code',
  },
  'pairHaveCode': {
    'ru': 'У меня есть код партнёра',
    'en': 'I have my partner’s code',
  },
  'pairEnterCode': {
    'ru': 'Введите код или вставьте ссылку',
    'en': 'Enter the code or paste the link',
  },
  'pairCodeField': {
    'ru': 'Код или ссылка',
    'en': 'Code or link',
  },
  'pairAccept': {
    'ru': 'Принять код',
    'en': 'Accept the code',
  },
  'pairSend': {
    'ru': 'Отправить',
    'en': 'Send',
  },
  'pairWait': {
    'ru': 'Секунду…',
    'en': 'One moment…',
  },
  'pairDone': {
    'ru': 'Готово, вы в паре',
    'en': 'Done, you are paired',
  },
  'pairBack': {
    'ru': 'Пара вернулась вместе со всей историей',
    'en': 'The pair is back, with all its history',
  },
  'pairNeedAccount': {
    'ru': 'Пара живёт на сервере, поэтому нужен аккаунт. Он общий для '
        'приложений Togetherly и заводится здесь же, почтой.',
    'en': 'A pair lives on the server, so an account is needed. It is shared '
        'across Togetherly apps and can be created right here, by email.',
  },
  'pairCodeLives': {
    'ru': 'Код не протухает: партнёр введёт его и через месяц. Третьего в '
        'пару он не пустит.',
    'en': 'The code does not expire: your partner can enter it a month later. '
        'It will not let a third person in.',
  },
  'pairHow': {
    'ru': 'Партнёр ставит Wallet, вводит код, и вы ведёте деньги вдвоём. '
        'Togetherly для этого не нужен.',
    'en': 'Your partner installs Wallet, enters the code, and you keep the '
        'money together. Togetherly is not needed for that.',
  },
  'pairShareText': {
    'ru': 'Ведём деньги вдвоём в Togetherly Wallet. Мой код: %s\n%s',
    'en': 'We keep our money together in Togetherly Wallet. My code: %s\n%s',
  },

  // Сколько файлов и чеков осталось в этом месяце. Строка стоит НАД полем
  // ввода: в самой капсуле счётчик ломал край скрепки («это криво очень»,
  // 17.09.2026).
  'askFilesLeft': {
    'ru': 'Файлов в этом месяце: %s из %s',
    'en': 'Files this month: %s of %s',
  },

  // Отчёт за период файлом.
  'reportRow': {
    'ru': 'Отчёт за период',
    'en': 'Period report',
  },
  'reportRowNote': {
    'ru': 'PDF с графиками или таблица',
    'en': 'A PDF with charts or a spreadsheet',
  },
  'reportTitle': {
    'ru': 'Отчёт',
    'en': 'Report',
  },
  'reportPeriod': {
    'ru': 'За какой отрезок',
    'en': 'Which period',
  },
  'reportScope': {
    'ru': 'Чьи деньги',
    'en': 'Whose money',
  },
  'reportFormat': {
    'ru': 'Чем открывать',
    'en': 'How to open it',
  },
  'reportFormatPdf': {
    'ru': 'PDF',
    'en': 'PDF',
  },
  'reportFormatPdfNote': {
    'ru': 'Итоги, категории полосами и список операций',
    'en': 'Totals, category bars and the list of records',
  },
  'reportFormatXlsxNote': {
    'ru': 'Все строки и график, который можно перестроить',
    'en': 'Every row and a chart you can rebuild',
  },
  'reportFormatXlsx': {
    'ru': 'Таблица',
    'en': 'Spreadsheet',
  },
  'reportBuild': {
    'ru': 'Собрать и поделиться',
    'en': 'Build and share',
  },
  'reportBuilding': {
    'ru': 'Собираем отчёт',
    'en': 'Building the report',
  },
  'reportFailed': {
    'ru': 'Отчёт не собрался. Попробуйте ещё раз',
    'en': 'The report did not build. Try again',
  },
  'reportNeedPlus': {
    'ru': 'Отчёт файлом открывает Wallet+',
    'en': 'The report file comes with Wallet+',
  },
  'reportNeedAccount': {
    'ru': 'Отчёт собирается на сервере: нужен вход',
    'en': 'The report is built on the server: sign in first',
  },
  'reportFreeNote': {
    'ru': 'Выгрузить всю базу можно бесплатно и всегда: это ваши записи',
    'en': 'Exporting the whole database is free and always will be',
  },
  'reportCategories': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'reportOperations': {
    'ru': 'Операции',
    'en': 'Records',
  },
  'reportSummary': {
    'ru': 'Сводка',
    'en': 'Summary',
  },
  'reportDate': {
    'ru': 'Дата',
    'en': 'Date',
  },
  'reportCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'reportAccount': {
    'ru': 'Счёт',
    'en': 'Account',
  },
  'reportNote': {
    'ru': 'Заметка',
    'en': 'Note',
  },
  'reportAmount': {
    'ru': 'Сумма',
    'en': 'Amount',
  },
  'reportCurrency': {
    'ru': 'Валюта',
    'en': 'Currency',
  },
  'reportMoreRows': {
    'ru': 'Остальные строки — в таблице',
    'en': 'The remaining rows are in the spreadsheet',
  },

  // Разбор месяца от модели: приходит сам первого числа.
  'monthReviewRow': {
    'ru': 'Разбор месяца',
    'en': 'Month review',
  },
  'monthReviewTitle': {
    'ru': 'Разбор',
    'en': 'Review',
  },
  'monthReviewCardTitle': {
    'ru': 'Разбор %s готов',
    'en': 'The review of %s is ready',
  },
  'monthReviewCardNote': {
    'ru': 'Куда ушли деньги, где просели против плана, что выросло',
    'en': 'Where the money went, where you missed the plan, what grew',
  },
  'monthReviewWriting': {
    'ru': 'Читаем месяц. Это займёт полминуты',
    'en': 'Reading the month. This takes half a minute',
  },
  'monthReviewEmpty': {
    'ru': 'За этот месяц записей нет, разбирать нечего',
    'en': 'No records for that month, nothing to review',
  },
  'monthReviewFailed': {
    'ru': 'Разбор не приехал. Попробуйте ещё раз',
    'en': 'The review did not arrive. Try again',
  },
  'monthReviewNeedPlus': {
    'ru': 'Разбор месяца открывает Wallet+',
    'en': 'The month review comes with Wallet+',
  },
};
