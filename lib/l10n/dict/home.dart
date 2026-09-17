// Главный экран: баланс, поток, категории, счета, цели, бюджеты, план, долги.
//
// Английский написан не подстрочником, а так, как это называют в финансовых
// приложениях: «Cash flow», «Settle up», «Left to repay». Дословный перевод
// русской фразы читается как машинный.
const Map<String, Map<String, String>> homeStrings = {
  'moneyDateTitle': {
    'ru': 'Разговор о деньгах',
    'en': 'Money date',
  },
  'moneyDateNone': {
    'ru': 'Не назначен — выберите день',
    'en': 'Not set — pick a day',
  },
  'moneyDatePassed': {
    'ru': 'День прошёл, назначьте новый',
    'en': 'The day has passed, pick a new one',
  },

  'soonTitle': {
    'ru': 'Скоро спишется',
    'en': 'Due soon',
  },
  'soonLate': {
    'ru': 'Просрочено',
    'en': 'Overdue',
  },
  'soonMore': {
    'ru': 'И ещё %s',
    'en': 'And %s more',
  },
  'subsTitle': {
    'ru': 'Похоже на подписки: %s',
    'en': 'Looks like subscriptions: %s',
  },

  'settleAskTitle': {
    'ru': 'Рассчитались?',
    'en': 'All settled?',
  },
  'settleAskText': {
    'ru': 'Долг на %s закроется. Остатки счетов не изменятся: деньги вы передали сами — наличными или переводом, о котором приложение не знает. Запись увидит %s',
    'en': 'The %s debt will be cleared. Account balances stay as they are: you handed the money over yourselves, in cash or by a transfer this app knows nothing about. %s will see the record',
  },

  'totalBalance': {
    'ru': 'Общий баланс',
    'en': 'Total balance',
  },
  'cashFlow': {
    'ru': 'Денежный поток',
    'en': 'Cash flow',
  },
  'income': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'spending': {
    'ru': 'Расход',
    'en': 'Spending',
  },
  'spendings': {
    'ru': 'Расходы',
    'en': 'Spending',
  },
  'net': {
    'ru': 'Итого',
    'en': 'Net',
  },
  'inGoals': {
    'ru': 'Отложено на цели',
    'en': 'Set aside for goals',
  },
  'goalsOutsideBalance': {
    'ru': 'Не входит в общий баланс',
    'en': 'Not counted in the total balance',
  },
  'settleTitle': {
    'ru': 'Сальдо',
    'en': 'Who owes whom',
  },
  'settleUp': {
    'ru': 'Выровнять',
    'en': 'Settle up',
  },
  'accounts': {
    'ru': 'Счета',
    'en': 'Accounts',
  },
  'allAccounts': {
    'ru': 'Все счета',
    'en': 'All accounts',
  },
  'whichAccounts': {
    'ru': 'Какие счета считать',
    'en': 'Which accounts to count',
  },
  'noAccounts': {
    'ru': 'Ни одного счёта',
    'en': 'No accounts yet',
  },
  'accountsChosen': {
    'ru': 'счетов: %s',
    'en': 'accounts: %s',
  },
  'goals': {
    'ru': 'Цели',
    'en': 'Goals',
  },
  'noGoals': {
    'ru': 'Ни одной цели',
    'en': 'No goals yet',
  },
  'budgets': {
    'ru': 'Бюджеты',
    'en': 'Budgets',
  },
  'noBudgets': {
    'ru': 'Нет активных бюджетов',
    'en': 'No active budgets',
  },
  'monthPlan': {
    'ru': 'План на месяц',
    'en': 'Monthly plan',
  },
  'noPlan': {
    'ru': 'Плана пока нет',
    'en': 'No plan yet',
  },
  'planAllocated': {
    'ru': 'Всё распределено',
    'en': 'Everything is allocated',
  },
  'planLeft': {
    'ru': 'Не распределено',
    'en': 'Unallocated',
  },
  'planOver': {
    'ru': 'Сверх дохода',
    'en': 'Over income',
  },
  'bucketNeeds': {
    'ru': 'Нужды',
    'en': 'Needs',
  },
  'bucketWants': {
    'ru': 'Желания',
    'en': 'Wants',
  },
  'bucketSavings': {
    'ru': 'Сбережения и долги',
    'en': 'Savings and debt',
  },
  'debts': {
    'ru': 'Долги',
    'en': 'Debt',
  },
  'debtsPaid': {
    'ru': 'Всё выплачено',
    'en': 'All paid off',
  },
  'debtsLeft': {
    'ru': 'Осталось вернуть',
    'en': 'Left to repay',
  },
  'debtsFirst': {
    'ru': 'Первым гасить «%s»',
    'en': 'Pay off “%s” first',
  },
  'debtsInterest': {
    'ru': 'Проценты по всем долгам %s ',
    'en': 'Interest on all debt %s ',
  },
  'perMonth': {
    'ru': 'в месяц',
    'en': 'per month',
  },
  'categories': {
    'ru': 'Категории',
    'en': 'Categories',
  },
  'chat': {
    'ru': 'Чат',
    'en': 'Chat',
  },
  'settings': {
    'ru': 'Настройки',
    'en': 'Settings',
  },
  'open': {
    'ru': 'Открыть',
    'en': 'Open',
  },
  'done': {
    'ru': 'Готово',
    'en': 'Done',
  },
  'localOnly': {
    'ru': 'Данные лежат на устройстве',
    'en': 'Data stays on this device',
  },
  'noticesHint': {
    'ru': 'Банк прислал, приложение разобрало. Проверьте и запишите.',
    'en': 'The bank sent it, the app read it. Check and save.',
  },
  'notices.one': {
    'ru': 'новое списание',
    'en': 'new charge',
  },
  'notices.few': {
    'ru': 'новых списания',
    'en': 'new charges',
  },
  'notices.many': {
    'ru': 'новых списаний',
    'en': 'new charges',
  },
  'notices.other': {
    'ru': 'новых списаний',
    'en': 'new charges',
  },
  'quartersHint': {
    'ru': 'Касание карточки меняет расход на доход',
    'en': 'Tap the card to switch between spending and income',
  },
  'noSpendingHere': {
    'ru': 'Расходов за отрезок нет',
    'en': 'No spending in this period',
  },
  'noIncomeHere': {
    'ru': 'Доходов за отрезок нет',
    'en': 'No income in this period',
  },
  'reviewDue': {
    'ru': 'Пора свериться с планом',
    'en': 'Time to review the plan',
  },
  'reviewMonthly': {
    'ru': 'Вы договорились смотреть бюджет раз в месяц',
    'en': 'You agreed to review the budget once a month',
  },
  'reviewEveryMonths': {
    'ru': 'Вы договорились смотреть бюджет раз в %s месяца',
    'en': 'You agreed to review the budget every %s months',
  },
  'andMore': {
    'ru': 'И ещё %s',
    'en': '%s more',
  },
  'ofAmount': {
    'ru': 'из %s',
    'en': 'of %s',
  },
  'monthsShort': {
    'ru': '%s из %s мес.',
    'en': '%s of %s mo',
  },

  // Прогноз конца месяца: сколько останется такими темпами и чего не хватит.
  'forecastTitle': {
    'ru': 'Останется к концу месяца',
    'en': 'Left by the end of the month',
  },
  'forecastShortTitle': {
    'ru': 'К концу месяца не хватит',
    'en': 'Short by the end of the month',
  },
  'forecastAtPace': {
    'ru': 'Такими темпами, %s в день',
    'en': 'At this pace, %s a day',
  },
  'forecastDueOn': {
    'ru': '%s %s-го — %s',
    'en': '%s on the %s — %s',
  },
  'forecastDrying': {
    'ru': '«%s» кончатся %s-го',
    'en': '“%s” runs out on the %s',
  },
};
