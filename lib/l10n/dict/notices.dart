// Уведомления банков и правка категорий.
//
// Здесь легко сделать перевод «для галочки», а текст объясняет разрешение,
// которое человек даёт системе. По-английски он так же прямой: сказано, что
// текст уведомления остаётся на телефоне.
const Map<String, Map<String, String>> noticeStrings = {
  'noticesAndroidOnlyLong': {
    'ru': 'Читать уведомления умеет Android. На iPhone доступа к ним нет ни '
        'у одного приложения — там траты записываются руками или '
        'регулярными платежами.',
    'en': 'Only Android can read notifications. On iPhone no app has access '
        'to them — spending goes in by hand or through recurring records.',
  },
  'noticesPermissionHowLong': {
    'ru': 'Android спросит, можно ли приложению видеть уведомления. Разбор '
        'идёт на телефоне: сумму, карту и магазин приложение достаёт само, '
        'а текст уведомления никуда не отправляет.',
    'en': 'Android asks whether the app may see notifications. Parsing '
        'happens on the phone: the app pulls out the amount, the card and '
        'the shop itself, and the notification text goes nowhere.',
  },
  'noticesNoBanksLong': {
    'ru': 'Банковских приложений на телефоне не нашлось. Источник появится '
        'здесь сам, как только придёт первое уведомление, — или найдите '
        'банк поиском ниже.',
    'en': 'No banking apps found on the phone. A source appears here on its '
        'own with the first notification — or find the bank by the search '
        'below.',
  },
  'noticesRememberedHowX': {
    'ru': 'Приложение помнит ваш выбор и больше не спрашивает. Забыть — '
        'крестиком.',
    'en': 'The app keeps your choice and stops asking. Tap the cross to '
        'forget it.',
  },
  'noticesBothNoteShort': {
    'ru': 'Читаем и банк, и кошелёк. Одну покупку дважды приложение не '
        'запишет: сверяет сумму, день и счёт.',
    'en': 'We read both the bank and the wallet. The app will not record one '
        'purchase twice: it checks the amount, the day and the account.',
  },
  'noticesSourcesHowShort': {
    'ru': 'Читаются все, кто здесь включён. Банка нет в списке? Он появится '
        'сам после первого уведомления.',
    'en': 'Everyone switched on here is read. Bank missing? It appears on its '
        'own after the first notification.',
  },
  'noticesMonthCount': {
    'ru': '%s за месяц',
    'en': '%s this month',
  },
  'anyCard': {
    'ru': 'Любая карта',
    'en': 'Any card',
  },
  'categoryWordPlaceholder': {
    'ru': 'категория',
    'en': 'category',
  },
  'noticesMore': {
    'ru': 'Ещё',
    'en': 'More',
  },
  'noticesTitle': {
    'ru': 'Уведомления банков',
    'en': 'Bank notifications',
  },
  'noticesAndroidOnlyBadge': {
    'ru': 'Только на Android',
    'en': 'Android only',
  },
  'noticesAndroidOnlyText': {
    'ru': 'Читать уведомления умеет Android. На iPhone доступа к ним нет ни '
        'у одного приложения.',
    'en': 'Only Android can read notifications. On iPhone no app has access '
        'to them at all.',
  },
  'noticesGotIt': {
    'ru': 'Понятно',
    'en': 'Got it',
  },
  'noticesServiceAsleep': {
    'ru': 'Разрешение есть, служба спит',
    'en': 'Permission granted, service asleep',
  },
  'noticesServiceAsleepWhy': {
    'ru': 'После установки поверх Android рвёт связь со службой и сам её не '
        'возвращает: галочка стоит, а уведомления не читаются. Одно нажатие '
        'поднимает её обратно.',
    'en': 'After installing over the old build Android drops the listener and '
        'never restores it: the switch stays on while nothing is read. One '
        'tap brings it back.',
  },
  'noticesWakeService': {
    'ru': 'Поднять службу',
    'en': 'Restart the listener',
  },
  'noticesNothingArrives': {
    'ru': 'Ни одного уведомления не дошло',
    'en': 'No notification has arrived',
  },
  'noticesNothingArrivesWhy': {
    'ru': 'Разрешение выдано и служба на связи, но до приложения не дошло ни '
        'одного уведомления — ни банковского, ни любого другого. Так делает '
        'энергосбережение прошивки: снимите ограничения с приложения в '
        'настройках Android.',
    'en': 'The permission is granted and the listener is connected, yet not a '
        'single notification has reached the app — from a bank or anything '
        'else. That is the phone saving battery: remove the restrictions in '
        'Android settings.',
  },
  'noticesSwitchesIdle': {
    'ru': 'Пока доступ не выдан, эти переключатели ничего не делают.',
    'en': 'Until access is granted these switches do nothing.',
  },
  'noticesPermissionOnce': {
    'ru': 'Разрешение нужно один раз',
    'en': 'The permission is asked once',
  },
  'noticesPermissionHow': {
    'ru': 'Android спросит, можно ли приложению видеть уведомления. Разбор '
        'идёт на телефоне, а текст уведомления никуда не отправляет.',
    'en': 'Android asks whether the app may see notifications. Parsing '
        'happens on the phone, and the notification text goes nowhere.',
  },
  'noticesRestricted': {
    'ru': 'Android не даёт включить',
    'en': 'Android blocks the switch',
  },
  'noticesRestrictedWhy': {
    'ru': 'Приложение поставлено не из магазина, и до вашего подтверждения '
        'Android держит доступ к уведомлениям закрытым: переключатель будет '
        'серым. Снимается это один раз.',
    'en': 'The app was installed outside the store, so until you confirm it '
        'Android keeps notification access closed: the switch stays greyed '
        'out. You lift this once.',
  },
  'noticesRestrictedSteps': {
    'ru': '1. Откройте сведения о приложении.\n'
        '2. Найдите «Разрешить ограниченные настройки». Прошивки прячут этот '
        'пункт по-разному: у одних он в меню с тремя точками сверху, у '
        'других (Xiaomi) — в самом низу страницы.\n'
        '3. Вернитесь сюда и выдайте доступ к уведомлениям.',
    'en': '1. Open the app info.\n'
        '2. Find “Allow restricted settings”. Phones hide it differently: '
        'some keep it in the three-dot menu at the top, others (Xiaomi) at '
        'the very bottom of the page.\n'
        '3. Come back here and grant notification access.',
  },
  'noticesOpenAppInfo': {
    'ru': 'Открыть сведения о приложении',
    'en': 'Open app info',
  },
  'noticesOpenAndroid': {
    'ru': 'Открыть настройки Android',
    'en': 'Open Android settings',
  },
  'noticesAccessGranted': {
    'ru': 'Доступ Android выдан',
    'en': 'Android access granted',
  },
  'noticesWorks': {
    'ru': 'Работает',
    'en': 'Working',
  },
  'noticesNotReading': {
    'ru': 'Не читаем',
    'en': 'Not reading',
  },
  'noticesNobodyYet': {
    'ru': 'Пока никого',
    'en': 'Nobody yet',
  },
  'noticesNowhere': {
    'ru': 'Сейчас уведомления не читаются ниоткуда.',
    'en': 'Right now notifications are not read from anywhere.',
  },
  'noticesWhoSends': {
    'ru': 'Кто присылает',
    'en': 'Who sends them',
  },
  'noticesSourcesHow': {
    'ru': 'Читаются все, кто здесь включён. Банка нет в списке? Он появится '
        'после первого уведомления или найдите банк поиском ниже.',
    'en': 'Everyone switched on here is read. Bank missing? It shows up after '
        'its first notification, or find it by the search below.',
  },
  'noticesFind': {
    'ru': 'Найти банк или кошелёк',
    'en': 'Find a bank or a wallet',
  },
  'noticesBanksWallets': {
    'ru': 'Банки и кошельки',
    'en': 'Banks and wallets',
  },
  'noticesNoBanks': {
    'ru': 'Банковских приложений на телефоне не нашлось. Источник появится '
        'после первого уведомления.',
    'en': 'No banking apps found on the phone. A source shows up after its '
        'first notification.',
  },
  'noticesTurnOnAhead': {
    'ru': 'Включить заранее или выключить лишний',
    'en': 'Switch one on ahead of time, or switch off an extra one',
  },
  'noticesBank': {
    'ru': 'Банк',
    'en': 'Bank',
  },
  'noticesWallet': {
    'ru': 'Кошелёк',
    'en': 'Wallet',
  },
  'noticesBoth': {
    'ru': 'Оба',
    'en': 'Both',
  },
  'noticesBankNote': {
    'ru': 'Траты берутся из банковских уведомлений: там есть валюта счёта и '
        'остаток.',
    'en': 'Spending comes from bank notifications: they carry the account '
        'currency and the balance.',
  },
  'noticesWalletNote': {
    'ru': 'Траты берутся из кошелька. Годится, когда банк уведомления не '
        'присылает.',
    'en': 'Spending comes from the wallet. Good when the bank sends no '
        'notifications.',
  },
  'noticesBothNote': {
    'ru': 'Читаем и банк, и кошелёк. Одну покупку дважды приложение не '
        'запишет: та же сумма в тот же день на том же счёте отбивается.',
    'en': 'We read both the bank and the wallet. The app will not record one '
        'purchase twice: the same amount on the same day and account is '
        'turned away.',
  },
  'noticesPhonePayments': {
    'ru': 'Платежи телефоном',
    'en': 'Phone payments',
  },
  'noticesSameCharge': {
    'ru': 'То же списание, что у банка',
    'en': 'The same charge as the bank sends',
  },
  'noticesOnPhone': {
    'ru': 'На телефоне',
    'en': 'On the phone',
  },
  'noticesSilentMonth': {
    'ru': 'Месяц тишины — проверьте Android →',
    'en': 'A silent month — check Android →',
  },
  'noticesToday': {
    'ru': 'Сегодня',
    'en': 'Today',
  },
  'noticesYesterday': {
    'ru': 'Вчера',
    'en': 'Yesterday',
  },
  'noticesDaysAgo': {
    'ru': '%s %s назад',
    'en': '%s %s ago',
  },
  'noticesPerMonth': {
    'ru': '%s за месяц',
    'en': '%s this month',
  },
  'noticesReview': {
    'ru': 'Разбор списаний',
    'en': 'Charges to check',
  },
  'noticesWaitingFor': {
    'ru': '%s %s подтверждения',
    'en': '%s %s waiting for you',
  },
  'wait.one': {
    'ru': 'ждёт',
    'en': 'charge is',
  },
  'wait.few': {
    'ru': 'ждут',
    'en': 'charges are',
  },
  'wait.many': {
    'ru': 'ждут',
    'en': 'charges are',
  },
  'wait.other': {
    'ru': 'ждут',
    'en': 'charges are',
  },
  'noticesRemembered': {
    'ru': 'Приложение запомнило',
    'en': 'The app remembered',
  },
  'noticesRememberedHow': {
    'ru': 'Приложение помнит ваш выбор и больше не спрашивает. Забыть — '
        'нажать на строку.',
    'en': 'The app keeps your choice and stops asking. Tap a row to forget '
        'it.',
  },
  'noticesLearnedNothing': {
    'ru': 'Пока ничему не научилось.',
    'en': 'It has not learned anything yet.',
  },
  'noticesAskOnce': {
    'ru': 'Счёт спросим один раз',
    'en': 'We ask about the account once',
  },
  'noticesCards': {
    'ru': ' · карт: %s',
    'en': ' · cards: %s',
  },
  'noticesUsedIn': {
    'ru': 'В %s %s',
    'en': 'In %s %s',
  },
  'noticesModeAsk': {
    'ru': 'Спросить',
    'en': 'Ask',
  },
  'noticesModeAuto': {
    'ru': 'Сразу',
    'en': 'Right away',
  },
  'noticesTextStays': {
    'ru': 'Текст уведомления остаётся на телефоне. На сервер уезжает готовая '
        'операция.',
    'en': 'The notification text stays on the phone. Only the finished '
        'operation goes to the server.',
  },
  'categoriesEditTitle': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'categoriesEditEmpty': {
    'ru': 'Категории заводятся сами, когда записываете операцию. Здесь их '
        'можно переименовать и раскрасить.',
    'en': 'Categories appear on their own as you record operations. Here you '
        'can rename them and give them colours.',
  },
  'categoryNew': {
    'ru': 'Новая категория',
    'en': 'New category',
  },
  'subcategoryNew': {
    'ru': 'Новая подкатегория',
    'en': 'New subcategory',
  },
  'subcategoryOne': {
    'ru': 'Подкатегория',
    'en': 'Subcategory',
  },
  'subcategoryMore': {
    'ru': 'Ещё',
    'en': 'More',
  },
  'categoryName': {
    'ru': 'Название',
    'en': 'Name',
  },
  'categoryColor': {
    'ru': 'Цвет',
    'en': 'Colour',
  },
  'categoryIcon': {
    'ru': 'Значок',
    'en': 'Icon',
  },
  'categoryBucket': {
    'ru': 'Куда отнести трату',
    'en': 'Where this spending belongs',
  },
  'categoryBucketWhy': {
    'ru': 'Правило пары делит доход на три части. Здесь вы говорите, из какой '
        'части берутся эти деньги — и тогда приложение видит, укладываетесь '
        'вы в договорённость или нет.',
    'en': 'Your rule splits income three ways. Here you say which part this '
        'money comes from, and the app can tell whether you are keeping to '
        'what you agreed.',
  },
  'bucketNeedWhy': {
    'ru': 'Без этого не прожить',
    'en': 'You cannot go without it',
  },
  'bucketWantWhy': {
    'ru': 'Приятно, но можно отложить',
    'en': 'Nice to have, can wait',
  },
  'bucketSavingWhy': {
    'ru': 'Откладываю себе',
    'en': 'Money you set aside',
  },
  'categoryKind': {
    'ru': 'Это трата или поступление',
    'en': 'Spending or income',
  },
  'categoryKindWhy': {
    'ru': 'От этого зависит, в каком списке категория покажется при записи.',
    'en': 'This decides which list the category shows up in when you record.',
  },
  'categoryKindExpense': {
    'ru': 'Расход',
    'en': 'Spending',
  },
  'categoryKindIncome': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'categoryNameHint': {
    'ru': 'Например, Продукты',
    'en': 'For example, Groceries',
  },
  'categoryIconFind': {
    'ru': 'Найти значок',
    'en': 'Find an icon',
  },
  'categoryIconSearch': {
    'ru': 'Значок',
    'en': 'Icon',
  },
  'categoryIconHint': {
    'ru': 'Еда, дом, машина…',
    'en': 'Food, home, car…',
  },
  'categoryIconNothing': {
    'ru': 'По этому слову ничего нет. Попробуйте короче: «еда», «дом», «карта».',
    'en': 'Nothing matches. Try something shorter: “food”, “home”, “card”.',
  },
  'categoryIconAll': {
    'ru': 'Все значки набора — %s штук',
    'en': 'All %s icons of the set',
  },
  'categoryBucketGuess': {
    'ru': 'Пока подсказано по названию: %s',
    'en': 'Guessed from the name for now: %s',
  },
  'bucketNeed': {
    'ru': 'Нужда',
    'en': 'Need',
  },
  'bucketWant': {
    'ru': 'Желание',
    'en': 'Want',
  },
  'bucketSaving': {
    'ru': 'Сбережение',
    'en': 'Savings',
  },
  'bucketUnmarked': {
    'ru': 'Не размечено',
    'en': 'Unmarked',
  },
  'categoryAccounts': {
    'ru': 'На каких счетах',
    'en': 'On which accounts',
  },
  'categoryAccountsAll': {
    'ru': 'Показывается на всех счетах',
    'en': 'Shown on every account',
  },
  'categoryAccountsSome': {
    'ru': 'Показывается только на выбранных — у рекламного кабинета нет '
        'продуктов, а у карты нет рекламных поступлений',
    'en': 'Shown only on the chosen ones — an ad account has no groceries, '
        'and a card has no ad payouts',
  },
  'categoryAccountsEvery': {
    'ru': 'Все',
    'en': 'All',
  },
  'categoryRemove': {
    'ru': 'Убрать',
    'en': 'Remove',
  },
  'categorySave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'noOperations': {
    'ru': 'Без операций',
    'en': 'No operations',
  },
  'bankName': {
    'ru': 'Название банка',
    'en': 'Bank name',
  },
  'useWord.one': {
    'ru': 'операции',
    'en': 'operation',
  },
  'useWord.few': {
    'ru': 'операциях',
    'en': 'operations',
  },
  'useWord.many': {
    'ru': 'операциях',
    'en': 'operations',
  },
  'useWord.other': {
    'ru': 'операциях',
    'en': 'operations',
  },
};
