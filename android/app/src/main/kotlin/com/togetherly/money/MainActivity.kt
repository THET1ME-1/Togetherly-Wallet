package com.togetherly.money

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onResume() {
        super.onResume()
        // Служба чтения уведомлений могла умереть вместе с процессом, пока
        // приложение лежало закрытым. Проснувшись, она подберёт шторку.
        NoticeBridge.wakeIfAsleep(applicationContext)
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        NoticeBridge(applicationContext, engine.dartExecutor.binaryMessenger)
        // Вибрация своим мотором: системные щелчки Flutter часть прошивок
        // глушит вместе с виброоткликом касаний.
        HapticsBridge(applicationContext, engine.dartExecutor.binaryMessenger)

        // Пуши: Dart спрашивает только две вещи — дойдут ли они сюда вообще и
        // какой у телефона токен. Всё остальное (запись токена на сервер,
        // решение о запасном пути) решается в Dart, где это можно проверить
        // тестами.
        MethodChannel(engine.dartExecutor.binaryMessenger, "money/fcm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Сервисов Google нет на кастомных прошивках; там пушей не
                    // будет вовсе, и работает запасной путь через живой канал.
                    "hasServices" -> {
                        val code = GoogleApiAvailability.getInstance()
                            .isGooglePlayServicesAvailable(this)
                        result.success(code == ConnectionResult.SUCCESS)
                    }

                    "getToken" -> {
                        try {
                            FirebaseMessaging.getInstance().token
                                .addOnCompleteListener { task ->
                                    // Об ошибке молчим: телефон без сервисов
                                    // Google приходит сюда же, а пуши там не
                                    // работают в принципе.
                                    result.success(
                                        if (task.isSuccessful) task.result else null
                                    )
                                }
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
