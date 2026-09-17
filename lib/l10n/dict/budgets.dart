// Бюджеты-конверты: лимит, перенос остатка, перерасход.
const Map<String, Map<String, String>> budgetStrings = {
  'rulesBigSpend': {
    'ru': 'Обсуждаем траты дороже, %s',
    'en': 'Talk about spending over, %s',
  },
  'rulesBigSpendNote': {
    'ru': 'С любого счёта, не только из общего кошелька',
    'en': 'From any account, not just the shared wallet',
  },

  'categorySideSpending': {
    'ru': 'Расходы',
    'en': 'Spending',
  },
  'categorySideIncome': {
    'ru': 'Доходы',
    'en': 'Income',
  },

  'periodCustom': {
    'ru': 'Свой',
    'en': 'Custom',
  },
  'periodOnce': {
    'ru': 'Без срока',
    'en': 'No limit',
  },
  'periodPerCustom': {
    'ru': 'за отрезок',
    'en': 'per stretch',
  },
  'periodPerOnce': {
    'ru': 'всего',
    'en': 'in total',
  },
  'periodLastCustom': {
    'ru': 'с прошлого отрезка ',
    'en': 'from the last stretch ',
  },
  'periodNextCustom': {
    'ru': 'следующий отрезок',
    'en': 'next stretch',
  },
  'budgetDays': {
    'ru': 'Длина отрезка',
    'en': 'Stretch length',
  },
  'budgetDaysValue': {
    'ru': '%s дней',
    'en': '%s days',
  },
  'budgetStart': {
    'ru': 'Считать с',
    'en': 'Count from',
  },
  'budgetOnceNote': {
    'ru': 'Предел на всё время, без обнуления',
    'en': 'A cap for all time, never reset',
  },

  'budgetPeriodTitle': {
    'ru': 'Период',
    'en': 'Period',
  },
  'budgetPickHint': {
    'ru': 'На что ставим предел',
    'en': 'What to cap',
  },

  'amountZero': {
    'ru': '0,00',
    'en': '0.00',
  },

  'categoryPickTitle': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'categoryPickSearch': {
    'ru': 'Поиск',
    'en': 'Search',
  },
  'categoryPickNothing': {
    'ru': 'Ничего не нашлось',
    'en': 'Nothing found',
  },
  'categoryPickNone': {
    'ru': 'Выбрать',
    'en': 'Choose',
  },

  'budgetDeclinedBy': {
    'ru': 'Ответ %s: «не сейчас»',
    'en': 'Reply from %s: “not now”',
  },
  'budgetProposeAgain': {
    'ru': 'Предложить снова',
    'en': 'Propose again',
  },
  'budgetDropProposal': {
    'ru': 'Убрать',
    'en': 'Dismiss',
  },
  'budgetCategoriesTitle': {
    'ru': 'Какие категории считать',
    'en': 'Which categories to count',
  },
  'budgetCategoriesDone': {
    'ru': 'Выбрано: %s',
    'en': 'Chosen: %s',
  },
  'budgetCategoriesMore': {
    'ru': 'И ещё %s',
    'en': 'And %s more',
  },
  'budgetCategoriesMoreTitle': {
    'ru': 'Ещё категории',
    'en': 'More categories',
  },
  'budgetCategoriesNone': {
    'ru': 'Только главная',
    'en': 'Main one only',
  },
  'budgetAccounts': {
    'ru': 'С каких счетов',
    'en': 'From which accounts',
  },
  'budgetAccountsNote': {
    'ru': 'Пусто — считаем по всем счетам.',
    'en': 'Empty means all accounts count.',
  },
  'budgetAllAccounts': {
    'ru': 'Все счета',
    'en': 'All accounts',
  },
  'budgetName': {
    'ru': 'Имя и вид',
    'en': 'Name and look',
  },
  'budgetNameHint': {
    'ru': 'Например, «Машина»',
    'en': 'For example, “Car”',
  },
  'budgetPropose': {
    'ru': 'Предложить бюджет',
    'en': 'Propose a budget',
  },
  'budgetProposeAction': {
    'ru': 'Предложить',
    'en': 'Propose',
  },
  'budgetWhySo': {
    'ru': 'Почему так',
    'en': 'Why this much',
  },
  'budgetWhySoHint': {
    'ru': 'Мы четвёртый месяц выходим за эту сумму',
    'en': 'We have been over this amount for four months',
  },
  'budgetWaiting': {
    'ru': 'Предложено, ждём ответа %s',
    'en': 'Proposed, waiting for %s',
  },
  'budgetsEmptyPair': {
    'ru': 'Бюджет в паре ставится вдвоём: вы предлагаете сумму, партнёр '
        'соглашается. Приложение будет говорить, сколько от неё осталось.',
    'en': 'In a couple a budget is set together: you propose the amount, your '
        'partner agrees. The app will tell you how much of it is left.',
  },
  'budgetsTitle': {
    'ru': 'Бюджеты',
    'en': 'Budgets',
  },
  'budgetOne': {
    'ru': 'Бюджет',
    'en': 'Budget',
  },
  'budgetNew': {
    'ru': 'Новый бюджет',
    'en': 'New budget',
  },
  'budgetsEmpty': {
    'ru': 'Ни одного бюджета',
    'en': 'No budgets yet',
  },
  'budgetsEmptyHow': {
    'ru': 'Поставьте лимит на категорию, и приложение будет говорить, '
        'сколько от него осталось.',
    'en': 'Set a limit on a category and the app will tell you how much of '
        'it is left.',
  },
  'budgetsNeedSpending': {
    'ru': 'Сначала запишите хотя бы один расход — бюджет ставится на '
        'категорию.',
    'en': 'Record at least one expense first — a budget is set on a category.',
  },
  'budgetRemoveTitle': {
    'ru': 'Убрать бюджет?',
    'en': 'Remove the budget?',
  },
  'budgetRemoveText': {
    'ru': 'Лимит на «%s» перестанет считаться. Операции останутся на месте.',
    'en': 'The limit on “%s” stops counting. The operations stay where they '
        'are.',
  },
  'budgetRemove': {
    'ru': 'Убрать',
    'en': 'Remove',
  },
  'budgetSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'budgetLimitField': {
    'ru': 'Лимит %s, %s',
    'en': 'Limit %s, %s',
  },
  'budgetCarry': {
    'ru': 'Переносить остаток',
    'en': 'Carry the remainder over',
  },
  'budgetCarryNote': {
    'ru': 'Остаток перейдёт на %s, перерасход вычтется',
    'en': 'The remainder carries to the next %s, an overspend is subtracted',
  },
  'budgetLeft': {
    'ru': 'Осталось %s',
    'en': '%s left',
  },
  'budgetOver': {
    'ru': 'Перерасход %s',
    'en': '%s over',
  },
  'budgetOfPeriod': {
    'ru': 'из %s %s',
    'en': 'of %s %s',
  },
  'budgetCarriedIn': {
    'ru': 'Перенесено с %s: ',
    'en': 'Carried over from %s: ',
  },
  'budgetCarriedOver': {
    'ru': 'Перерасход %s: ',
    'en': 'Overspend from %s: ',
  },
  // Русскому нужен падеж («с прошлой недели»), английскому — нет. Поэтому
  // отрезок подставляется целой фразой, а не окончанием.
  'periodLastDay': {
    'ru': 'прошлого дня',
    'en': 'the last day',
  },
  'periodLastWeek': {
    'ru': 'прошлой недели',
    'en': 'last week',
  },
  'periodLastMonth': {
    'ru': 'прошлого месяца',
    'en': 'last month',
  },
  'periodDay': {
    'ru': 'День',
    'en': 'Day',
  },
  'periodWeek': {
    'ru': 'Неделя',
    'en': 'Week',
  },
  'periodMonth': {
    'ru': 'Месяц',
    'en': 'Month',
  },
  'periodPerDay': {
    'ru': 'на день',
    'en': 'per day',
  },
  'periodPerWeek': {
    'ru': 'на неделю',
    'en': 'per week',
  },
  'periodPerMonth': {
    'ru': 'на месяц',
    'en': 'per month',
  },
  'periodNextDay': {
    'ru': 'следующий день',
    'en': 'day',
  },
  'periodNextWeek': {
    'ru': 'следующую неделю',
    'en': 'week',
  },
  'periodNextMonth': {
    'ru': 'следующий месяц',
    'en': 'month',
  },
};
