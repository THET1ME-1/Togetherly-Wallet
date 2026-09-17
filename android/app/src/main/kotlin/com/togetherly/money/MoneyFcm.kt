package com.togetherly.money

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Приём пушей FCM.
 *
 * Служба почти ничего не делает: баннер рисует система, потому что в пуше едет
 * `notification`. Сюда попадает либо тихий пуш, либо обычный, когда приложение
 * на переднем плане — тогда показывать нечего, человек и так внутри.
 *
 * Содержимое пуша нейтральное: «есть новая запись», без суммы и категории.
 * Деньги на экране блокировки и в журналах Google не место, а детали
 * приложение забирает само своей синхронизацией.
 *
 * Плагин `firebase_messaging` НЕ подключён намеренно — так же, как в
 * Togetherly: на iOS он перехватывает делегата APNs, а здесь нужен только
 * токен на Android. Токен уезжает на сервер из Dart: там есть сессия.
 */
class MoneyFcm : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // Писать некуда: сессия живёт в Dart, и на следующем запуске
        // `getToken` отдаст этот же токен, который тут же уедет на сервер.
        Log.i(TAG, "новый токен FCM (длина ${token.length})")
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (message.notification != null) return
        Log.i(TAG, "тихий пуш: ${message.data["kind"] ?: "без вида"}")
    }

    companion object {
        private const val TAG = "MoneyFcm"
    }
}
