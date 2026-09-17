// Листы подтверждения: роспуск пары, удаление аккаунта, выход, стирание.
//
// Слова решений живут отдельным разделом: их читают в момент, когда человек
// готов сделать необратимое, и перевод здесь важнее, чем где-либо.
const Map<String, Map<String, String>> sheetStrings = {
  'wheelToday': {
    'ru': 'Сегодня',
    'en': 'Today',
  },
  'wheelDone': {
    'ru': 'Готово',
    'en': 'Done',
  },
  'wheelWhen': {
    'ru': 'Когда это было',
    'en': 'When was it',
  },
  'wheelMonth': {
    'ru': 'Какой месяц',
    'en': 'Which month',
  },
  'cancel': {
    'ru': 'Отмена',
    'en': 'Cancel',
  },
  'signOutTitle': {
    'ru': 'Выйти из аккаунта?',
    'en': 'Sign out?',
  },
  'signOutText': {
    'ru': 'Записи останутся и на устройстве, и на сервере. Синхронизация '
        'остановится, пока вы не войдёте снова.',
    'en': 'Records stay both on the device and on the server. Syncing stops '
        'until you sign in again.',
  },
  'signOut': {
    'ru': 'Выйти',
    'en': 'Sign out',
  },
  'wipeTitle': {
    'ru': 'Стереть всё?',
    'en': 'Erase everything?',
  },
  'wipeText': {
    'ru': 'Счета, операции, бюджеты и цели исчезнут с этого устройства. '
        'Сохраните копию, если она может понадобиться.',
    'en': 'Accounts, operations, budgets and goals disappear from this device. '
        'Save a copy if you might need it.',
  },
  'wipe': {
    'ru': 'Стереть',
    'en': 'Erase',
  },
  'disbandTitle': {
    'ru': 'Распустить пару?',
    'en': 'Break up the pair?',
  },
  'disbandText': {
    'ru': 'Общий учёт с %s прекратится. Записи останутся у вас обоих, но с '
        'этой минуты каждый ведёт свои. Собраться снова можно новым кодом.',
    'en': 'Shared accounting with %s stops. The records stay with both of '
        'you, but from this minute each keeps their own. You can pair again '
        'with a new code.',
  },
  'disband': {
    'ru': 'Распустить',
    'en': 'Break up',
  },
  'disbandRow': {
    'ru': 'Распустить пару',
    'en': 'Break up the pair',
  },
  'disbandRowNote': {
    'ru': 'Каждый продолжит со своими записями',
    'en': 'Each of you continues with their own records',
  },
  'disbandDone': {
    'ru': 'Пара распущена',
    'en': 'The pair is broken up',
  },
  'deleteAccountTitle': {
    'ru': 'Удалить аккаунт?',
    'en': 'Delete the account?',
  },
  'deleteAccountRow': {
    'ru': 'Удалить аккаунт',
    'en': 'Delete account',
  },
  'deleteAccountRowNote': {
    'ru': 'Вместе с ним исчезнет и аккаунт Togetherly',
    'en': 'The Togetherly account goes with it',
  },
  'deleteAccountText': {
    'ru': 'Аккаунт общий с Togetherly: вместе с деньгами уходит и он — '
        'воспоминания, чат, виджеты. Передумаете — просто войдите снова в '
        'течение %s дней, и всё вернётся на место. После этого срока стирается '
        'насовсем.',
    'en': 'The account is shared with Togetherly: it goes along with the money '
        '— memories, chat, widgets. Change your mind and simply sign in again '
        'within %s days and everything comes back. After that it is erased '
        'for good.',
  },
  'deleteAccountPairNote': {
    'ru': 'Пара распустится, общие записи останутся у партнёра.',
    'en': 'The pair breaks up, shared records stay with your partner.',
  },
  'deleteAccountAction': {
    'ru': 'Удалить навсегда',
    'en': 'Delete forever',
  },
  'deleteAccountWord': {
    'ru': 'Удалить',
    'en': 'Delete',
  },
  'typeWord': {
    'ru': 'Введите слово «%s»',
    'en': 'Type the word “%s”',
  },
  'deleteFailed': {
    'ru': 'Не вышло удалить: %s',
    'en': 'Could not delete: %s',
  },
  'disbandFailed': {
    'ru': 'Не вышло: %s',
    'en': 'Did not work: %s',
  },
};
