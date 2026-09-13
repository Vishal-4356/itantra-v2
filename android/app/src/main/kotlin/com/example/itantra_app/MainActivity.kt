package com.example.itantra_app

import android.app.NotificationManager
import android.content.Context
import android.media.AudioManager
import android.net.wifi.WifiManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.itantra.app/hardware_override"
    private var previousVolume: Int = -1
    private var previousInterruptionFilter: Int = -1
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            multicastLock = wifiManager?.createMulticastLock("iTantraP2PMulticast")?.apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (e: Exception) { e.printStackTrace() }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            when (call.method) {
                // ── EMERGENCY OVERRIDE ───────────────────────────────────────────
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
                            AudioManager.STREAM_ALARM, maxAlarmVolume,
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

                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try { if (multicastLock?.isHeld == true) multicastLock?.release() } catch (e: Exception) { e.printStackTrace() }
        super.onDestroy()
    }
}