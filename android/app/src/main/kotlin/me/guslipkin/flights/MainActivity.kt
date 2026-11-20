package me.guslipkin.flights

import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSounds = mutableSetOf<Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initSoundPool()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "me.guslipkin.flights/platform"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playSound" -> {
                    val name = call.argument<String>("name") ?: "jet_hop"
                    playSound(name)
                    result.success(null)
                }
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val title = call.argument<String>("title") ?: "Share Flights Result"
                    val sendIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_SUBJECT, title)
                        putExtra(Intent.EXTRA_TEXT, text)
                    }
                    val shareIntent = Intent.createChooser(sendIntent, title)
                    startActivity(shareIntent)
                    result.success(null)
                }
                "readSave" -> {
                    try {
                        val file = File(filesDir, "saves.json")
                        if (file.exists()) {
                            result.success(file.readText(Charsets.UTF_8))
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "writeSave" -> {
                    try {
                        val content = call.argument<String>("content") ?: ""
                        val file = File(filesDir, "saves.json")
                        val tmp = File(filesDir, "saves.json.tmp")
                        tmp.writeText(content, Charsets.UTF_8)
                        if (!tmp.renameTo(file)) {
                            file.writeText(content, Charsets.UTF_8)
                            tmp.delete()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "appVersion" -> {
                    result.success(packageManager.getPackageInfo(packageName, 0).versionName)
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initSoundPool() {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(attrs)
            .build()
        pool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) {
                loadedSounds.add(sampleId)
            }
        }
        soundPool = pool

        val loader = FlutterInjector.instance().flutterLoader()
        for (name in listOf("jet_hop", "jet_back", "jet_longer", "jet_victory")) {
            try {
                val assetKey = loader.getLookupKeyForAsset("assets/audio/$name.wav")
                assets.openFd(assetKey).use { afd ->
                    val id = pool.load(afd, 1)
                    soundIds[name] = id
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun playSound(name: String) {
        val pool = soundPool ?: return
        val id = soundIds[name] ?: return
        if (!loadedSounds.contains(id)) return
        val volume = when (name) {
            "jet_victory" -> 0.85f
            "jet_longer" -> 0.78f
            "jet_back" -> 0.70f
            else -> 0.75f
        }
        pool.play(id, volume, volume, 1, 0, 1.0f)
    }

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }
}
