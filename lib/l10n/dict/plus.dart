// Wallet+: витрина, калитки и состояние подписки.
//
// Слова калиток говорят, ЧТО откроется, а не «оформите подписку»: человек,
// упёршийся в потолок, должен понять причину с первой строки.
const Map<String, Map<String, String>> plusStrings = {
  'plusQuarter': {
    'ru': '3 месяца',
    'en': '3 months',
  },
  'plusSaving': {
    'ru': 'Выгода %s%',
    'en': 'Save %s%',
  },
  'plusSeatTitle': {
    'ru': 'Второе место',
    'en': 'The second seat',
  },
  'plusSeatFree': {
    'ru': 'Никому не отдано',
    'en': 'Given to nobody',
  },
  'plusSeatNone': {
    'ru': 'Место останется у вас одного',
    'en': 'The seat stays with you alone',
  },
  'plusSeatWith': {
    'ru': 'Плюс откроется вам и этому человеку',
    'en': 'Plus opens for you and this person',
  },
  'plusSeatPick': {
    'ru': 'Кому открыть Плюс',
    'en': 'Who else gets Plus',
  },
  'plusSeatOnlyMe': {
    'ru': 'Только мне',
    'en': 'Just me',
  },
  'plusSeatGroup': {
    'ru': 'В группе %s — второе место не даётся',
    'en': 'A group of %s — no second seat',
  },
  'plusSeatSoon': {
    'ru': 'Сменить можно раз в 30 дней',
    'en': 'You can hand it over once in 30 days',
  },
  'plusSeatWait': {
    'ru': 'Место уже меняли: следующий раз через %s дн.',
    'en': 'Already handed over: next time in %s days',
  },
  'plusSeatDisband': {
    'ru': 'Распадётся пара — место вернётся к вам',
    'en': 'If the pair breaks up, the seat comes back to you',
  },
  'plusPayOpened': {
    'ru': 'Оплата открыта в браузере. Вернитесь сюда, когда закончите.',
    'en': 'Payment opened in the browser. Come back when you are done.',
  },
  'plusPayFailed': {
    'ru': 'Касса не ответила. Попробуйте ещё раз.',
    'en': 'The checkout did not answer. Try again.',
  },
  'plusName': {
    'ru': 'Wallet+',
    'en': 'Wallet+',
  },
  'plusSection': {
    'ru': 'Подписка',
    'en': 'Subscription',
  },
  'plusTitle': {
    'ru': 'Деньги на автопилоте',
    'en': 'Money on autopilot',
  },
  'plusText': {
    'ru': 'Учёт, счета, отчёты и всё, что делается вдвоём, остаются '
        'бесплатными. Подписка берёт на себя работу, которую иначе делаете '
        'руками.',
    'en': 'Tracking, accounts, reports and everything you do together stay '
        'free. The subscription takes over the work you would otherwise do '
        'by hand.',
  },
  'plusMonth': {
    'ru': 'Месяц',
    'en': 'Monthly',
  },
  'plusYear': {
    'ru': 'Год',
    'en': 'Yearly',
  },
  'plusYearSave': {
    'ru': 'Выгоднее на 37%',
    'en': 'Save 37%',
  },
  'plusTrial': {
    'ru': 'Первые 7 дней бесплатно',
    'en': 'First 7 days free',
  },
  'plusBuy': {
    'ru': 'Оформить',
    'en': 'Subscribe',
  },
  'plusRestore': {
    'ru': 'Вернуть покупку',
    'en': 'Restore purchase',
  },
  'plusPerPair': {
    'ru': 'Одна подписка на пару: партнёру платить не нужно',
    'en': 'One subscription per couple: your partner pays nothing',
  },
  'plusActive': {
    'ru': 'Подписка работает',
    'en': 'Subscription active',
  },
  'plusUntil': {
    'ru': 'Оплачено до %s',
    'en': 'Paid through %s',
  },
  'plusFromPartner': {
    'ru': 'Открыто подпиской партнёра',
    'en': 'Opened by your partner’s subscription',
  },
  'plusOffline': {
    'ru': 'Без сети подписка работает ещё %s',
    'en': 'Offline the subscription keeps working for %s more',
  },
  'plusManage': {
    'ru': 'Управлять подпиской',
    'en': 'Manage subscription',
  },

  // Что входит.
  'plusWhatsIn': {
    'ru': 'Что входит',
    'en': 'What you get',
  },
  'plusFeatureChat': {
    'ru': 'Чат без дневного потолка',
    'en': 'Chat with no daily cap',
  },
  'plusFeatureChatNote': {
    'ru': 'Без подписки три вопроса в сутки',
    'en': 'Three questions a day without it',
  },
  'plusFeatureFiles': {
    'ru': 'Чеки и выписки без счёта',
    'en': 'Receipts and statements without a cap',
  },
  'plusFeatureFilesNote': {
    'ru': 'Фото чека, PDF, CSV, Excel; без подписки пять файлов в месяц',
    'en': 'Receipt photos, PDF, CSV, Excel; five files a month without it',
  },
  'plusFeatureAuto': {
    'ru': 'Записывать траты молча',
    'en': 'Record spending silently',
  },
  'plusFeatureAutoNote': {
    'ru': 'Разбор уведомлений с подтверждением остаётся бесплатным',
    'en': 'Reading notifications with confirmation stays free',
  },
  'plusFeatureRules': {
    'ru': 'Свои правила разбора',
    'en': 'Your own parsing rules',
  },
  'plusFeatureRulesNote': {
    'ru': '«Больше 2000 — спроси», «Wolt по будням — Еда вне дома, пополам»',
    'en': '“Over 2000 — ask me”, “Wolt on weekdays — Eating out, split evenly”',
  },
  'plusFeaturePlanning': {
    'ru': 'Бюджеты, цели, долги и регулярное без счёта',
    'en': 'Budgets, goals, debts and recurring without a cap',
  },
  'plusFeaturePlanningNote': {
    'ru': 'Бесплатно: 5 бюджетов, 2 цели, 2 долга, 3 регулярных',
    'en': 'Free: 5 budgets, 2 goals, 2 debts, 3 recurring',
  },
  'plusFeatureReport': {
    'ru': 'Отчёт за период файлом',
    'en': 'A period report as a file',
  },
  'plusFeatureReportNote': {
    'ru': 'PDF и Excel с графиками; выгрузка базы бесплатна всегда',
    'en': 'PDF and Excel with charts; the raw backup is always free',
  },
  'plusFeatureReview': {
    'ru': 'Разбор месяца первого числа',
    'en': 'A month review on the first',
  },
  'plusFeatureReviewNote': {
    'ru': 'Куда ушли деньги, где просели против плана, что выросло',
    'en': 'Where the money went, where you missed the plan, what grew',
  },
  'plusFeatureForecast': {
    'ru': 'Прогноз конца месяца',
    'en': 'End-of-month forecast',
  },
  'plusFeatureForecastNote': {
    'ru': 'Сколько останется такими темпами и чего не хватит',
    'en': 'What is left at this pace and what will fall short',
  },
  'plusFeatureLock': {
    'ru': 'Замок на вход',
    'en': 'App lock',
  },
  'plusFeatureLockNote': {
    'ru': 'PIN и отпечаток',
    'en': 'PIN and fingerprint',
  },
  'plusFeatureBackups': {
    'ru': 'Возврат к любому дню',
    'en': 'Roll back to any day',
  },
  'plusFeatureBackupsNote': {
    'ru': 'Снимок базы за каждый день, зашифрованный. Сама пара '
        'синхронизируется всегда и бесплатно',
    'en': 'An encrypted snapshot of the database for every day. Syncing the '
        'pair itself always works and stays free',
  },
  'plusFeatureLooks': {
    'ru': 'Премиальные оформления карт',
    'en': 'Premium card designs',
  },
  'plusFeatureLooksNote': {
    'ru': 'Глубокие цвета и фактуры, которых нет в бесплатном наборе',
    'en': 'Deep colours and textures the free set does not have',
  },

  // Счёт до потолка: сколько занято из бесплатного.
  'plusMeterTaken': {
    'ru': 'Занято %s из %s',
    'en': 'Taken %s of %s',
  },

  // Калитки: у каждой своя причина.
  'plusGateChat': {
    'ru': 'Три вопроса в сутки бесплатны. Каждый ответ пишет модель, и каждый '
        'стоит нам денег, поэтому дальше — подписка или ролик за вопрос.',
    'en': 'Three questions a day are free. Every answer is written by the '
        'model and costs us money, so beyond that it is the subscription or a '
        'video for one more question.',
  },
  'plusGateFiles': {
    'ru': 'Пять файлов в месяц бесплатно. Чек читает зрячая модель, а выписку '
        'разбирает сервер — это самое дорогое, что есть в приложении.',
    'en': 'Five files a month are free. A receipt is read by a vision model '
        'and a statement is parsed on the server — the most expensive thing '
        'the app does.',
  },
  'plusGateTitle': {
    'ru': 'Это в Wallet+',
    'en': 'This is in Wallet+',
  },
  'plusGateEnvelope': {
    'ru': 'Бесплатно ведутся пять бюджетов — этого хватает на еду, дорогу, '
        'дом, связь и развлечения. Шестой и дальше открывает подписка.',
    'en': 'Five budgets are free — food, transport, home, phone and fun. '
        'The sixth and beyond come with the subscription.',
  },
  'plusGateGoal': {
    'ru': 'Две цели бесплатно, включая подушку. Третья и дальше — в подписке.',
    'en': 'Two goals are free, the safety net included. The third and beyond '
        'come with the subscription.',
  },
  'plusGateDebt': {
    'ru': 'Два долга бесплатно. Если их больше, приложение считает порядок '
        'погашения и проценты в месяц — это в подписке.',
    'en': 'Two debts are free. With more of them the app plans the payoff '
        'order and monthly interest, and that is in the subscription.',
  },
  'plusGateRecurring': {
    'ru': 'Три регулярных платежа бесплатно. Дальше — в подписке.',
    'en': 'Three recurring payments are free. Beyond that, the subscription.',
  },
  'plusGatePlanAhead': {
    'ru': 'План на текущий месяц бесплатный. Планировать вперёд можно с '
        'подпиской.',
    'en': 'The current month’s plan is free. Planning ahead comes with the '
        'subscription.',
  },
  'plusGateAutoNotices': {
    'ru': 'Разбор уведомлений бесплатен: трата приходит в «Новые списания», вы '
        'её подтверждаете. Записывать молча, без подтверждения, — в подписке.',
    'en': 'Reading notifications is free: the charge lands in “New charges” '
        'and you confirm it. Recording silently is in the subscription.',
  },
  'plusGateRules': {
    'ru': 'Приложение и так запоминает, какую категорию вы ставите магазину. '
        'Правила с условиями — по сумме, дню недели, счёту — в подписке.',
    'en': 'The app already remembers the category you give a merchant. Rules '
        'with conditions — amount, weekday, account — are in the subscription.',
  },
  'plusGateLock': {
    'ru': 'Замок на вход — в подписке.',
    'en': 'The app lock is in the subscription.',
  },
  'plusGateReport': {
    'ru': 'Отчёт файлом — в подписке. Выгрузить всю базу можно бесплатно и '
        'всегда: это ваши записи.',
    'en': 'The report file is in the subscription. Exporting the whole '
        'database is free and always will be: these are your records.',
  },
  'plusGateReview': {
    'ru': 'Разбор месяца пишет модель, и каждый такой разбор нам чего-то '
        'стоит. Поэтому он в подписке.',
    'en': 'The month review is written by the model and costs us money on '
        'every run. That is why it is in the subscription.',
  },
  'plusGateLooks': {
    'ru': 'Дополнительные оформления карт — в подписке.',
    'en': 'Extra card designs are in the subscription.',
  },
  'plusGateBackups': {
    'ru': 'Вернуться к состоянию на любой прошлый день — в подписке. Данные '
        'пары живут на сервере всегда: без этого не было бы общих счетов. '
        'Копии на телефоне приложение делает само и бесплатно.',
    'en': 'Rolling back to any past day is in the subscription. Your pair '
        'data always lives on the server — shared accounts would not work '
        'otherwise. On-device copies are made automatically and for free.',
  },
  'plusGateOpen': {
    'ru': 'Смотреть Wallet+',
    'en': 'See Wallet+',
  },
  'plusGateLater': {
    'ru': 'Не сейчас',
    'en': 'Not now',
  },
  'plusSoon': {
    'ru': 'Покупка скоро откроется',
    'en': 'Purchases open soon',
  },
  'plusFreeTitle': {
    'ru': 'Что бесплатно навсегда',
    'en': 'Free forever',
  },
  'plusFreeText': {
    'ru': 'Счета и операции без счёта, категории, история и поиск, отчёты, '
        'работа без сети, выгрузка базы. Синхронизация пары и хранение её '
        'данных на сервере. Всё, что делается вдвоём: общие и личные счета, '
        'дележ, сальдо, скрытые траты, разговор под операцией. '
        'Разбор банковских уведомлений с подтверждением.',
    'en': 'Unlimited accounts and records, categories, history and search, '
        'reports, offline work, database export. Everything you do together: '
        'shared and personal accounts, splitting, balances, hidden spending, '
        'the thread under a record. Bank notifications with confirmation.',
  },
};
