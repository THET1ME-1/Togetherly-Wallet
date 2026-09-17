package com.togetherly.money

import android.content.Context
import android.os.Build
import android.os.CombinedVibration
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Вибрация своим мотором, а не системным «щелчком».
 *
 * Почему не хватило `HapticFeedback` из Flutter: он просит систему сыграть
 * `CLOCK_TICK` и `VIRTUAL_KEY`, а прошивки — Xiaomi в первую очередь —
 * глушат эти константы, когда в настройках приглушён виброотклик касаний.
 * Человек в итоге не чувствует НИЧЕГО и справедливо говорит, что вибраций
 * нет (17.09.2026).
 *
 * Здесь мы играем эффект сами. На Android 10+ берутся системные предустановки
 * (`EFFECT_TICK`, `EFFECT_CLICK`, `EFFECT_HEAVY_CLICK`) — они звучат «как
 * телефон», а не как дешёвая дрожь. Ниже — одиночный импульс с амплитудой,
 * и совсем на старых — просто длительность.
 */
class HapticsBridge(private val context: Context, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "money/haptics")

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as? VibratorManager
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "buzz" -> result.success(buzz(call.argument<String>("kind") ?: "pick"))
                // Экран замка спрашивает заранее: есть ли чем отвечать пальцу.
                "available" -> result.success(vibrator?.hasVibrator() == true)
                else -> result.notImplemented()
            }
        }
    }

    private fun buzz(kind: String): Boolean {
        val motor = vibrator ?: return false
        if (!motor.hasVibrator()) return false

        return try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                    val effect = VibrationEffect.createPredefined(
                        when (kind) {
                            "done" -> VibrationEffect.EFFECT_CLICK
                            "warn" -> VibrationEffect.EFFECT_HEAVY_CLICK
                            "cheer" -> VibrationEffect.EFFECT_DOUBLE_CLICK
                            else -> VibrationEffect.EFFECT_TICK
                        }
                    )
                    play(motor, effect)
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                    // Амплитуда, а не только длительность: короткая дрожь на
                    // полную силу читается как ошибка, даже когда всё хорошо.
                    val (ms, amp) = when (kind) {
                        "done" -> 18L to 130
                        "warn" -> 32L to 200
                        "cheer" -> 46L to 255
                        else -> 10L to 90
                    }
                    play(motor, VibrationEffect.createOneShot(ms, amp))
                }
                else -> {
                    @Suppress("DEPRECATION")
                    motor.vibrate(
                        when (kind) {
                            "done" -> 18L
                            "warn" -> 32L
                            "cheer" -> 46L
                            else -> 10L
                        }
                    )
                }
            }
            true
        } catch (e: Exception) {
            // Прошивки бывают разные: отказ мотора не должен ронять экран.
            false
        }
    }

    private fun play(motor: Vibrator, effect: VibrationEffect) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as? VibratorManager
            if (manager != null) {
                manager.vibrate(CombinedVibration.createParallel(effect))
                return
            }
        }
        motor.vibrate(effect)
    }
}
