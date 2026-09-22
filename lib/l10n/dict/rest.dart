// Остальное: разбор списаний, разговор о деньгах, отбор, периоды, карточка
// счёта, перенос записей, реплики.
const Map<String, Map<String, String>> restStrings = {
  // ── разбор списаний ──
  'reviewTitle': {
    'ru': 'Новые списания',
    'en': 'New charges',
  },
  'reviewDone': {
    'ru': 'Разобрано всё. Новое списание появится здесь само, как только '
        'придёт уведомление банка.',
    'en': 'All done. A new charge shows up here on its own with the next bank '
        'notification.',
  },
  'reviewUnsure': {
    'ru': 'Разбор неуверенный — проверьте сумму по тексту уведомления.',
    'en': 'The reading is unsure — check the amount against the notification '
        'text.',
  },
  'reviewMaybeDouble': {
    'ru': 'Похоже, эта трата уже записана — тем же днём и на тот же счёт.',
    'en': 'Looks like this expense is already recorded — same day, same '
        'account.',
  },
  'reviewWhere': {
    'ru': 'Куда записать',
    'en': 'Where to record it',
  },
  'reviewPickAccount': {
    'ru': 'Выберите счёт',
    'en': 'Pick an account',
  },
  'reviewWhichCategory': {
    'ru': 'Какая категория',
    'en': 'Which category',
  },
  'reviewNoticeText': {
    'ru': 'Текст уведомления',
    'en': 'Notification text',
  },
  'reviewSave': {
    'ru': 'Записать',
    'en': 'Record',
  },
  'reviewLater': {
    'ru': 'Позже',
    'en': 'Later',
  },
  'reviewDismiss': {
    'ru': 'Не надо',
    'en': 'Skip it',
  },
  'reviewClearAll': {
    'ru': 'Убрать все',
    'en': 'Clear all',
  },
  'reviewSaveAll': {
    'ru': 'Записать все · %s',
    'en': 'Save all · %s',
  },
  'reviewSaveAllHint': {
    'ru': 'Остальные ждут ответа: счёт непонятен или разбор неуверенный',
    'en': 'The rest need you: no account, or the parse is unsure',
  },
  'reviewSetUp': {
    'ru': 'Настроить',
    'en': 'Set up',
  },
  // ── разговор о деньгах ──
  'askTitle': {
    'ru': 'Спросить о деньгах',
    'en': 'Ask about money',
  },
  'askInvite': {
    'ru': 'Спросите о деньгах',
    'en': 'Ask about your money',
  },
  'askHintPersonal': {
    'ru': 'Спросить о своих деньгах…',
    'en': 'Ask about your own money…',
  },
  'askHintShared': {
    'ru': 'Спросить об общем бюджете…',
    'en': 'Ask about the shared budget…',
  },
  'askScopePersonal': {
    'ru': 'Личный чат',
    'en': 'Personal chat',
  },
  'askScopeShared': {
    'ru': 'Общий чат',
    'en': 'Shared chat',
  },
  'askServerNote': {
    'ru': 'Сводку собирает сервер, а не приложение: так личное остаётся '
        'личным.',
    'en': 'The server builds the summary, not the app: that is how personal '
        'stays personal.',
  },
  'askLeft': {
    'ru': 'Осталось бесплатных вопросов: %s',
    'en': 'Free questions left: %s',
  },
  'askNoMore': {
    'ru': 'Вопросы на сегодня кончились',
    'en': 'No questions left for today',
  },
  'askWatch': {
    'ru': 'Посмотреть видео и получить вопрос',
    'en': 'Watch a video, get one question',
  },
  'goalLook': {
    'ru': 'Значок и цвет',
    'en': 'Icon and colour',
  },
  'goalRemoveWhere': {
    'ru': 'Куда вернуть %s',
    'en': 'Where to return %s',
  },
  'askWatchWait': {
    'ru': 'Показываем ролик…',
    'en': 'Playing the video…',
  },
  'askWatchLeft': {
    'ru': 'Видео сегодня: осталось %s',
    'en': 'Videos today: %s left',
  },
  'askWatchDone': {
    'ru': 'Вопрос открыт, спрашивайте',
    'en': 'One question unlocked, go ahead',
  },
  'askWatchFailed': {
    'ru': 'Ролик не показался. Попробуйте ещё раз',
    'en': 'The video did not play. Try again',
  },
  'askWatchOut': {
    'ru': 'Видео на сегодня кончились. Дальше Wallet+',
    'en': 'No videos left today. Wallet+ continues',
  },
  'askNoKey': {
    'ru': 'Чтобы отвечать на вопросы, нужен ключ модели в настройках',
    'en': 'Answering questions needs a model key in the settings',
  },
  'askNoAnswer': {
    'ru': 'Модель не ответила',
    'en': 'The model did not answer',
  },
  'askThinking': {
    'ru': 'Считаю…',
    'en': 'Counting…',
  },
  'askWholeHistory': {
    'ru': 'Ответ считается по вашей истории целиком.',
    'en': 'The answer counts your whole history.',
  },
  'askExampleFood': {
    'ru': 'Сколько мы тратим на еду?',
    'en': 'How much do we spend on food?',
  },
  'askExampleTop': {
    'ru': 'На что уходит больше всего?',
    'en': 'Where does most of it go?',
  },
  'askExampleEnough': {
    'ru': 'Хватит ли до конца месяца?',
    'en': 'Will it last until the end of the month?',
  },
  'askEmptyTitle': {
    'ru': 'Спросите о деньгах или скажите, что записать',
    'en': 'Ask about money, or say what to record',
  },
  'askAsk': {
    'ru': 'Спросить',
    'en': 'Ask',
  },
  'askAttachment': {
    'ru': 'Вложение: %s',
    'en': 'Attachment: %s',
  },
  'askClear': {
    'ru': 'Забыть переписку',
    'en': 'Forget the conversation',
  },
  'askClearNote': {
    'ru': 'Чат перестанет помнить, о чём вы говорили. Записанные траты, счета '
        'и лимиты останутся на месте.',
    'en': 'The chat will stop remembering what you talked about. Recorded '
        'expenses, accounts and limits stay where they are.',
  },
  'askClearDo': {
    'ru': 'Забыть',
    'en': 'Forget',
  },
  'askDo': {
    'ru': 'Сделать',
    'en': 'Do',
  },
  'askExampleAdd': {
    'ru': 'Я потратил 150 на чипсы',
    'en': 'I spent 150 on chips',
  },
  'askExampleAccount': {
    'ru': 'Заведи счёт Зал',
    'en': 'Create an account called Gym',
  },
  'askExampleLimit': {
    'ru': 'Поставь лимит на кафе 1200',
    'en': 'Set a 1200 limit on cafes',
  },
  'askExampleFile': {
    'ru': 'Разбери выписку из файла',
    'en': 'Read the statement from a file',
  },
  'chatTitle': {
    'ru': 'Чат',
    'en': 'Chat',
  },
  'chatHint': {
    'ru': 'Спросить или объяснить…',
    'en': 'Ask or explain…',
  },
  'chatExampleFood': {
    'ru': 'Сколько я трачу на еду?',
    'en': 'How much do I spend on food?',
  },
  // ── правило дележа ──
  'splitRuleTitle': {
    'ru': 'Как делим общие траты',
    'en': 'How we split shared spending',
  },
  'splitRuleDefault': {
    'ru': 'Это правило по умолчанию: с ним записывается новая общая трата. '
        'У каждой траты правило можно поменять на месте.',
    'en': 'This is the default: a new shared expense is recorded with it. You '
        'can change the rule on any single expense.',
  },
  'splitRuleEqual': {
    'ru': 'Пополам, сколько бы кто ни зарабатывал',
    'en': 'Half and half, whoever earns what',
  },
  'splitRuleIncome': {
    'ru': 'Тот, у кого доход больше, платит большую долю',
    'en': 'Whoever earns more pays the bigger share',
  },
  'splitRulePayer': {
    'ru': 'Общие траты не делятся: платит тот, кто платил',
    'en': 'Shared spending is not split: whoever paid, paid',
  },
  'splitRuleLast': {
    'ru': 'Доля последнего считается сама: сумма долей обязана быть ровно '
        '100%.',
    'en': 'The last share counts itself: the shares must add up to exactly '
        '100%.',
  },
  'splitRuleSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  // ── перенос записей ──
  'importAskTitle': {
    'ru': 'Перенести ваши записи?',
    'en': 'Move your records over?',
  },
  'importAskText': {
    'ru': 'На телефоне %s %s, сделанных без аккаунта. Перенесём — они приедут '
        'на другие ваши устройства и, если у вас есть пара, станут видны '
        'партнёру.',
    'en': 'There are %s %s on this phone, made without an account. Move them '
        'over and they reach your other devices — and your partner, if you '
        'have a pair.',
  },
  'importAskMove': {
    'ru': 'Перенести',
    'en': 'Move them',
  },
  'importAskKeep': {
    'ru': 'Оставить на телефоне',
    'en': 'Keep on the phone',
  },
  'records.one': {
    'ru': 'запись',
    'en': 'record',
  },
  'records.few': {
    'ru': 'записи',
    'en': 'records',
  },
  'records.many': {
    'ru': 'записей',
    'en': 'records',
  },
  'records.other': {
    'ru': 'записей',
    'en': 'records',
  },
  // ── отбор и отрезки ──
  'filterTitle': {
    'ru': 'Отбор',
    'en': 'Filter',
  },
  'filterApply': {
    'ru': 'Применить',
    'en': 'Apply',
  },
  'filterReset': {
    'ru': 'Сбросить',
    'en': 'Reset',
  },
  'filterPeriod': {
    'ru': 'За какой отрезок',
    'en': 'Which period',
  },
  'filterPickPeriod': {
    'ru': 'Выбрать период',
    'en': 'Pick a period',
  },
  'filterKind': {
    'ru': 'Порядок',
    'en': 'Order',
  },
  'filterNoAccounts': {
    'ru': 'Счетов пока нет',
    'en': 'No accounts yet',
  },
  'filterNoCategories': {
    'ru': 'Категорий пока нет',
    'en': 'No categories yet',
  },
  'periodToday': {
    'ru': 'Сегодня',
    'en': 'Today',
  },
  'periodWeekly': {
    'ru': 'Неделя',
    'en': 'Week',
  },
  'periodMonthly': {
    'ru': 'Месяц',
    'en': 'Month',
  },
  'periodYear': {
    'ru': 'Год',
    'en': 'Year',
  },
  'periodAll': {
    'ru': 'Всё время',
    'en': 'All time',
  },
  'periodOwn': {
    'ru': 'Свой отрезок',
    'en': 'Custom period',
  },
  'periodEarlier': {
    'ru': 'Раньше',
    'en': 'Earlier',
  },
  'periodLater': {
    'ru': 'Позже',
    'en': 'Later',
  },
  // ── мелочи ──
  'cardNoNumber': {
    'ru': 'Без номера',
    'en': 'No number',
  },
  'designInk': {
    'ru': 'Чёрная',
    'en': 'Black',
  },
  'designGraphite': {
    'ru': 'Графит',
    'en': 'Graphite',
  },
  'designSteel': {
    'ru': 'Сталь',
    'en': 'Steel',
  },
  'designMint': {
    'ru': 'Мята',
    'en': 'Mint',
  },
  'designLavender': {
    'ru': 'Лаванда',
    'en': 'Lavender',
  },
  'designSky': {
    'ru': 'Небо',
    'en': 'Sky',
  },
  'designSand': {
    'ru': 'Песок',
    'en': 'Sand',
  },
  'designPeach': {
    'ru': 'Персик',
    'en': 'Peach',
  },
  'designCoral': {
    'ru': 'Коралл',
    'en': 'Coral',
  },
  'designPaper': {
    'ru': 'Бумага',
    'en': 'Paper',
  },
  'categoriesListTitle': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'categoriesEditRow': {
    'ru': 'Редактировать категории',
    'en': 'Edit categories',
  },
  'categoriesSeeOps': {
    'ru': 'Под ним видно сами операции.',
    'en': 'The operations themselves are visible below it.',
  },
  'noIncomeInPeriod': {
    'ru': 'За этот отрезок доходов не было',
    'en': 'No income in this period',
  },
  'noSpendingInPeriod': {
    'ru': 'За этот отрезок расходов не было',
    'en': 'No spending in this period',
  },
  'nothingToStack': {
    'ru': 'Пока не из чего складывать',
    'en': 'Nothing to stack up yet',
  },
  'nothingToDraw': {
    'ru': 'Пока не из чего строить',
    'en': 'Nothing to draw yet',
  },
  'commentsEmpty': {
    'ru': 'Пока тихо. Спросите про эту трату здесь — вопрос останется рядом с '
        'суммой, а не потеряется в переписке.',
    'en': 'Quiet so far. Ask about this expense here — the question stays next '
        'to the amount instead of getting lost in a chat.',
  },
  'meShort': {
    'ru': 'Я',
    'en': 'Me',
  },
  'youShort': {
    'ru': 'Вы',
    'en': 'You',
  },
  'inviteQrAlt': {
    'ru': 'Код приглашения в виде QR',
    'en': 'The invite code as a QR',
  },
  'andMoreRows': {
    'ru': 'И ещё %s',
    'en': '%s more',
  },
};
