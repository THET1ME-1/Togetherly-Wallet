// Лента операций: отбор, разрез по людям, слово дележа, скрытая трата.
const Map<String, Map<String, String>> ledgerStrings = {
  'ledgerEmpty': {
    'ru': 'За этот отрезок операций нет',
    'en': 'No operations in this period',
  },
  'ledgerFilterEmpty': {
    'ru': 'Под этот отбор ничего не подошло',
    'en': 'Nothing matches this filter',
  },
  'ledgerSearch': {
    'ru': 'Искать по заметке, счёту, категории',
    'en': 'Search by note, account or category',
  },
  'ledgerClearFilter': {
    'ru': 'Снять отбор · %s',
    'en': 'Clear filter · %s',
  },
  'peopleAll': {
    'ru': 'Все',
    'en': 'Everyone',
  },
  'peopleMine': {
    'ru': 'Мои',
    'en': 'Mine',
  },
  'noCategory': {
    'ru': 'Без категории',
    'en': 'No category',
  },
  'transfer': {
    'ru': 'Перевод',
    'en': 'Transfer',
  },
  'surprise': {
    'ru': 'Сюрприз',
    'en': 'Surprise',
  },
  'splitEqual': {
    'ru': 'Поровну',
    'en': 'Split evenly',
  },
  'splitIncome': {
    'ru': 'По доходу',
    'en': 'By income',
  },
  'splitShares': {
    'ru': 'По долям',
    'en': 'By shares',
  },
  'splitPayer': {
    'ru': 'Только себе',
    'en': 'Payer only',
  },
  'hiddenDetails': {
    'ru': '%s · детали скрыты',
    'en': '%s · details hidden',
  },
  'opensOn': {
    'ru': '%s · откроется %s',
    'en': '%s · opens on %s',
  },
  'opensLater': {
    'ru': '%s · откроется позже',
    'en': '%s · opens later',
  },

  // Выбор пачкой: удержание в ленте включает режим, короткое касание берёт
  // запись. Человек просил это прямо: «нет множественного выбора при
  // удержании транзакции и действиях с ними» (17.09.2026).
  'bulkChosen': {
    'ru': 'Выбрано: %s',
    'en': 'Selected: %s',
  },
  'bulkCancel': {
    'ru': 'Снять выбор',
    'en': 'Clear the selection',
  },
  'bulkAll': {
    'ru': 'Выбрать всё на экране',
    'en': 'Select everything on screen',
  },
  'bulkActions': {
    'ru': 'Что сделать',
    'en': 'What to do',
  },
  'bulkDelete': {
    'ru': 'Удалить',
    'en': 'Delete',
  },
  'bulkDeleteTitle': {
    'ru': 'Удалить записи: %s',
    'en': 'Delete records: %s',
  },
  'bulkDeleteText': {
    'ru': 'Вернуть всё разом можно кнопкой «Отменить» — она держится пять '
        'секунд.',
    'en': 'You can bring them all back with “Undo” — it stays for five '
        'seconds.',
  },
  'bulkCategory': {
    'ru': 'Сменить категорию',
    'en': 'Change the category',
  },
  'bulkCategoryNote': {
    'ru': 'У всех выбранных разом',
    'en': 'For every selected record',
  },
  'bulkAccount': {
    'ru': 'Перенести на счёт',
    'en': 'Move to an account',
  },
  'bulkAccountNote': {
    'ru': 'Суммы и категории останутся прежними',
    'en': 'Amounts and categories stay as they are',
  },
};
