package com.togetherly.money

import android.app.Notification
import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import java.io.File

/**
 * Чтение банковских уведомлений.
 *
 * Служба живёт отдельно от приложения: система поднимает её сама, даже когда
 * Flutter не запущен. Поэтому она НИЧЕГО не разбирает и не решает — только
 * складывает пуш в файл, а разбор делает Dart, когда откроется. Логика в одном
 * месте, и её видно тестами.
 *
 * Текст уведомления не уезжает с устройства ни при каком режиме: сервер про
 * него не знает.
 */
class NoticeListener : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        NoticeStore.connected = true
        sweep()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        NoticeStore.connected = false
        // После обновления приложения система рвёт связь и сама её не вернёт:
        // человек видит разрешение включённым, а уведомления не читаются.
        requestRebind(ComponentName(this, NoticeListener::class.java))
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        capture(sbn)
    }

    /// Подобрать то, что уже висит в шторке.
    ///
    /// Пока служба спала, система пуши ей не отдавала, и `onNotificationPosted`
    /// о них не узнает никогда. Прошивки с жёстким энергосбережением убивают
    /// процесс вместе со службой, и оживает она только при открытии
    /// приложения — а покупка к тому времени уже прошла: «LINELLA 81 ·
    /// 59,55 MDL» висело в шторке, а в приложении его не было (15.09.2026).
    /// Повтор уже записанного отсекает `NoticeStore` по ключу уведомления.
    private fun sweep() {
        val shown = runCatching { activeNotifications }.getOrNull() ?: return
        for (sbn in shown) runCatching { capture(sbn) }
    }

    private fun capture(sbn: StatusBarNotification) {
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return

        val n: Notification = sbn.notification ?: return
        // Сводка группы повторяет то, что уже пришло строками, а «постоянное»
        // уведомление — это плеер и навигатор, там денег нет.
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return

        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val big = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        // Банк часто кладёт короткую строку в текст, а полную — в развёрнутый
        // вид: сумма и магазин бывают только во второй.
        val body = if (big.length > text.length) big else text
        if (title.isBlank() && body.isBlank()) return

        val id = "${sbn.key}|${sbn.postTime}"
        if (!NoticeStore.add(this, id, pkg, title, body, sbn.postTime)) return
        saveIcon(pkg, n)
    }

    /// Знак банка из САМОГО уведомления.
    ///
    /// Иконку установленного приложения приложение берёт у системы, но видеть
    /// чужие пакеты можно только те, что заявлены в манифесте. Банков в мире
    /// больше, чем список: у уведомления есть свой значок, и для незнакомого
    /// банка он становится знаком в списке источников. Пишем один раз.
    private fun saveIcon(pkg: String, n: Notification) {
        val dir = File(filesDir, "sender_icons")
        val file = File(dir, "$pkg.png")
        if (file.exists()) return

        val drawable: Drawable = runCatching {
            n.smallIcon?.loadDrawable(this)
        }.getOrNull() ?: return

        runCatching {
            dir.mkdirs()
            val size = 96
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(Canvas(bitmap))
            file.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            bitmap.recycle()
        }
    }
}
