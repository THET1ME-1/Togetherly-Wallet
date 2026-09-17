// Счета и карты, валюта с курсами, договорённости пары.
const Map<String, Map<String, String>> accountStrings = {
  'currencyPickTitle': {
    'ru': 'Валюта',
    'en': 'Currency',
  },
  'currencyPickSearch': {
    'ru': 'Код или название',
    'en': 'Code or name',
  },
  'currencyPickOwn': {
    'ru': 'Своя валюта',
    'en': 'Custom currency',
  },
  'currencyConvert': {
    'ru': 'Пересчёт',
    'en': 'Convert',
  },
  'currencyMine': {
    'ru': 'Мои валюты',
    'en': 'My currencies',
  },

  'currencyAdd': {
    'ru': 'Добавить',
    'en': 'Add',
  },
  'currencyAddHint': {
    'ru': 'GBP',
    'en': 'GBP',
  },

  'accountsTitle': {
    'ru': 'Счета',
    'en': 'Accounts',
  },
  'accountsCards': {
    'ru': 'Ваши карты',
    'en': 'Your cards',
  },
  'accountNew': {
    'ru': 'Новый счёт',
    'en': 'New account',
  },
  'accountNewShort': {
    'ru': 'Новая',
    'en': 'New',
  },
  'accountCreate': {
    'ru': 'Завести',
    'en': 'Create',
  },
  'accountName': {
    'ru': 'Имя счёта',
    'en': 'Account name',
  },
  'accountNameHint': {
    'ru': 'Карта maib',
    'en': 'Maib card',
  },
  'accountNameShort': {
    'ru': 'Имя',
    'en': 'Name',
  },
  'accountRename': {
    'ru': 'Переименовать',
    'en': 'Rename',
  },
  'accountEmpty': {
    'ru': 'Пока пусто',
    'en': 'Nothing here yet',
  },
  'accountEmptyHow': {
    'ru': 'Счёт появится сам, как только запишете первую операцию',
    'en': 'An account appears on its own with your first operation',
  },
  'accountsNone': {
    'ru': 'Счетов пока нет',
    'en': 'No accounts yet',
  },
  'accountsNoneText': {
    'ru': 'Заведите первый — карту, наличные или копилку. Операции будут '
        'копиться на нём, а карту можно узнать по цвету и четырём цифрам.',
    'en': 'Create the first one: a card, cash or a jar. Operations pile up on '
        'it, and a card is recognised by its colour and last four digits.',
  },
  'accountFirst': {
    'ru': 'Завести счёт',
    'en': 'Create an account',
  },
  'accountNoOperations': {
    'ru': 'На этом счёте пока нет операций',
    'en': 'No operations on this account yet',
  },
  'accountWhose': {
    'ru': 'Чей это счёт',
    'en': 'Whose account',
  },
  'accountKind': {
    'ru': 'Что это за счёт',
    'en': 'What kind of account',
  },
  'accountIsShared': {
    'ru': 'Общий',
    'en': 'Shared',
  },
  'accountSharedNote': {
    'ru': 'Общий: видите оба',
    'en': 'Shared: you both see it',
  },
  'accountPersonal': {
    'ru': 'Личный счёт',
    'en': 'Personal account',
  },
  'accountOnlyYou': {
    'ru': 'Только вы',
    'en': 'Only you',
  },
  'accountPersonalNote': {
    'ru': 'Партнёр не увидит ни остаток, ни операции по нему',
    'en': 'Your partner sees neither the balance nor the operations',
  },
  'accountPot': {
    'ru': 'Общий кошелёк',
    'en': 'Shared wallet',
  },
  'accountPotNote': {
    'ru': 'Из него платите общее',
    'en': 'You pay shared things from it',
  },
  'accountLast4': {
    'ru': 'Последние 4 цифры',
    'en': 'Last 4 digits',
  },
  'accountBrand': {
    'ru': 'Платёжная система',
    'en': 'Payment network',
  },
  'accountBrandNone': {
    'ru': 'Без системы',
    'en': 'No network',
  },
  'accountBank': {
    'ru': 'Банк карты',
    'en': 'Card issuer',
  },
  'accountIcon': {
    'ru': 'Значок',
    'en': 'Icon',
  },
  'accountLook': {
    'ru': 'Оформление',
    'en': 'Design',
  },
  'accountEditTitle': {
    'ru': 'Счёт',
    'en': 'Account',
  },
  'accountTexture': {
    'ru': 'Фактура',
    'en': 'Texture',
  },
  'textureWatermark': {
    'ru': 'Имя повторами',
    'en': 'Name repeated',
  },
  'textureGuilloche': {
    'ru': 'Сетка линий',
    'en': 'Line mesh',
  },
  'textureStripes': {
    'ru': 'Ленты наискось',
    'en': 'Diagonal bands',
  },
  'accountOwn': {
    'ru': 'Своя',
    'en': 'Custom',
  },
  'accountTotal': {
    'ru': 'Всего',
    'en': 'Total',
  },
  'accountAllTogether': {
    'ru': 'Всё вместе',
    'en': 'Everything together',
  },
  'accountInGoals': {
    'ru': 'Отложено на цели',
    'en': 'Set aside for goals',
  },
  'accountPartner': {
    'ru': 'Партнёр',
    'en': 'Partner',
  },
  'accountCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'accountSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'accountWhySo': {
    'ru': 'Почему так',
    'en': 'Why this way',
  },
  'accountMir': {
    'ru': 'МИР',
    'en': 'MIR',
  },
  // ── валюта и курсы ──
  'currencyTitle': {
    'ru': 'Валюта и курсы',
    'en': 'Currency and rates',
  },
  'currencyBase': {
    'ru': 'Базовая валюта',
    'en': 'Base currency',
  },
  'currencyBaseNote': {
    'ru': 'В базовой валюте считаются итоги, бюджеты и сводки. Курс — сколько '
        'базовой валюты стоит единица чужой.',
    'en': 'Totals, budgets and summaries are counted in the base currency. A '
        'rate is how much of it one unit of another currency costs.',
  },
  'currencyRates': {
    'ru': 'Курсы к %s',
    'en': 'Rates against %s',
  },
  'currencyNoOthers': {
    'ru': 'Других валют у вас пока нет. Появится счёт в долларах — здесь '
        'встанет поле для его курса.',
    'en': 'You have no other currencies yet. Add an account in dollars and a '
        'field for its rate appears here.',
  },
  'currencyRateMissing': {
    'ru': 'Курс не задан — считаем один к одному',
    'en': 'No rate set — counting one to one',
  },
  'currencyRefresh': {
    'ru': 'Обновить курсы',
    'en': 'Refresh the rates',
  },
  'currencyAsking': {
    'ru': 'Спрашиваем…',
    'en': 'Asking…',
  },
  'currencyUpdated': {
    'ru': 'Курсы обновлены',
    'en': 'Rates updated',
  },
  'currencySource': {
    'ru': 'Источник: %s',
    'en': 'Source: %s',
  },
  'currencyStale': {
    'ru': 'Источник молчит — взяли последние известные курсы',
    'en': 'The source is silent — we took the last known rates',
  },
  'currencyNoServer': {
    'ru': 'Сервер не дал курсов для ваших валют',
    'en': 'The server gave no rates for your currencies',
  },
  'currencyNeedAccount': {
    'ru': 'Курсы с сервера доступны после входа в аккаунт',
    'en': 'Rates from the server need you to sign in',
  },
  'currencyConverted': {
    'ru': '≈ %s по текущему курсу',
    'en': '≈ %s at the current rate',
  },
  // ── договорённости ──
  'agreementsTitle': {
    'ru': 'Договорённости',
    'en': 'Agreements',
  },
  'agreementsHow': {
    'ru': 'Лимит на категорию, правило дележа, взнос в общий кошелёк — всё это '
        'предлагается второму, а не ставится молча. Нажмите плюс, чтобы '
        'предложить первый лимит.',
    'en': 'A category limit, a split rule, a contribution to the shared '
        'wallet — each is proposed to the other person, not set silently. '
        'Press the plus to propose the first limit.',
  },
  'agreementPropose': {
    'ru': 'Предложить',
    'en': 'Propose',
  },
  'agreementProposeLimit': {
    'ru': 'Предложить лимит',
    'en': 'Propose a limit',
  },
  'agreementLimitField': {
    'ru': 'Лимит в месяц, %s',
    'en': 'Monthly limit, %s',
  },
  'agreementYouProposed': {
    'ru': 'Вы предложили',
    'en': 'You proposed',
  },
  'agreementWaiting': {
    'ru': 'Ждём ответа %s',
    'en': 'Waiting for %s',
  },
  'agreementProposes': {
    'ru': '%s предлагает',
    'en': '%s proposes',
  },
  'agreementAgree': {
    'ru': 'Согласен',
    'en': 'I agree',
  },
  'agreementNotNow': {
    'ru': 'Не сейчас',
    'en': 'Not now',
  },
  'agreementActive': {
    'ru': 'Действует',
    'en': 'In force',
  },
  'agreementsActive': {
    'ru': 'Действуют',
    'en': 'In force',
  },
  'agreementDeclined': {
    'ru': 'Отклонено',
    'en': 'Declined',
  },
  'agreementsDeclined': {
    'ru': 'Отклонены',
    'en': 'Declined',
  },
  'agreementExample': {
    'ru': 'Мы четвёртый месяц выходим за лимит',
    'en': 'We have been over the limit for four months',
  },
  'today': {
    'ru': 'сегодня',
    'en': 'today',
  },
  'yesterday': {
    'ru': 'вчера',
    'en': 'yesterday',
  },
  'operations.one': {
    'ru': 'операция',
    'en': 'operation',
  },
  'operations.few': {
    'ru': 'операции',
    'en': 'operations',
  },
  'operations.many': {
    'ru': 'операций',
    'en': 'operations',
  },
  'operations.other': {
    'ru': 'операций',
    'en': 'operations',
  },

  // Премиальные оформления карт: открываются подпиской.
  'designNight': {
    'ru': 'Ночь',
    'en': 'Night',
  },
  'designPine': {
    'ru': 'Хвоя',
    'en': 'Pine',
  },
  'designWine': {
    'ru': 'Вино',
    'en': 'Wine',
  },
  'designBrass': {
    'ru': 'Латунь',
    'en': 'Brass',
  },
  'designIce': {
    'ru': 'Лёд',
    'en': 'Ice',
  },
  'designLilac': {
    'ru': 'Сирень',
    'en': 'Lilac',
  },
  'accountLookPlus': {
    'ru': 'В Wallet+',
    'en': 'In Wallet+',
  },
};
