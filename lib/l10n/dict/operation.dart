// Запись и правка операции.
//
// Здесь человек решает про деньги, поэтому английский подобран по смыслу, а не
// по словам: «Сделать сюрпризом» — «Make it a surprise», «Не делить» —
// «Don't split», «Раскроется» — «Opens on».
const Map<String, Map<String, String>> operationStrings = {
  'opBigSpend': {
    'ru': 'Договорились обсуждать траты дороже %s. %s увидит эту запись',
    'en': 'You agreed to talk about spending over %s. %s will see this record',
  },

  'opFromOwn': {
    'ru': 'Из своих денег',
    'en': 'From their own money',
  },
  'opMoveToPair': {
    'ru': 'Перенести в другую пару',
    'en': 'Move to another pair',
  },
  'opMoveTitle': {
    'ru': 'Куда перенести',
    'en': 'Where to move it',
  },
  'opMoveText': {
    'ru': 'Запись уйдёт целиком: нынешняя пара её больше не увидит',
    'en': 'The record moves whole: the current pair will no longer see it',
  },

  'opShareWith': {
    'ru': 'Разделить с другой парой',
    'en': 'Share with another pair',
  },
  'opSharedWith': {
    'ru': 'Делим с %s',
    'en': 'Shared with %s',
  },
  'opShareTitle': {
    'ru': 'С кем делим',
    'en': 'Who shares this',
  },
  'opShareText': {
    'ru': 'Деньги уйдут с этого счёта. Выбранная пара увидит трату расчётом — сумму и кто платил, без вашего счёта',
    'en': 'The money still leaves this account. The chosen pair sees the expense as a settlement: the amount and who paid, without your account',
  },
  'opShareNone': {
    'ru': 'Ни с кем',
    'en': 'With no one',
  },

  'opNew': {
    'ru': 'Новая операция',
    'en': 'New operation',
  },
  'opEdit': {
    'ru': 'Операция',
    'en': 'Operation',
  },
  'opSave': {
    'ru': 'Записать',
    'en': 'Save',
  },
  'opSaved': {
    'ru': 'Записано',
    'en': 'Saved',
  },
  'opChanged': {
    'ru': 'Изменено',
    'en': 'Updated',
  },
  'opSaveWord': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'opDelete': {
    'ru': 'Удалить',
    'en': 'Delete',
  },
  'opDeleteTitle': {
    'ru': 'Удалить операцию?',
    'en': 'Delete this operation?',
  },
  'opDeleteText': {
    'ru': 'Её можно будет вернуть полосой отмены внизу экрана.',
    'en': 'You can bring it back from the undo bar at the bottom.',
  },
  'opSpending': {
    'ru': 'Расход',
    'en': 'Spending',
  },
  'opIncome': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'opTransfer': {
    'ru': 'Перевод',
    'en': 'Transfer',
  },
  'opAccount': {
    'ru': 'Счёт',
    'en': 'Account',
  },
  'opAccountNew': {
    'ru': 'Счёта ещё нет — заведём «%s» при записи',
    'en': 'No account yet — we will create “%s” as you record',
  },
  'opAccountMake': {
    'ru': 'Завести свой',
    'en': 'Create my own',
  },
  'accountDefaultName': {
    'ru': 'Наличные',
    'en': 'Cash',
  },
  'opMoveFrom': {
    'ru': 'Откуда',
    'en': 'From',
  },
  'opMoveTo': {
    'ru': 'Куда',
    'en': 'To',
  },
  'opMovePick': {
    'ru': 'Выберите, куда переводите',
    'en': 'Choose where the money goes',
  },
  'opMoved': {
    'ru': 'Переведено',
    'en': 'Transferred',
  },
  'opToday': {
    'ru': 'Сегодня',
    'en': 'Today',
  },
  'opYesterday': {
    'ru': 'Вчера',
    'en': 'Yesterday',
  },
  // Вкладки нижней панели: одна панель, три состояния.
  'opCategorySearch': {
    'ru': 'Найти категорию',
    'en': 'Find a category',
  },
  'opTabKeys': {
    'ru': 'Клавиши',
    'en': 'Keys',
  },
  'opTabCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'opTabWallet': {
    'ru': 'Счёт',
    'en': 'Account',
  },
  'opPickCategory': {
    'ru': 'Выберите категорию',
    'en': 'Pick a category',
  },
  'opPickCategoryNote': {
    'ru': 'Без неё трата не попадёт в отчёты',
    'en': 'Without one the expense stays out of reports',
  },
  'opSubsOf': {
    'ru': 'Уточнить: %s',
    'en': 'Narrow down: %s',
  },
  'opPayerTitle': {
    'ru': 'Кто платил',
    'en': 'Who paid',
  },
  'opPayerNote': {
    'ru': 'С чьих денег ушла трата',
    'en': 'Whose money went out',
  },
  'opSplitTitle': {
    'ru': 'Как делим',
    'en': 'How we split',
  },
  'opTime': {
    'ru': 'Время',
    'en': 'Time',
  },
  'opTomorrow': {
    'ru': 'Завтра',
    'en': 'Tomorrow',
  },
  'opTimeAdd': {
    'ru': 'Время',
    'en': 'Time',
  },
  'opTimeWhen': {
    'ru': 'Во сколько',
    'en': 'What time',
  },
  'opNoteShort': {
    'ru': 'Заметка',
    'en': 'Note',
  },
  'opNoteAdd': {
    'ru': 'Добавить заметку',
    'en': 'Add a note',
  },
  'opNoteWhy': {
    'ru': 'Строчка для себя: за что платили, кому, с кем. В отчётах она не '
        'считается — только помогает вспомнить.',
    'en': 'A line for yourself: what it was for, to whom, with whom. Reports '
        'ignore it — it only helps you remember.',
  },
  'opNoteHint': {
    'ru': 'Например, обед с Линеллой',
    'en': 'For example, lunch with Linella',
  },
  'opCurrency': {
    'ru': 'Валюта',
    'en': 'Currency',
  },
  'opCurrencyOfOperation': {
    'ru': 'Валюта операции',
    'en': 'Operation currency',
  },
  'opCurrencyOther': {
    'ru': 'Другая',
    'en': 'Other',
  },
  'opCurrencyCode': {
    'ru': 'Код валюты',
    'en': 'Currency code',
  },
  'opRate': {
    'ru': 'по курсу %s',
    'en': 'at %s',
  },
  'opRateMissing': {
    'ru': 'Курс %s не задан — в итогах пойдёт один к одному',
    'en': 'No rate for %s — totals will count it one to one',
  },
  'opSameAmount': {
    'ru': 'В итогах: та же сумма',
    'en': 'In totals: the same amount',
  },
  'opCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'opSubcategory': {
    'ru': 'Подкатегория',
    'en': 'Subcategory',
  },
  'opCategoryNew': {
    'ru': 'Новая категория',
    'en': 'New category',
  },
  'opCategoryNewText': {
    'ru': 'Название увидит и партнёр: по нему считаются доли и лимиты.',
    'en': 'Your partner sees this name too: shares and limits count by it.',
  },
  'opCategoryName': {
    'ru': 'Название',
    'en': 'Name',
  },
  'opAdd': {
    'ru': 'Добавить',
    'en': 'Add',
  },
  'opMoreSubs': {
    'ru': 'Ещё %s',
    'en': '%s more',
  },
  'opNote': {
    'ru': 'Заметка',
    'en': 'Note',
  },
  'opWhen': {
    'ru': 'Когда',
    'en': 'When',
  },
  'opTalk': {
    'ru': 'Разговор',
    'en': 'Comments',
  },
  'opPartnerDative': {
    'ru': 'партнёру',
    'en': 'your partner',
  },
  'opSplitNone': {
    'ru': 'Не делить',
    'en': 'Don’t split',
  },
  'opSplitEqual': {
    'ru': 'Поровну',
    'en': 'Split evenly',
  },
  'opSplitIncome': {
    'ru': 'По доходу',
    'en': 'By income',
  },
  'opSplitOwn': {
    'ru': 'Своя',
    'en': 'Custom',
  },
  'opSplitPayer': {
    'ru': 'Только себе',
    'en': 'Payer only',
  },
  'opSecretShort': {
    'ru': 'Сюрприз',
    'en': 'Surprise',
  },
  'opSecretOff': {
    'ru': 'Не сюрприз',
    'en': 'Not a surprise',
  },
  'opMe': {
    'ru': 'Я',
    'en': 'Me',
  },
  'opSecretMake': {
    'ru': 'Сделать сюрпризом',
    'en': 'Make it a surprise',
  },
  'opSecretNote': {
    'ru': 'Сюрприз: партнёр увидит сумму, но не суть',
    'en': 'Surprise: your partner sees the amount, not what it was for',
  },
  'opRevealWhen': {
    'ru': 'Когда раскрыть',
    'en': 'When to reveal',
  },
  'opRevealAt': {
    'ru': 'Раскроется %s',
    'en': 'Opens on %s',
  },
  'opRoundUp': {
    'ru': 'В копилку ушло %s ',
    'en': 'Rounded %s into savings ',
  },
  'opPotLimit': {
    'ru': 'Вы договорились брать из общего кошелька не больше ',
    'en': 'You agreed to take no more than ',
  },
  'opPotLimitTail': {
    'ru': '%s за раз — скажите %s',
    'en': '%s at a time from the shared wallet — tell %s',
  },
  'opPotTell': {
    'ru': 'Из общего кошелька: скажите %s',
    'en': 'From the shared wallet: tell %s',
  },
};
