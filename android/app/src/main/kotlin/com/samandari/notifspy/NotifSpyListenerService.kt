package com.samandari.notifspy

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotifSpyListenerService : NotificationListenerService() {

    companion object {
        var instance: NotifSpyListenerService? = null
        val postedNotifications = mutableListOf<Map<String, Any?>>()
        val removedNotifications = mutableListOf<Map<String, Any?>>()
        var onNotificationPosted: ((Map<String, Any?>) -> Unit)? = null
        var onNotificationRemoved: ((Map<String, Any?>) -> Unit)? = null
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        val bigText = extras.getCharSequence("android.bigText")?.toString()
        val subText = extras.getCharSequence("android.subText")?.toString()
        val conversationTitle = extras.getCharSequence("android.conversationTitle")?.toString()
        val isGroupSummary = (sbn.notification.flags and android.app.Notification.FLAG_GROUP_SUMMARY) != 0

        val pm = applicationContext.packageManager
        val appName = try {
            pm.getApplicationLabel(pm.getApplicationInfo(sbn.packageName, 0)).toString()
        } catch (e: Exception) {
            sbn.packageName
        }

        val data = mapOf<String, Any?>(
            "type" to "posted",
            "key" to sbn.key,
            "packageName" to sbn.packageName,
            "appName" to appName,
            "title" to title,
            "text" to text,
            "bigText" to bigText,
            "subText" to subText,
            "category" to sbn.notification?.category,
            "isGroupSummary" to isGroupSummary,
            "conversationTitle" to conversationTitle,
            "timestamp" to sbn.postTime
        )

        synchronized(postedNotifications) {
            postedNotifications.add(data)
        }
        onNotificationPosted?.invoke(data)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return

        val extras = sbn.notification?.extras
        val title = extras?.getCharSequence("android.title")?.toString() ?: ""
        val text = extras?.getCharSequence("android.text")?.toString() ?: ""

        val data = mapOf<String, Any?>(
            "type" to "removed",
            "key" to sbn.key,
            "packageName" to sbn.packageName,
            "title" to title,
            "text" to text,
            "timestamp" to System.currentTimeMillis()
        )

        synchronized(removedNotifications) {
            removedNotifications.add(data)
        }
        onNotificationRemoved?.invoke(data)
    }
}
