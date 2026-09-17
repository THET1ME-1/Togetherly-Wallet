package com.togetherly.money

import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.service.notification.NotificationListenerService
import java.io.ByteArrayOutputStream
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Мост к чтению уведомлений: разрешение, экран системных настроек, выдача
 * накопленного и список банков, которые реально стоят на телефоне.
 */
class NoticeBridge(private val context: Context, messenger: BinaryMessenger) {

    private val calls = MethodChannel(messenger, "togetherly.money/notices")
    private val events = EventChannel(messenger, "togetherly.money/notices/live")

    init {
        calls.setMethodCallHandler { call, result ->
            when (call.method) {
                "granted" -> result.success(granted(context))
                "state" -> result.success(
                    mapOf(
                        "granted" to granted(context),
                        "connected" to NoticeStore.connected,
                        "waiting" to NoticeStore.pendingCount(context),
                        "seen" to NoticeStore.seenCount(context),
                        "restricted" to restricted(context),
                    )
                )
                "rebind" -> {
                    revive(context) {}
                    result.success(null)
                }
                "appDetails" -> {
                    appDetails()
                    result.success(null)
                }
                "openSettings" -> {
                    openSettings()
                    result.success(null)
                }
                "drain" -> result.success(NoticeStore.drain(context))
                "waiting" -> result.success(NoticeStore.pendingCount(context))
                "installed" -> result.success(installed(call.arguments as? List<*>))
                "icons" -> result.success(icons(call.arguments as? List<*>))
                "appSettings" -> {
                    appSettings("${call.arguments}")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) =
                NoticeStore.listen(sink, context)

            override fun onCancel(arguments: Any?) = NoticeStore.listen(null, context)
        })
    }

