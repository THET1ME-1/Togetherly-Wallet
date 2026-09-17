package com.togetherly.money

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Возвращает службу чтения уведомлений после обновления и перезагрузки.
 *
 * Установка поверх убивает процесс, и Android рвёт связь со службой: доступ
 * выдан, галочка стоит, а пуши не читаются, пока человек не откроет
 * приложение. Покупки за это время проходят мимо. Система сама шлёт нашему
 * пакету `MY_PACKAGE_REPLACED` сразу после установки — на нём и поднимаем
 * службу, не дожидаясь человека. `BOOT_COMPLETED` — то же после перезагрузки:
 * прошивки с жёстким энергосбережением не всегда поднимают службу сами.
 *
 * Оба действия защищены системой: чужое приложение их прислать не может,
 * поэтому приёмник открыт без риска.
 */
class NoticeKeeper : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_BOOT_COMPLETED -> {
                // Проверка связи ждёт несколько секунд: без goAsync система
                // считает приёмник отработавшим и может убить процесс раньше.
                val pending = goAsync()
                NoticeBridge.revive(context.applicationContext) { pending.finish() }
            }
        }
    }
}
