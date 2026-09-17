// Свои правила разбора списаний: экран, форма и описания правил словами.
//
// Правило человек узнаёт ВЗГЛЯДОМ, не открывая: в списке стоит условие
// («Wolt · по будням») и действие («Записать молча»). Поэтому слов здесь
// больше, чем кнопок, — они и есть интерфейс этого экрана.
const Map<String, Map<String, String>> ruleStrings = {
  'nruleTitle': {
    'ru': 'Правила разбора',
    'en': 'Parsing rules',
  },
  'nruleSection': {
    'ru': 'Правила',
    'en': 'Rules',
  },
  'nruleOrder': {
    'ru': 'Сверху вниз: первое подошедшее и сработает',
    'en': 'Top down: the first match wins',
  },
  'nruleEmptyTitle': {
    'ru': 'Правил пока нет',
    'en': 'No rules yet',
  },
  'nruleEmptyText': {
    'ru': 'Приложение и так запоминает, какую категорию вы ставите магазину. '
        'Правило умеет больше: различать суммы и дни, записывать молча и '
        'пропускать то, что вам не нужно — банковскую комиссию, например.',
    'en': 'The app already remembers the category you give a merchant. A rule '
        'does more: it tells amounts and weekdays apart, records silently and '
        'skips what you do not need — a bank fee, say.',
  },
  'nruleNew': {
    'ru': 'Правило',
    'en': 'Rule',
  },
  'nruleEditTitle': {
    'ru': 'Правило',
    'en': 'Rule',
  },
  'nruleSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'nruleRemove': {
    'ru': 'Удалить правило',
    'en': 'Remove the rule',
  },
  'nruleNeedWhen': {
    'ru': 'Скажите, к чему правило применять: магазин, сумма, день или карта',
    'en': 'Say what the rule applies to: merchant, amount, weekday or card',
  },
  'nruleOff': {
    'ru': 'Выключено',
    'en': 'Off',
  },

  // Условие.
  'nruleWhen': {
    'ru': 'Когда',
    'en': 'When',
  },
  'nruleMerchant': {
    'ru': 'Магазин',
    'en': 'Merchant',
  },
  'nruleMerchantHint': {
    'ru': 'Часть названия: «tucano» поймает «SC TUCANO SRL»',
    'en': 'Part of the name: “tucano” catches “SC TUCANO SRL”',
  },
  'nruleAmount': {
    'ru': 'Сумма',
    'en': 'Amount',
  },
  'nruleMin': {
    'ru': 'От',
    'en': 'From',
  },
  'nruleMax': {
    'ru': 'До',
    'en': 'To',
  },
  'nruleSide': {
    'ru': 'Приход или расход',
    'en': 'Money in or out',
  },
  'nruleSideAny': {
    'ru': 'Любое',
    'en': 'Either',
  },
  'nruleDays': {
    'ru': 'Дни недели',
    'en': 'Weekdays',
  },
  'nruleCard': {
    'ru': 'Карта',
    'en': 'Card',
  },
  'nruleCardHint': {
    'ru': 'Последние четыре цифры',
    'en': 'The last four digits',
  },

  // Что делать.
  'nruleDo': {
    'ru': 'Что делать',
    'en': 'What to do',
  },
  'nruleDoRecord': {
    'ru': 'Записать молча',
    'en': 'Record silently',
  },
  'nruleDoAsk': {
    'ru': 'Спросить',
    'en': 'Ask me',
  },
  'nruleDoSkip': {
    'ru': 'Не записывать',
    'en': 'Skip it',
  },
  'nruleDoRecordNote': {
    'ru': 'Трата ляжет в ленту сама, без подтверждения',
    'en': 'The charge lands in the feed on its own',
  },
  'nruleDoAskNote': {
    'ru': 'Трата встанет в «Новые списания» с готовыми полями',
    'en': 'The charge waits in “New charges” with the fields filled in',
  },
  'nruleDoSkipNote': {
    'ru': 'Для комиссий и переводов между своими счетами',
    'en': 'For fees and transfers between your own accounts',
  },

  // Чем заполнить.
  'nruleFill': {
    'ru': 'Чем заполнить',
    'en': 'What to fill in',
  },
  'nruleCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'nruleAccount': {
    'ru': 'Счёт',
    'en': 'Account',
  },
  'nruleSplit': {
    'ru': 'Делёж',
    'en': 'Split',
  },
  'nruleNote': {
    'ru': 'Заметка',
    'en': 'Note',
  },
  'nruleKeep': {
    'ru': 'Как разобралось',
    'en': 'As parsed',
  },

  // Описание правила словами.
  'nruleAny': {
    'ru': 'Любое списание',
    'en': 'Any charge',
  },
  'nruleFrom': {
    'ru': 'больше',
    'en': 'over',
  },
  'nruleTo': {
    'ru': 'меньше',
    'en': 'under',
  },
  'nruleCardShort': {
    'ru': 'карта',
    'en': 'card',
  },
  'nruleIncomeShort': {
    'ru': 'приход',
    'en': 'money in',
  },
  'nruleExpenseShort': {
    'ru': 'расход',
    'en': 'money out',
  },

  // Сколько правил заведено. Числительное, а не «правил: 3»: у русского три
  // формы, и «1 правил» на экране читается поломкой.
  'nrules.one': {
    'ru': 'правило',
    'en': 'rule',
  },
  'nrules.few': {
    'ru': 'правила',
    'en': 'rules',
  },
  'nrules.many': {
    'ru': 'правил',
    'en': 'rules',
  },
  'nrules.other': {
    'ru': 'правил',
    'en': 'rules',
  },
};