    private fun openSettings() {
        val mine = ComponentName(context, NoticeListener::class.java)
        // С Android 11 система умеет открывать страницу именно нашей службы:
        // в общем списке из сорока приложений человек нас не находит.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val direct = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, mine.flattenToString())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (direct.resolveActivity(context.packageManager) != null) {
                context.startActivity(direct)
                return
            }
        }
        context.startActivity(
            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /// Настоящие логотипы банков: иконка приложения, которая уже стоит на
    /// телефоне. Ни рисовать похожее, ни возить чужие знаки в APK не нужно —
    /// и логотип всегда точный, включая свежий редизайн банка.
    private fun icons(wanted: List<*>?): Map<String, ByteArray> {
        if (wanted == null) return emptyMap()
        val pm = context.packageManager
        val out = HashMap<String, ByteArray>()
        for (pkg in wanted.filterIsInstance<String>()) {
            val drawable = runCatching { pm.getApplicationIcon(pkg) }.getOrNull()
            if (drawable == null) {
                // Приложение системе не видно: берём знак, снятый с самого
                // уведомления. Так логотип есть и у банка, которого нет в
                // нашем списке.
                val saved = java.io.File(java.io.File(context.filesDir, "sender_icons"), "$pkg.png")
                if (saved.exists()) out[pkg] = saved.readBytes()
                continue
            }
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(Canvas(bitmap))
            val bytes = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
            bitmap.recycle()
            out[pkg] = bytes.toByteArray()
        }
        return out
    }

    /// Настройки уведомлений самого банка. Когда банк молчит, причина обычно
    /// там: человек когда-то отключил его пуши, и приложению это не починить.
    private fun appSettings(pkg: String) {
        val direct = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, pkg)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (direct.resolveActivity(context.packageManager) != null) {
            context.startActivity(direct)
            return
        }
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", pkg, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /// Сведения о НАШЕМ приложении. Оттуда снимают запрет Android: меню с
    /// тремя точками сверху, «Разрешить ограниченные настройки».
    private fun appDetails() {
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", context.packageName, null))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    /// Из присланного списка оставляем те приложения, что стоят на телефоне.
    /// Видимость этих пакетов заявлена в манифесте — разрешения на список всех
    /// программ приложению не нужно.
    private fun installed(wanted: List<*>?): List<String> {
        if (wanted == null) return emptyList()
        val pm = context.packageManager
        return wanted.filterIsInstance<String>().filter { pkg ->
            runCatching { pm.getPackageInfo(pkg, 0) }.isSuccess
        }
    }

    companion object {
        /// Разрешение читают у системы, а не запоминают у себя: его отзывают в
        /// настройках, и запомненное «да» врало бы месяцами.
        ///
        /// Спрашиваем ТРЕМЯ способами и верим любому «да». Причина не в
        /// перестраховке: строку `enabled_notification_listeners` прошивки пишут
        /// по-разному — одни кладут «пакет/класс», другие один пакет, — и разбор
        /// через `unflattenFromString` на второй записи возвращает null. Человек
        /// тогда видит «Разрешение нужно один раз» при выданном разрешении и
        /// справедливо отвечает «всё включено, а не работает» (14.09.2026).
        fun granted(context: Context): Boolean {
            val mine = context.packageName

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                val nm = context.getSystemService(NotificationManager::class.java)
                val component = ComponentName(context, NoticeListener::class.java)
                val answer = runCatching {
                    nm?.isNotificationListenerAccessGranted(component)
                }.getOrNull()
                if (answer == true) return true
            }

            for (key in listOf("enabled_notification_listeners", "enabled_notification_assistant")) {
                val enabled = runCatching {
                    Settings.Secure.getString(context.contentResolver, key)
                }.getOrNull().orEmpty()
                if (enabled.isBlank()) continue
                for (item in enabled.split(':', ';')) {
                    val entry = item.trim()
                    if (entry.isEmpty()) continue
                    // «пакет/класс» разбираем как компонент, голый пакет сравниваем
                    // строкой: обе записи встречаются на живых прошивках.
                    val parsed = ComponentName.unflattenFromString(entry)
                    val pkg = parsed?.packageName ?: entry.substringBefore('/')
                    if (pkg == mine) return true
                }
            }
            // Служба на связи — значит разрешение выдано, что бы ни отвечали
            // настройки: система не поднимает listener без него.
            return NoticeStore.connected
        }

        /// Android запрещает выдать доступ, пока человек не подтвердит это в
        /// сведениях о приложении.
        ///
        /// С Android 13 приложению, поставленному мимо магазина, систему
        /// уведомлений включить нельзя: переключатель в настройках серый, и
        /// человек справедливо думает, что сломано приложение. Снимается
        /// запрет один раз, в меню сведений о приложении.
        ///
        /// Спрашиваем у самой системы, а не гадаем по способу установки:
        /// разрешение операции `access_restricted_settings` и есть ответ.
        fun restricted(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return false
            // Доступ уже выдан — запрет ничего не держит, и говорить о нём
            // значило бы пугать зря.
            if (granted(context)) return false
            val ops = context.getSystemService(AppOpsManager::class.java) ?: return false
            val mode = runCatching {
                ops.unsafeCheckOpNoThrow(
                    "android:access_restricted_settings",
                    Process.myUid(),
                    context.packageName,
                )
            }.getOrNull() ?: return false
            return mode != AppOpsManager.MODE_ALLOWED
        }

        /// Поднять службу, не трогая настройки Android.
        ///
        /// После обновления приложения система рвёт связь и сама её не
        /// восстанавливает: разрешение на месте, уведомления не читаются. Это
        /// лечится ровно одним вызовом, и человеку не нужно знать слово «rebind».
        fun rebind(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
            runCatching {
                NotificationListenerService.requestRebind(
                    ComponentName(context, NoticeListener::class.java)
                )
            }
        }

        /// Разбудить службу, если доступ есть, а связи нет. Зовётся на каждом
        /// возврате в приложение: прошивки с жёстким энергосбережением убивают
        /// процесс вместе со службой, и сама она не оживает, пока человек не
        /// откроет экран уведомлений (15.09.2026).
        fun wakeIfAsleep(context: Context) {
            if (NoticeStore.connected) return
            revive(context) {}
        }

        private val main = Handler(Looper.getMainLooper())

        /// Сколько ждать ответа системы на просьбу о связи.
        private const val settleMs = 3000L

        @Volatile
        private var reviving = false

        /// Вернуть связь со службой в две ступени.
        ///
        /// Сперва `requestRebind`. Если через несколько секунд службы всё ещё
        /// нет, выключаем и тут же включаем её компонент в `PackageManager`:
        /// система видит `PACKAGE_CHANGED` и заново перебирает слушателей, а
        /// на этот путь прошивки не ставят фильтров. Доступ при этом не
        /// слетает: одобрение хранится именем компонента и снимается только
        /// удалением пакета. `DONT_KILL_APP` — чтобы открытое приложение не
        /// закрылось у человека на глазах.
        ///
        /// `done` зовётся ровно один раз: приёмник обязан закончить работу.
        fun revive(context: Context, done: () -> Unit) {
            if (NoticeStore.connected || reviving || !granted(context)) {
                done()
                return
            }
            reviving = true
            rebind(context)
            main.postDelayed({
                if (!NoticeStore.connected) {
                    toggle(context)
                    rebind(context)
                }
                main.postDelayed({
                    reviving = false
                    done()
                }, settleMs)
            }, settleMs)
        }

        private fun toggle(context: Context) {
            val pm = context.packageManager
            val component = ComponentName(context, NoticeListener::class.java)
            runCatching {
                pm.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP,
                )
                pm.setComponentEnabledSetting(
                    component,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }
}
