// План на месяц с нулевым балансом и регулярные записи.
//
// «Заплати себе первым» — pay yourself first, устойчивое правило, а не
// описание. Остальное переведено по смыслу: «Факт» это Actual, «Разложить по
// правилу» — Allocate by the rule.
const Map<String, Map<String, String>> planStrings = {
  'planRowNew': {
    'ru': 'Строка',
    'en': 'Row',
  },
  'planRowWhat': {
    'ru': 'Что добавить в план',
    'en': 'What to add to the plan',
  },
  'planRowRemove': {
    'ru': 'Убрать из плана',
    'en': 'Remove from the plan',
  },
  'planClear': {
    'ru': 'Очистить план',
    'en': 'Clear the plan',
  },
  'planClearText': {
    'ru': 'Плановые суммы этого месяца исчезнут. Записи и траты останутся на месте',
    'en': 'The planned amounts for this month will go. Records and spending stay',
  },

  'planTitle': {
    'ru': 'План на месяц',
    'en': 'Monthly plan',
  },
  'planMoreRows': {
    'ru': 'Ещё %s в плане',
    'en': 'Plan has %s more',
  },
  'planEmpty': {
    'ru': 'Плана на этот месяц ещё нет',
    'en': 'No plan for this month yet',
  },
  'planEmptyHow': {
    'ru': 'План — это ответ на вопрос «что делает каждый рубль». Разложите '
        'доход по правилу, а потом поправьте строки руками: приложение знает '
        'ваши прошлые траты, но не знает ваших планов.',
    'en': 'A plan answers one question: what does every unit of money do. '
        'Allocate the income by the rule, then fix the rows by hand — the app '
        'knows your past spending, not your plans.',
  },
  'planNeedIncome': {
    'ru': 'Нужен доход за этот или прошлый месяц — от него и делим',
    'en': 'Income for this or last month is needed — the split comes from it',
  },
  'planNoIncome': {
    'ru': 'Дохода за этот месяц ещё нет',
    'en': 'No income for this month yet',
  },
  'planAllocate': {
    'ru': 'Разложить',
    'en': 'Allocate',
  },
  'planAllocateByRule': {
    'ru': 'Разложить по правилу',
    'en': 'Allocate by the rule',
  },
  'planAllocateTitle': {
    'ru': 'Разложить по правилу?',
    'en': 'Allocate by the rule?',
  },
  'planAllocateText': {
    'ru': 'Доход разойдётся по долям %s и внутри каждой доли — по тому, на что '
        'вы правда тратили последние месяцы. Нынешний план этого месяца '
        'заменится: %s строк.',
    'en': 'The income goes by the shares %s, and inside each share by what you '
        'actually spent over the last months. The current plan for this month '
        'is replaced: %s rows.',
  },
  'planRule': {
    'ru': 'Правило %s',
    'en': 'Rule %s',
  },
  'planWhereIncomeGoes': {
    'ru': 'Куда уходит доход',
    'en': 'Where the income goes',
  },
  'planIncome': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'planPlanned': {
    'ru': 'В плане',
    'en': 'Planned',
  },
  'planPlannedField': {
    'ru': 'В плане, %s',
    'en': 'Planned, %s',
  },
  'planPlannedAmount': {
    'ru': 'В плане %s · ',
    'en': 'Planned %s · ',
  },
  'planPlannedInline': {
    'ru': '(в плане %s)',
    'en': '(planned %s)',
  },
  'planActual': {
    'ru': 'Факт',
    'en': 'Actual',
  },
  'planActualMonth': {
    'ru': 'Факт за месяц: %s',
    'en': 'Actual this month: %s',
  },
  'planZeroRemoves': {
    'ru': 'Ноль убирает строку из плана',
    'en': 'Zero removes the row from the plan',
  },
  'planAllDone': {
    'ru': 'Всё распределено',
    'en': 'Everything is allocated',
  },
  'planLeftToPlan': {
    'ru': 'Ещё не распределено',
    'en': 'Not allocated yet',
  },
  'planOverIncome': {
    'ru': 'Распределено больше, чем доход',
    'en': 'Allocated more than the income',
  },
  'planNotInPlan': {
    'ru': 'Не было в плане',
    'en': 'Not in the plan',
  },
  'planNotInPlanGood': {
    'ru': 'Не было в плане — но пошло на пользу',
    'en': 'Not in the plan — but it did good',
  },
  'planOverRow': {
    'ru': 'Сверх плана %s ',
    'en': '%s over the plan ',
  },
  'planMoreThanPlan': {
    'ru': 'Больше плана на %s ',
    'en': '%s more than planned ',
  },
  'planLeftRow': {
    'ru': 'осталось',
    'en': 'left',
  },
  'planLeftToAdd': {
    'ru': 'осталось внести',
    'en': 'left to add',
  },
  'planUnmarked': {
    'ru': 'Не размечено на %s — ',
    'en': '%s unmarked — ',
  },
  'planUnmarkedTail': {
    'ru': 'разметьте категории, иначе правило считается по догадкам',
    'en': 'mark the categories, otherwise the rule counts on guesses',
  },
  'planSavings': {
    'ru': 'Сбережения',
    'en': 'Savings',
  },
  'planSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'recurringTitle': {
    'ru': 'Регулярное',
    'en': 'Recurring',
  },
  'recurringNew': {
    'ru': 'Новая регулярная запись',
    'en': 'New recurring record',
  },
  'recurringOne': {
    'ru': 'Запись',
    'en': 'Record',
  },
  'recurringEmpty': {
    'ru': 'Ничего регулярного',
    'en': 'Nothing recurring',
  },
  'recurringEmptyHow': {
    'ru': 'Квартплата, подписки, зарплата — то, что повторяется каждый месяц. '
        'А взнос в цель, который срабатывает сам, — это правило «заплати '
        'себе первым»: откладывается сразу, а не из остатка.',
    'en': 'Rent, subscriptions, salary — whatever repeats every month. And a '
        'goal contribution that fires on its own is the “pay yourself first” '
        'rule: it is set aside right away, not out of what is left.',
  },
  'recurringName': {
    'ru': 'Название',
    'en': 'Name',
  },
  'recurringNameHint': {
    'ru': 'Квартплата',
    'en': 'Rent',
  },
  'recurringNeedName': {
    'ru': 'Напишите название',
    'en': 'Give it a name',
  },
  'recurringAmount': {
    'ru': 'Сумма, %s',
    'en': 'Amount, %s',
  },
  'recurringAmountPositive': {
    'ru': 'Сумма должна быть больше нуля',
    'en': 'The amount has to be above zero',
  },
  'recurringHowOften': {
    'ru': 'Как часто',
    'en': 'How often',
  },
  'recurringNextTime': {
    'ru': 'Следующий раз',
    'en': 'Next time',
  },
  'recurringNext': {
    'ru': 'Следующий раз: %s',
    'en': 'Next: %s',
  },
  'recurringDueOnOpen': {
    'ru': 'Сработает при следующем открытии: %s',
    'en': 'Fires the next time you open the app: %s',
  },
  'recurringWallet': {
    'ru': 'Кошелёк',
    'en': 'Wallet',
  },
  'recurringNeedWallet': {
    'ru': 'Сначала нужен кошелёк',
    'en': 'You need a wallet first',
  },
  'recurringCategory': {
    'ru': 'Категория',
    'en': 'Category',
  },
  'recurringWhat': {
    'ru': 'Что за запись',
    'en': 'What it is',
  },
  'recurringWhen': {
    'ru': 'Когда',
    'en': 'When',
  },
  'everyWeekly': {
    'ru': 'Каждую неделю',
    'en': 'Every week',
  },
  'everyMonthly': {
    'ru': 'Каждый месяц',
    'en': 'Every month',
  },
  'everyQuarterly': {
    'ru': 'Раз в квартал',
    'en': 'Every quarter',
  },
  'everyYearly': {
    'ru': 'Раз в год',
    'en': 'Every year',
  },
  'everyCustom': {
    'ru': 'Свой срок',
    'en': 'Custom',
  },
  'everyOnce': {
    'ru': 'Один раз',
    'en': 'Once',
  },
  'everyCustomDays': {
    'ru': 'Каждые %s дней',
    'en': 'Every %s days',
  },
  'recurringKindPayment': {
    'ru': 'Платёж',
    'en': 'Payment',
  },
  'recurringKindIncome': {
    'ru': 'Доход',
    'en': 'Income',
  },
  'recurringKindGoal': {
    'ru': 'В цель',
    'en': 'To a goal',
  },
  'recurringKindDebt': {
    'ru': 'По долгу',
    'en': 'On a debt',
  },
  'recurringWhichGoal': {
    'ru': 'В какую цель',
    'en': 'Which goal',
  },
  'recurringPickGoal': {
    'ru': 'Выберите цель, куда откладывать',
    'en': 'Pick the goal to put money into',
  },
  'recurringWhichDebt': {
    'ru': 'По какому долгу',
    'en': 'Which debt',
  },
  'recurringPickDebt': {
    'ru': 'Выберите долг, который гасить',
    'en': 'Pick the debt to pay off',
  },
  'recurringGoalNote': {
    'ru': 'Взнос уйдёт сразу, как придёт срок: это и есть «заплати себе '
        'первым».',
    'en': 'The contribution leaves as soon as it is due: that is “pay yourself '
        'first”.',
  },
  'recurringOn': {
    'ru': 'Включено',
    'en': 'On',
  },
  'recurringOff': {
    'ru': 'Выключено',
    'en': 'Off',
  },
  'recurringMonthly': {
    'ru': 'Обязательное в месяц',
    'en': 'Committed each month',
  },
  'recurringOutSummary': {
    'ru': 'Платежи %s · ',
    'en': 'Payments %s · ',
  },
  'recurringIntoSummary': {
    'ru': 'себе и по долгам %s',
    'en': 'to yourself and debts %s',
  },
  'recurringRemoveTitle': {
    'ru': 'Убрать «%s»?',
    'en': 'Remove “%s”?',
  },
  'recurringRemoveText': {
    'ru': 'Записи, которые уже созданы, останутся в истории.',
    'en': 'Records already created stay in history.',
  },
  'recurringRemove': {
    'ru': 'Убрать',
    'en': 'Remove',
  },
  'recurringSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
};
