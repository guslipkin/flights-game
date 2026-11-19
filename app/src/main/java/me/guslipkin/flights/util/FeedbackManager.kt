package me.guslipkin.flights.util

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import me.guslipkin.flights.R
import kotlin.random.Random

/**
 * Provides tactile haptic feedback and real recorded commercial jet airliner flyby audio
 * (`res/raw/jet_hop.wav`, `jet_back.wav`, `jet_longer.wav`, `jet_victory.wav`) via Android's
 * low-latency `SoundPool`.
 */
class FeedbackManager(context: Context) {
    private val appContext = context.applicationContext

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val vm = appContext.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        vm?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        appContext.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val soundPool: SoundPool? = try {
        SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
    } catch (_: Exception) {
        null
    }

    private val hopSoundId: Int = soundPool?.load(appContext, R.raw.jet_hop, 1) ?: 0
    private val backSoundId: Int = soundPool?.load(appContext, R.raw.jet_back, 1) ?: 0
    private val longerSoundId: Int = soundPool?.load(appContext, R.raw.jet_longer, 1) ?: 0
    private val victorySoundId: Int = soundPool?.load(appContext, R.raw.jet_victory, 1) ?: 0
    private var activeStreamId: Int = 0

    fun onPreviewSelect(hapticsEnabled: Boolean) {
        if (hapticsEnabled) {
            vibrateClick(10L, 60)
        }
    }

    fun onHop(hapticsEnabled: Boolean, soundEnabled: Boolean) {
        if (hapticsEnabled) {
            vibrateClick(18L, 120)
        }
        if (soundEnabled) {
            val rate = 0.97f + Random.nextFloat() * 0.06f
            playSound(hopSoundId, volume = 0.72f, rate = rate)
        }
    }

    fun onBacktrack(hapticsEnabled: Boolean, soundEnabled: Boolean) {
        if (hapticsEnabled) {
            vibrateClick(14L, 90)
        }
        if (soundEnabled) {
            playSound(backSoundId, volume = 0.62f, rate = 0.98f)
        }
    }

    fun onLongerRoute(hapticsEnabled: Boolean, soundEnabled: Boolean) {
        if (hapticsEnabled) {
            vibratePattern(longArrayOf(0, 25, 60, 35), intArrayOf(0, 150, 0, 180))
        }
        if (soundEnabled) {
            playSound(longerSoundId, volume = 0.78f, rate = 1.0f)
        }
    }

    fun onVictory(hapticsEnabled: Boolean, soundEnabled: Boolean) {
        if (hapticsEnabled) {
            vibratePattern(longArrayOf(0, 20, 45, 25, 50, 45), intArrayOf(0, 130, 0, 170, 0, 230))
        }
        if (soundEnabled) {
            playSound(victorySoundId, volume = 0.88f, rate = 1.0f)
        }
    }

    private fun playSound(soundId: Int, volume: Float, rate: Float) {
        try {
            val pool = soundPool ?: return
            if (soundId == 0) return
            if (activeStreamId != 0) {
                pool.stop(activeStreamId)
            }
            activeStreamId = pool.play(soundId, volume, volume, 1, 0, rate)
        } catch (_: Exception) {
        }
    }

    private fun vibrateClick(durationMs: Long, amplitude: Int) {
        try {
            val v = vibrator ?: return
            if (!v.hasVibrator()) return
            v.vibrate(VibrationEffect.createOneShot(durationMs, amplitude))
        } catch (_: Exception) {
        }
    }

    private fun vibratePattern(timings: LongArray, amplitudes: IntArray) {
        try {
            val v = vibrator ?: return
            if (!v.hasVibrator()) return
            v.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
        } catch (_: Exception) {
        }
    }
}
