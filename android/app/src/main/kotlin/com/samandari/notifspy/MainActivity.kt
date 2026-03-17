package com.samandari.notifspy

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.samandari.notifspy/listener"
    private val EVENT_CHANNEL = "com.samandari.notifspy/notifications"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "openPermissionSettings" -> {
                    openNotificationListenerSettings()
                    result.success(null)
                }
                "isServiceRunning" -> {
                    result.success(NotifSpyListenerService.instance != null && NotifSpyListenerService.isConnected)
                }
                "isBatteryOptimized" -> {
                    val pm = getSystemService(POWER_SERVICE) as PowerManager
                    result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestBatteryOptimization" -> {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    result.success(null)
                }
                "rebindService" -> {
                    try {
                        val cn = ComponentName(this, NotifSpyListenerService::class.java)
                        android.service.notification.NotificationListenerService.requestRebind(cn)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events

                    NotifSpyListenerService.onNotificationPosted = { data ->
                        runOnUiThread { eventSink?.success(data) }
                    }
                    NotifSpyListenerService.onNotificationRemoved = { data ->
                        runOnUiThread { eventSink?.success(data) }
                    }

                    synchronized(NotifSpyListenerService.postedNotifications) {
                        for (n in NotifSpyListenerService.postedNotifications) {
                            eventSink?.success(n)
                        }
                        NotifSpyListenerService.postedNotifications.clear()
                    }
                    synchronized(NotifSpyListenerService.removedNotifications) {
                        for (n in NotifSpyListenerService.removedNotifications) {
                            eventSink?.success(n)
                        }
                        NotifSpyListenerService.removedNotifications.clear()
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    NotifSpyListenerService.onNotificationPosted = null
                    NotifSpyListenerService.onNotificationRemoved = null
                }
            }
        )
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val cn = ComponentName(this, NotifSpyListenerService::class.java)
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(cn.flattenToString())
    }

    private fun openNotificationListenerSettings() {
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }
}
