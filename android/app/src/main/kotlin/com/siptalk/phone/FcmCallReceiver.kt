package com.siptalk.siptalk

import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class FcmCallReceiver {
    private val seenCallIds = ArrayDeque<String>()

    fun onIncomingCallPush(context: Context, payload: Map<String, String>) {
        val callId = payload["callId"].orEmpty()
        if (callId.isBlank() || !markIfNew(callId)) {
            return
        }

        val intent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_SHOW_INCOMING_CALL
            putExtra(IncomingCallService.EXTRA_CALL_ID, callId)
            putExtra(IncomingCallService.EXTRA_CALLER, payload["caller"].orEmpty())
            putExtra(IncomingCallService.EXTRA_DISPLAY_NAME, payload["displayName"].orEmpty())
        }
        ContextCompat.startForegroundService(context, intent)
    }

    private fun markIfNew(callId: String): Boolean {
        if (seenCallIds.contains(callId)) {
            return false
        }

        seenCallIds.addLast(callId)
        while (seenCallIds.size > 128) {
            seenCallIds.removeFirst()
        }
        return true
    }
}
