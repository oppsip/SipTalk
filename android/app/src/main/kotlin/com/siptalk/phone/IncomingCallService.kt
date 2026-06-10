package com.siptalk.siptalk

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class IncomingCallService : Service() {
    companion object {
        const val ACTION_SHOW_INCOMING_CALL = "com.siptalk.siptalk.action.SHOW_INCOMING_CALL"
        const val ACTION_STOP_RINGING = "com.siptalk.siptalk.action.STOP_RINGING"
        const val EXTRA_CALL_ID = "callId"
        const val EXTRA_CALLER = "caller"
        const val EXTRA_DISPLAY_NAME = "displayName"

        private const val CHANNEL_ID = "incoming_calls"
        private const val NOTIFICATION_ID = 1001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SHOW_INCOMING_CALL -> showIncomingCall(intent)
            ACTION_STOP_RINGING -> stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }

    private fun showIncomingCall(intent: Intent) {
        ensureNotificationChannel()

        val callId = intent.getStringExtra(EXTRA_CALL_ID).orEmpty()
        val caller = intent.getStringExtra(EXTRA_CALLER).orEmpty()
        val displayName = intent.getStringExtra(EXTRA_DISPLAY_NAME).takeUnless { it.isNullOrBlank() }
        val title = displayName ?: caller.ifBlank { "Incoming call" }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_CALLER, caller)
            putExtra(EXTRA_DISPLAY_NAME, displayName)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            callId.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(title)
            .setContentText("Incoming SIP call")
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .setAutoCancel(false)
            .setFullScreenIntent(pendingIntent, true)
            .setContentIntent(pendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Incoming calls",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Shows incoming SIP calls"
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }
}
