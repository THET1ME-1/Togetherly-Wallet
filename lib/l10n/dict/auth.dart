// Вход и регистрация.
//
// Одна запись — все языки сразу: новый язык это колонка в словаре, а не ещё
// один класс на тысячу членов. Так же сделано в Togetherly.
//
// Русский и английский написаны, остальные пять языков пока пусты: `tr`
// откатывается на английский, поэтому выбранный немецкий даёт английский
// экран, а не пустые места.
const Map<String, Map<String, String>> authStrings = {
  'welcomeTitle': {
    'ru': 'Деньги вместе,',
    'en': 'Money together,',
  },
  'welcomeTitleSecond': {
    'ru': 'личное отдельно',
    'en': 'private stays private',
  },
  'welcomeStart': {
    'ru': 'Начать',
    'en': 'Get started',
  },
  'authNameLabel': {
    'ru': 'ИМЯ',
    'en': 'NAME',
  },
  'authEmailLabel': {
    'ru': 'ПОЧТА',
    'en': 'EMAIL',
  },
  'authPasswordLabel': {
    'ru': 'ПАРОЛЬ',
    'en': 'PASSWORD',
  },
  'authPasswordNote': {
    'ru': 'от 8 знаков',
    'en': '8 characters minimum',
  },
  'welcomeNoAccount': {
    'ru': 'Нет аккаунта?',
    'en': 'No account yet?',
  },
  'welcomeHaveAccount': {
    'ru': 'Уже есть аккаунт?',
    'en': 'Already have an account?',
  },
  'welcomeAccCard': {
    'ru': 'Карта',
    'en': 'Card',
  },
  'welcomeAccCash': {
    'ru': 'Наличные',
    'en': 'Cash',
  },
  'welcomeDemoSalary': {
    'ru': 'Зарплата',
    'en': 'Salary',
  },
  'welcomeDemoGroceries': {
    'ru': 'Продукты',
    'en': 'Groceries',
  },
  'welcomeDemoCoffee': {
    'ru': 'Кофе',
    'en': 'Coffee',
  },
  'welcomeCardShared': {
    'ru': 'Общий кошелёк',
    'en': 'Shared wallet',
  },
  'welcomeCardMine': {
    'ru': 'Моя карта',
    'en': 'My card',
  },

  'appTitle': {
    'ru': 'Togetherly Wallet',
    'en': 'Togetherly Wallet',
  },
  'authAbout': {
    'ru': 'Аккаунт тот же, что в других наших приложениях. Записи приедут на '
        'все устройства, пара подхватится сама.',
    'en': 'The same account as in our other apps. Your records reach every '
        'device, and your pair connects itself.',
  },
  'authAboutRegister': {
    'ru': 'Аккаунт нужен, чтобы записи пережили потерю телефона и приехали на '
        'второй.',
    'en': 'An account keeps your records safe if the phone is lost, and brings '
        'them to the second one.',
  },
  'authName': {
    'ru': 'Ваше имя',
    'en': 'Your name',
  },
  'authEmail': {
    'ru': 'ваша@почта.com',
    'en': 'your@email.com',
  },
  'authPassword': {
    'ru': 'Не меньше 8 знаков',
    'en': 'At least 8 characters',
  },
  'authShow': {
    'ru': 'Показать',
    'en': 'Show',
  },
  'authHide': {
    'ru': 'Скрыть',
    'en': 'Hide',
  },
  'authSignInTitle': {
    'ru': 'С возвращением',
    'en': 'Welcome back',
  },
  'authSignInNote': {
    'ru': 'Тот же аккаунт, что в других приложениях Togetherly.',
    'en': 'The same account as in other Togetherly apps.',
  },
  'authRegisterTitle': {
    'ru': 'Заводим аккаунт',
    'en': 'Create an account',
  },
  'authRegisterNote': {
    'ru': 'Записи переживут потерю телефона и приедут на второй.',
    'en': 'Your records survive a lost phone and reach the second one.',
  },
  'authSignIn': {
    'ru': 'Войти',
    'en': 'Sign in',
  },
  'authRegister': {
    'ru': 'Создать аккаунт',
    'en': 'Create account',
  },
  'authWait': {
    'ru': 'Секунду…',
    'en': 'One moment…',
  },
  'authHaveAccount': {
    'ru': 'У меня уже есть аккаунт',
    'en': 'I already have an account',
  },
  'authOr': {
    'ru': 'или',
    'en': 'or',
  },
  'authSkip': {
    'ru': 'Пока без аккаунта',
    'en': 'Without an account for now',
  },
  'authSkipNote': {
    'ru': 'Записи останутся на телефоне. Войти можно потом, всё перенесётся.',
    'en': 'Records stay on the phone. Sign in later and everything moves over.',
  },
  'authOneAccount': {
    'ru': 'Один аккаунт для всех приложений Togetherly',
    'en': 'One account for every Togetherly app',
  },
  'authFillBoth': {
    'ru': 'Заполните почту и пароль',
    'en': 'Fill in the email and the password',
  },
  'authProviderFailed': {
    'ru': 'Войти через %s не вышло. Попробуйте почтой и паролем.',
    'en': 'Signing in with %s did not work. Try email and password.',
  },
  'authNeedName': {
    'ru': 'Как вас зовут?',
    'en': 'What is your name?',
  },
};
