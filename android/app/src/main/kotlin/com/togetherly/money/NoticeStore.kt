package com.togetherly.money

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Ящик уведомлений между службой и Dart.
 *
 * Путь данных ровно один — файл в личной папке приложения. Живой канал только
 * будит Dart словом «проснись»: два пути доставки означали бы две записи одной
 * траты при любой ошибке в дедупликации.
 */
object NoticeStore {

    /// Служба на связи. Разрешение можно дать и отозвать, не открывая нас.
    @Volatile
    var connected: Boolean = false

    private const val fileName = "notices.jsonl"

    /// Столько уведомлений держим, если приложение долго не открывали.
    private const val keep = 400

    /// Сколько уведомлений служба приняла за всё время — любых, не только
    /// банковских. Это единственный честный ответ на вопрос «служба вообще
    /// работает?»: журнал разбора считает только те, что прошли фильтры, и при
    /// нуле неотличим от выключенного доступа.
    private const val prefs = "notices"
    private const val seenKey = "seen"

    private val lock = Any()
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null

    /// Ключи уже принятых уведомлений. Служба подбирает шторку при каждом
    /// подключении, и без этого списка одна покупка ложилась бы в файл столько
    /// раз, сколько раз служба просыпалась.
    private const val idsName = "notice_ids.txt"
    private const val idsKeep = 500

    fun listen(value: EventChannel.EventSink?, context: Context) {
        sink = value
        // Служба могла подобрать шторку раньше, чем Dart начал слушать: будим
        // сразу, иначе накопленное пролежит до следующего возврата в приложение.
        if (value != null && pendingCount(context) > 0) {
            main.post { runCatching { value.success("new") } }
        }
    }

    /// Положить уведомление в ящик. `false` — такое уже лежало или было
    /// разобрано: тот же ключ и то же время публикации.
    fun add(context: Context, id: String, pkg: String, title: String, body: String, at: Long): Boolean {
        val line = JSONObject().apply {
            put("package", pkg)
            put("title", title)
            put("body", body)
            put("at", at)
        }.toString()

        synchronized(lock) {
            val ids = File(context.filesDir, idsName)
            val known = if (ids.exists()) ids.readLines() else emptyList()
            if (id in known) return false
            val next = (known + id).takeLast(idsKeep)
            ids.writeText(next.joinToString("\n", postfix = "\n"))

            val file = File(context.filesDir, fileName)
            file.appendText(line + "\n")
            // Файл растёт, пока приложение закрыто. Обрезаем редко и по счёту
            // строк, а не по байтам: половина строки — потерянная трата.
            if (file.length() > 256 * 1024) {
                val tail = file.readLines().takeLast(keep)
                file.writeText(tail.joinToString("\n", postfix = "\n"))
            }
        }

        runCatching {
            val box = context.getSharedPreferences(prefs, Context.MODE_PRIVATE)
            box.edit().putInt(seenKey, box.getInt(seenKey, 0) + 1).apply()
        }

        sink?.let { live -> main.post { runCatching { live.success("new") } } }
        return true
    }

    /// Забрать всё накопленное и очистить. Забираем целиком: разобрать
    /// половину и оставить остальное значит потерять порядок дней.
    fun drain(context: Context): List<Map<String, Any>> = synchronized(lock) {
        val file = File(context.filesDir, fileName)
        if (!file.exists()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        for (line in file.readLines()) {
            if (line.isBlank()) continue
            val json = runCatching { JSONObject(line) }.getOrNull() ?: continue
            out.add(
                mapOf(
                    "package" to json.optString("package"),
                    "title" to json.optString("title"),
                    "body" to json.optString("body"),
                    "at" to json.optLong("at"),
                )
            )
        }
        file.delete()
        return out
    }

    fun pendingCount(context: Context): Int = synchronized(lock) {
        val file = File(context.filesDir, fileName)
        if (!file.exists()) return 0
        return file.readLines().count { it.isNotBlank() }
    }

    fun seenCount(context: Context): Int = runCatching {
        context.getSharedPreferences(prefs, Context.MODE_PRIVATE).getInt(seenKey, 0)
    }.getOrDefault(0)

    @Suppress("unused")
    fun asJson(items: List<Map<String, Any>>): String {
        val array = JSONArray()
        for (item in items) array.put(JSONObject(item))
        return array.toString()
    }
}
