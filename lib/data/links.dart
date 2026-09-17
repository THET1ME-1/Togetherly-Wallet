/// Ссылки наружу — одним списком.
///
/// Раньше адрес поддержки стоял прямо в экране настроек, и туда уехал
/// `support.togetherly.day` — приёмная, куда пускают только разработчика.
/// Человек упирался в страницу входа вместо ответа.
library;

/// Почта поддержки. Отвечает человек, читается с телефона.
///
/// Тема письма подставляется заранее: без неё половина писем приходит с пустым
/// заголовком, и приёмная не понимает, о каком приложении речь.
const String kSupportMail =
    'mailto:support@togetherly.day?subject=Togetherly%20Money';

/// Бот жалоб в Telegram — тот же, что у Togetherly.
const String kBugBot = 'https://t.me/TogetherlyBugsBot';

/// Канал с новостями.
const String kTgChannel = 'https://t.me/sandtcompany';

/// Ролики про приложения.
const String kTikTok = 'https://www.tiktok.com/@sandt.company';

/// Как обходимся с данными.
///
/// У Wallet СВОЯ политика: `togetherly.day/privacy-policy/` написана про
/// Togetherly, где речь о воспоминаниях, фото и геолокации, а здесь деньги,
/// уведомления банка и модель. Прежний адрес `togetherly.day/privacy` отдавал
/// 404 вовсе (16.09.2026).
const String kPrivacy = 'https://togetherly.day/wallet-privacy/';

/// Страница про общий аккаунт экосистемы — на неё ведёт подпись на входе.
const String kEcosystem = 'https://togetherly.day/#download';
