package com.example.itantra_app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val CHANNEL = "com.itantra.app/hardware_override"
    private var previousVolume: Int = -1
    private var previousInterruptionFilter: Int = -1
    private var multicastLock: WifiManager.MulticastLock? = null
    private var tts: TextToSpeech? = null
    private var ttsInitialized = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingSttResult: MethodChannel.Result? = null

    companion object {
        init {
            try {
                System.loadLibrary("onnxruntime")
                System.loadLibrary("sherpa-onnx-c-api")
            } catch (e: UnsatisfiedLinkError) {
                // Dynamically loaded by JNI runner
            }
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            ttsInitialized = true
            tts?.language = Locale("hi", "IN")
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Native Android TTS
        try {
            tts = TextToSpeech(applicationContext, this)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Initialize Native Android SpeechRecognizer
        try {
            if (SpeechRecognizer.isRecognitionAvailable(applicationContext)) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(applicationContext)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Acquire Wi-Fi Multicast Lock to ensure UDP broadcast packets are not dropped
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("iTantraP2PMulticast")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                // ── SPEECH-TO-TEXT ─────────────────────────────────────────────────────
                "recognizeSpeech" -> {
                    val langCode = call.argument<String>("langCode") ?: "hi"
                    try {
                        // Cancel any in-progress recognition
                        speechRecognizer?.cancel()
                        pendingSttResult?.success("")
                        pendingSttResult = result

                        val locale = when (langCode.lowercase(Locale.ROOT)) {
                            "hi" -> "hi-IN"
                            "ta" -> "ta-IN"
                            "te" -> "te-IN"
                            "kn" -> "kn-IN"
                            "ml" -> "ml-IN"
                            "mr" -> "mr-IN"
                            "bn" -> "bn-IN"
                            "gu" -> "gu-IN"
                            "pa" -> "pa-IN"
                            else -> "en-IN"
                        }

                        val recognizerIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                            putExtra("android.speech.extra.EXTRA_ADDITIONAL_LANGUAGES", arrayOf(locale, "en-IN", "hi-IN"))
                            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                            // Prefer offline recognition if model is installed on device
                            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                        }

                        speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                            override fun onReadyForSpeech(params: Bundle?) {}
                            override fun onBeginningOfSpeech() {}
                            override fun onRmsChanged(rmsdB: Float) {}
                            override fun onBufferReceived(buffer: ByteArray?) {}
                            override fun onEndOfSpeech() {}

                            override fun onResults(bundle: Bundle?) {
                                val matches = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                                val text = matches?.firstOrNull() ?: ""
                                val pending = pendingSttResult
                                pendingSttResult = null
                                pending?.success(text)
                            }

                            override fun onPartialResults(partialResults: Bundle?) {}

                            override fun onError(error: Int) {
                                val pending = pendingSttResult
                                pendingSttResult = null
                                // Return empty string on error (don't crash — let Dart handle it)
                                pending?.success("")
                            }

                            override fun onEvent(eventType: Int, params: Bundle?) {}
                        })

                        speechRecognizer?.startListening(recognizerIntent)
                    } catch (e: Exception) {
                        pendingSttResult = null
                        result.success("")
                    }
                }

                "stopRecognition" -> {
                    try {
                        speechRecognizer?.stopListening()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                // ── TEXT-TO-SPEECH ─────────────────────────────────────────────────────
                "speakText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val langCode = call.argument<String>("langCode") ?: "hi"
                    try {
                        val locale = when (langCode.lowercase(Locale.ROOT)) {
                            "hi" -> Locale("hi", "IN")
                            "ta" -> Locale("ta", "IN")
                            "te" -> Locale("te", "IN")
                            "kn" -> Locale("kn", "IN")
                            "ml" -> Locale("ml", "IN")
                            "mr" -> Locale("mr", "IN")
                            "bn" -> Locale("bn", "IN")
                            "gu" -> Locale("gu", "IN")
                            "pa" -> Locale("pa", "IN")
                            else -> Locale("en", "IN")
                        }
                        tts?.language = locale
                        tts?.setSpeechRate(0.95f)

                        val params = Bundle().apply {
                            putInt(TextToSpeech.Engine.KEY_PARAM_STREAM, AudioManager.STREAM_ALARM)
                            putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1.0f)
                        }
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "iTantra_${System.currentTimeMillis()}")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TTS_ERROR", e.message, null)
                    }
                }

                // ── EMERGENCY OVERRIDE ─────────────────────────────────────────────────
                "triggerEmergencyAlert" -> {
                    try {
                        var dndBypassed = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                previousInterruptionFilter = notificationManager.currentInterruptionFilter
                                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
                                dndBypassed = true
                            }
                        }

                        previousVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
                        val maxAlarmVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        audioManager.setStreamVolume(
                            AudioManager.STREAM_ALARM,
                            maxAlarmVolume,
                            AudioManager.FLAG_SHOW_UI or AudioManager.FLAG_PLAY_SOUND
                        )

                        result.success(mapOf(
                            "success" to true,
                            "alarmVolume" to maxAlarmVolume,
                            "dndOverridden" to dndBypassed
                        ))
                    } catch (e: Exception) {
                        result.error("HARDWARE_OVERRIDE_ERROR", e.message, null)
                    }
                }

                "restoreAudioSettings" -> {
                    try {
                        if (previousVolume != -1) {
                            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, previousVolume, 0)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && previousInterruptionFilter != -1) {
                            if (notificationManager.isNotificationPolicyAccessGranted) {
                                notificationManager.setInterruptionFilter(previousInterruptionFilter)
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESTORE_ERROR", e.message, null)
                    }
                }

                "checkDndAccess" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(notificationManager.isNotificationPolicyAccessGranted)
                    } else {
                        result.success(true)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        try {
            tts?.stop()
            tts?.shutdown()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            speechRecognizer?.destroy()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        super.onDestroy()
    }
}
