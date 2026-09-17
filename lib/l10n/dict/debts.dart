// Долги: кредиты, карты, микрозаймы, порядок погашения.
//
// «Лавина» и «снежный ком» — это avalanche и snowball, устойчивые названия
// двух способов гасить долги. Переводить их описанием нельзя: человек,
// читавший про это, ищет именно эти слова.
const Map<String, Map<String, String>> debtStrings = {
  'debtWhat': {
    'ru': 'Что за долг',
    'en': 'What kind',
  },
  'debtTerms': {
    'ru': 'Условия',
    'en': 'Terms',
  },

  'debtsTitle': {
    'ru': 'Долги',
    'en': 'Debt',
  },
  'debtOne': {
    'ru': 'Долг',
    'en': 'Debt',
  },
  'debtNew': {
    'ru': 'Новый долг',
    'en': 'New debt',
  },
  'debtNamed': {
    'ru': 'Долг «%s»',
    'en': 'Debt “%s”',
  },
  'debtsEmpty': {
    'ru': 'Долгов нет',
    'en': 'No debt',
  },
  'debtsEmptyHow': {
    'ru': 'Если есть кредит, карта или микрозайм — заведите их здесь. '
        'Приложение посчитает, что гасить первым и сколько это займёт: '
        'порядок погашения экономит больше, чем экономия на продуктах.',
    'en': 'Got a loan, a credit card or a payday loan? Add them here. The app '
        'works out what to pay off first and how long it takes: the order of '
        'repayment saves more than cutting the grocery bill.',
  },
  'debtDueDayShort': {
    'ru': 'платёж %s-го',
    'en': 'payment on day %s',
  },
  'debtsPaidOff': {
    'ru': 'Всё выплачено',
    'en': 'All paid off',
  },
  'debtPaidOff': {
    'ru': 'Выплачен',
    'en': 'Paid off',
  },
  'debtsLeftTitle': {
    'ru': 'Осталось вернуть',
    'en': 'Left to repay',
  },
  'debtLeft': {
    'ru': 'Осталось %s',
    'en': '%s left',
  },
  'debtInterestMonth': {
    'ru': 'Проценты в месяц',
    'en': 'Interest per month',
  },
  'debtPaymentsMonth': {
    'ru': 'Платежей в месяц',
    'en': 'Payments per month',
  },
  'debtPaymentMonth': {
    'ru': 'Платёж в месяц',
    'en': 'Payment per month',
  },
  'debtRateYear': {
    'ru': '%s% годовых',
    'en': '%s% a year',
  },
  'debtTermAndInterest': {
    'ru': '%s · проценты %s в месяц',
    'en': '%s · interest %s per month',
  },
  'debtPayoffIn': {
    'ru': 'При %s в месяц закроется через ',
    'en': 'At %s per month it closes in ',
  },
  'debtNeverEnds': {
    'ru': 'Платёж %s не перекрывает проценты ',
    'en': 'A payment of %s does not cover the interest ',
  },
  'debtNeverEndsTail': {
    'ru': '(%s в месяц) — так долг не кончится',
    'en': '(%s per month) — the debt will never end this way',
  },
  'debtAvalanche': {
    'ru': 'Лавина',
    'en': 'Avalanche',
  },
  'debtAvalancheHow': {
    'ru': 'Сперва самая дорогая ставка: так меньше переплата.',
    'en': 'Highest rate first: you pay less on top.',
  },
  'debtSnowball': {
    'ru': 'Снежный ком',
    'en': 'Snowball',
  },
  'debtSnowballHow': {
    'ru': 'Сперва самый маленький остаток: первый закрытый долг придаёт '
        'разгон.',
    'en': 'Smallest balance first: the first debt you close gives you a push.',
  },
  'debtName': {
    'ru': 'Название',
    'en': 'Name',
  },
  'debtNameHint': {
    'ru': 'Кредитка Мaib',
    'en': 'Maib credit card',
  },
  'debtNeedName': {
    'ru': 'Напишите название долга',
    'en': 'Give the debt a name',
  },
  'debtExists': {
    'ru': 'Такой долг уже есть',
    'en': 'That debt already exists',
  },
  'debtTotal': {
    'ru': 'Сколько всего вернуть, %s',
    'en': 'How much to repay in total, %s',
  },
  'debtTotalAsk': {
    'ru': 'Сколько всего предстоит вернуть?',
    'en': 'How much is there to repay?',
  },
  'debtRateField': {
    'ru': 'Ставка, % годовых',
    'en': 'Rate, % a year',
  },
  'debtDueDay': {
    'ru': 'День платежа',
    'en': 'Payment day',
  },
  'debtDueDayNone': {
    'ru': 'Не задан',
    'en': 'Not set',
  },
  'debtDueDayOn': {
    'ru': '%s-го числа',
    'en': 'Day %s',
  },
  'debtPay': {
    'ru': 'Заплатить',
    'en': 'Pay',
  },
  'debtPayOn': {
    'ru': 'Платёж по «%s»',
    'en': 'Payment on “%s”',
  },
  'debtHowMuch': {
    'ru': 'Сколько, %s',
    'en': 'How much, %s',
  },
  'debtFromWallet': {
    'ru': 'С какого кошелька',
    'en': 'From which wallet',
  },
  'debtNeedWallet': {
    'ru': 'Сначала нужен кошелёк, с которого платить',
    'en': 'You need a wallet to pay from first',
  },
  'debtAmountPositive': {
    'ru': 'Сумма должна быть больше нуля',
    'en': 'The amount has to be above zero',
  },
  'debtRemoveTitle': {
    'ru': 'Убрать «%s»?',
    'en': 'Remove “%s”?',
  },
  'debtRemoveEmpty': {
    'ru': 'Запись о долге исчезнет.',
    'en': 'The debt record disappears.',
  },
  'debtRemovePaid': {
    'ru': 'Запись исчезнет, а платежи (%s) останутся в истории: деньги ушли, '
        'и стирать их нельзя.',
    'en': 'The record disappears, the payments (%s) stay in history: the money '
        'left, and erasing it would be a lie.',
  },
  'debtRemove': {
    'ru': 'Убрать',
    'en': 'Remove',
  },
  'debtSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
};
