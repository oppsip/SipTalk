package com.siptalk.siptalk

import org.json.JSONObject

class SipNative(private val listener: (Map<String, Any?>) -> Unit) {
    external fun initialize()
    external fun shutdown()
    external fun createAccount(
        id: String,
        displayName: String,
        domain: String,
        username: String,
        password: String,
        authUsername: String?,
        proxy: String?,
        transport: String,
        registrationExpiresSeconds: Int,
    )
    external fun registerAccount(accountId: String)
    external fun unregisterAccount(accountId: String)
    external fun makeCall(accountId: String, destination: String): String
    external fun answerCall(callId: String)
    external fun rejectCall(callId: String)
    external fun hangupCall(callId: String)
    external fun holdCall(callId: String)
    external fun resumeCall(callId: String)
    external fun sendDtmf(callId: String, digits: String)
    external fun setMuted(callId: String, muted: Boolean)
    external fun setAudioRoute(route: String)

    @Suppress("unused")
    private fun emitNativeEvent(
        type: String,
        accountId: String,
        callId: String,
        payloadJson: String,
    ) {
        val event = mutableMapOf<String, Any?>("type" to type)
        if (accountId.isNotBlank()) {
            event["accountId"] = accountId
        }
        if (callId.isNotBlank()) {
            event["callId"] = callId
        }

        if (payloadJson.isNotBlank()) {
            val payload = JSONObject(payloadJson)
            for (key in payload.keys()) {
                event[key] = if (payload.isNull(key)) null else payload.get(key)
            }
        }

        listener(event)
    }

    companion object {
        init {
            System.loadLibrary("siptalk_jni")
        }
    }
}
