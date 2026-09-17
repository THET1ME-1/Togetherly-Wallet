// Цели и подушка безопасности.
//
// «Подушка» по-английски — emergency fund, а не «pillow»: это устойчивое имя,
// и человек, знающий финансовые приложения, ищет именно его.
const Map<String, Map<String, String>> goalStrings = {
  'goalsTitle': {
    'ru': 'Цели',
    'en': 'Goals',
  },
  'goalWhen': {
    'ru': 'Срок',
    'en': 'Deadline',
  },
  'goalNoDeadline': {
    'ru': 'Без срока',
    'en': 'No deadline',
  },
  'goalOne': {
    'ru': 'Цель',
    'en': 'Goal',
  },
  'goalNew': {
    'ru': 'Новая цель',
    'en': 'New goal',
  },
  'goalsEmpty': {
    'ru': 'Ни одной цели',
    'en': 'No goals yet',
  },
  'goalsEmptyHow': {
    'ru': 'Отпуск, кольцо, подушка на три месяца. Деньги в цель переводятся '
        'с кошелька и видны там же, а рядом — кто сколько внёс.',
    'en': 'A holiday, a ring, three months of expenses put aside. Money moves '
        'into a goal from a wallet and stays visible there, with who put in '
        'how much.',
  },
  'goalNamed': {
    'ru': 'Цель «%s»',
    'en': 'Goal “%s”',
  },
  'goalWhatFor': {
    'ru': 'На что копим',
    'en': 'What you are saving for',
  },
  'goalWhatForHint': {
    'ru': 'Отпуск в Греции',
    'en': 'A holiday in Greece',
  },
  'goalNeedName': {
    'ru': 'Напишите, на что копите',
    'en': 'Say what you are saving for',
  },
  'goalExists': {
    'ru': 'Такая цель уже есть',
    'en': 'That goal already exists',
  },
  'goalAmount': {
    'ru': 'Сколько нужно',
    'en': 'How much you need',
  },
  'goalAmountOptional': {
    'ru': 'Можно оставить пустым',
    'en': 'You can leave this empty',
  },
  'goalCurrency': {
    'ru': 'Валюта',
    'en': 'Currency',
  },
  'goalDeadline': {
    'ru': 'К какому дню',
    'en': 'By what date',
  },
  'goalDeadlineNone': {
    'ru': 'Срок не задан',
    'en': 'No deadline',
  },
  'goalDeadlineClear': {
    'ru': 'Убрать срок',
    'en': 'Clear the deadline',
  },
  'goalDeadlineBy': {
    'ru': 'К %s',
    'en': 'By %s',
  },
  'goalIsReserve': {
    'ru': 'Это подушка безопасности',
    'en': 'This is an emergency fund',
  },
  'goalReserveHow': {
    'ru': 'Сумма посчитается сама: столько месяцев ваших расходов',
    'en': 'The amount is worked out for you: that many months of your '
        'expenses',
  },
  'goalReserveMonths': {
    'ru': 'На сколько месяцев',
    'en': 'How many months',
  },
  'goalReserveByNow': {
    'ru': 'По нынешним расходам это %s ',
    'en': 'At your current spending that is %s ',
  },
  'goalReservePerMonth': {
    'ru': '(%s в месяц).',
    'en': '(%s per month).',
  },
  'goalReserveNoData': {
    'ru': 'Пока не из чего считать: нужен хотя бы один закрытый месяц с '
        'расходами. Сумма появится сама.',
    'en': 'Nothing to count from yet: one full month with expenses is enough. '
        'The amount will appear on its own.',
  },
  'goalReserveWait': {
    'ru': 'Подушка: сумма появится, когда будет хотя бы один закрытый '
        'месяц с расходами',
    'en': 'Emergency fund: the amount appears once there is a full month with '
        'expenses',
  },
  'goalReserveCovers': {
    'ru': 'Хватит на %s из %s',
    'en': 'Covers %s of %s',
  },
  'goalReserveDone': {
    'ru': '%s — собрано',
    'en': '%s — done',
  },
  'goalReserveLeft': {
    'ru': '%s · осталось %s',
    'en': '%s · %s to go',
  },
  'goalSaved': {
    'ru': 'Собрано',
    'en': 'Saved',
  },
  'goalSavedAmount': {
    'ru': 'Накоплено %s',
    'en': '%s saved',
  },
  'goalLeft': {
    'ru': 'Осталось %s',
    'en': '%s to go',
  },
  'goalOfTarget': {
    'ru': 'из %s',
    'en': 'of %s',
  },
  'goalNoTarget': {
    'ru': 'Копится без суммы — цель можно дописать',
    'en': 'Growing without a target — you can fill it in later',
  },
  'goalPerDay': {
    'ru': 'по %s в день',
    'en': '%s a day',
  },
  'goalDueToday': {
    'ru': 'срок сегодня',
    'en': 'due today',
  },
  'goalOverdue': {
    'ru': 'срок прошёл %s назад',
    'en': '%s overdue',
  },
  'goalDueIn': {
    'ru': '%s до срока',
    'en': '%s left',
  },
  'goalPut': {
    'ru': 'Вложить',
    'en': 'Add money',
  },
  'goalPutInto': {
    'ru': 'Вложить в «%s»',
    'en': 'Add money to “%s”',
  },
  'goalTake': {
    'ru': 'Снять',
    'en': 'Take out',
  },
  'goalTakeFrom': {
    'ru': 'Снять из «%s»',
    'en': 'Take out of “%s”',
  },
  'goalFromWallet': {
    'ru': 'С какого кошелька',
    'en': 'From which wallet',
  },
  'goalToWallet': {
    'ru': 'Куда вернуть',
    'en': 'Back to which wallet',
  },
  'goalNeedWallet': {
    'ru': 'Сначала нужен кошелёк, с которого копить',
    'en': 'You need a wallet to save from first',
  },
  'goalMoveNote': {
    'ru': 'Деньги уйдут с кошелька и будут видны в цели',
    'en': 'The money leaves the wallet and shows up in the goal',
  },
  'goalNotEnough': {
    'ru': 'В цели столько нет',
    'en': 'The goal does not hold that much',
  },
  'goalAmountPositive': {
    'ru': 'Сумма должна быть больше нуля',
    'en': 'The amount has to be above zero',
  },
  'goalHowMuch': {
    'ru': 'Сколько, %s',
    'en': 'How much, %s',
  },
  'goalRemoveTitle': {
    'ru': 'Убрать цель «%s»?',
    'en': 'Remove the goal “%s”?',
  },
  'goalRemoveEmpty': {
    'ru': 'Запись о цели исчезнет. Операции останутся на месте.',
    'en': 'The goal disappears. The operations stay where they are.',
  },
  'goalRemoveSaved': {
    'ru': 'Накопленное (%s) останется лежать на своём счёте — его можно '
        'снять обратно на кошелёк.',
    'en': 'What you saved (%s) stays on its own account — you can take it '
        'back to a wallet.',
  },
  'goalRemove': {
    'ru': 'Убрать',
    'en': 'Remove',
  },
  'goalSave': {
    'ru': 'Сохранить',
    'en': 'Save',
  },
  'days.one': {
    'ru': 'день',
    'en': 'day',
  },
  'days.few': {
    'ru': 'дня',
    'en': 'days',
  },
  'days.many': {
    'ru': 'дней',
    'en': 'days',
  },
  'days.other': {
    'ru': 'дней',
    'en': 'days',
  },
  'months.one': {
    'ru': 'месяц',
    'en': 'month',
  },
  'months.few': {
    'ru': 'месяца',
    'en': 'months',
  },
  'months.many': {
    'ru': 'месяцев',
    'en': 'months',
  },
  'months.other': {
    'ru': 'месяцев',
    'en': 'months',
  },
};
