import Flutter
import UIKit
import UserNotifications

/// Пуши на iPhone идут через APNs напрямую, без Firebase.
///
/// Плагин `firebase_messaging` в проект не подключён намеренно — то же
/// решение, что в Togetherly: на iOS он перехватывает делегата APNs
/// подменой методов, и разобраться, кто съел уведомление, становится нечем.
/// Здесь приложение само просит разрешение, само регистрируется и отдаёт
/// токен в Dart каналом `money/push`, а отправляет уже сервер — тем же
/// релеем, что у Togetherly (ключ Apple выдан на команду, тема передаётся
/// в запросе).
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "money/push"

  /// Токен устройства в том виде, в каком его ждёт APNs: шестнадцатеричной
  /// строкой без пробелов и скобок.
  private var deviceToken: String?

  /// Кто ждёт токен. Регистрация асинхронная: Dart спрашивает сразу при
  /// запуске, а Apple отвечает через доли секунды — и до ответа ждущему
  /// отдавать нечего.
  private var waiting: [FlutterResult] = []

  /// Канал держим, чтобы протолкнуть токен, когда он приедет после ответа:
  /// человек может думать над разрешением минуту, а пуши нужны с первого дня.
  private var channel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Баннер показываем и когда приложение открыто: запись партнёра приходит
    // тогда же, когда человек смотрит в свои деньги, и молчать в этот момент
    // странно.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Мессенджер берётся у регистратора плагина — как в Togetherly: прямого
    // `applicationBinaryMessenger` у моста движка нет.
    guard let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "WalletPush")?
      .messenger()
    else { return }

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(nil) }
      switch call.method {
      case "register":
        self.register(result: result)
      case "sandbox":
        // Отладочная сборка получает токен ПЕСОЧНИЦЫ, и слать его в боевой
        // APNs бесполезно: Apple отвечает BadDeviceToken. Сервер разводит их
        // по пометке устройства.
        #if DEBUG
          result(true)
        #else
          result(false)
        #endif
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Спросить разрешение и зарегистрироваться. Отдаёт токен или nil.
  private func register(result: @escaping FlutterResult) {
    if let token = deviceToken {
      result(token)
      return
    }
    waiting.append(result)

    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .sound, .badge]
    ) { [weak self] granted, _ in
      guard let self else { return }
      guard granted else {
        // Отказ — не ошибка: приложение работает, просто молча.
        DispatchQueue.main.async { self.answer(nil) }
        return
      }
      DispatchQueue.main.async {
        UIApplication.shared.registerForRemoteNotifications()
      }
    }

    // Apple не обещает ответить: без сети регистрация висит, и ждущий Dart
    // остался бы висеть вместе с ней.
    DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
      self?.answer(self?.deviceToken)
    }
  }

  private func answer(_ token: String?) {
    let pending = waiting
    waiting = []
    for result in pending {
      result(token)
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken token: Data
  ) {
    let hex = token.map { String(format: "%02x", $0) }.joined()
    deviceToken = hex
    answer(hex)
    channel?.invokeMethod("token", arguments: hex)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("пуши: регистрация не удалась — %@", error.localizedDescription)
    answer(nil)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // `.banner` появился в iOS 14, а минимум у нас 13: на более старых
    // система понимает только `.alert`.
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }
}
