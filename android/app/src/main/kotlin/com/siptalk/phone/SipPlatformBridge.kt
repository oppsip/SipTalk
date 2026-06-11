package com.siptalk.siptalk

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.os.Handler
import android.os.Looper

class SipPlatformBridge(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private companion object {
        private const val TAG = "SipTalkBridge"
    }

    private var eventSink: EventChannel.EventSink? = null
    private val native = SipNative(::emit)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioRouteManager = AudioRouteManager(context.applicationContext)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                native.initialize()
                result.success(null)
            }
            "shutdown" -> {
                native.shutdown()
                result.success(null)
            }
            "createAccount" -> {
                native.createAccount(
                    id = call.argument<String>("id").orEmpty(),
                    displayName = call.argument<String>("displayName").orEmpty(),
                    domain = call.argument<String>("domain").orEmpty(),
                    username = call.argument<String>("username").orEmpty(),
                    password = call.argument<String>("password").orEmpty(),
                    authUsername = call.argument<String>("authUsername"),
                    proxy = call.argument<String>("proxy"),
                    transport = call.argument<String>("transport").orEmpty(),
                    registrationExpiresSeconds = call.argument<Int>("registrationExpiresSeconds") ?: 300,
                )
                result.success(null)
            }
            "registerAccount" -> {
                val accountId = call.argument<String>("accountId").orEmpty()
                native.registerAccount(accountId)
                result.success(null)
            }
            "unregisterAccount" -> {
                val accountId = call.argument<String>("accountId").orEmpty()
                native.unregisterAccount(accountId)
                result.success(null)
            }
            "makeCall" -> {
                if (!hasRecordAudioPermission()) {
                    (context as? Activity)?.requestPermissions(
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        1002,
                    )
                    emit(
                        mapOf(
                            "type" to "DiagnosticLog",
                            "level" to "error",
                            "message" to "Microphone permission is required before starting a SIP call",
                        ),
                    )
                    result.error(
                        "audio_permission_denied",
                        "Microphone permission is required before starting a SIP call",
                        null,
                    )
                    return
                }
                val accountId = call.argument<String>("accountId").orEmpty()
                val destination = call.argument<String>("destination").orEmpty()
                audioRouteManager.prepareForCall()
                val callId = native.makeCall(accountId, destination)
                result.success(callId)
            }
            "answerCall" -> {
                if (!hasRecordAudioPermission()) {
                    (context as? Activity)?.requestPermissions(
                        arrayOf(Manifest.permission.RECORD_AUDIO),
                        1002,
                    )
                    result.error(
                        "audio_permission_denied",
                        "Microphone permission is required before answering a SIP call",
                        null,
                    )
                    return
                }
                val callId = call.argument<String>("callId").orEmpty()
                audioRouteManager.prepareForCall()
                native.answerCall(callId)
                stopIncomingCallService()
                result.success(null)
            }
            "rejectCall" -> {
                val callId = call.argument<String>("callId").orEmpty()
                Log.i(TAG, "rejectCall requested: callId=$callId")
                native.rejectCall(callId)
                audioRouteManager.releaseAfterCall()
                stopIncomingCallService()
                result.success(null)
            }
            "hangupCall" -> {
                val callId = call.argument<String>("callId").orEmpty()
                native.hangupCall(callId)
                audioRouteManager.releaseAfterCall()
                stopIncomingCallService()
                result.success(null)
            }
            "holdCall" -> {
                val callId = call.argument<String>("callId").orEmpty()
                native.holdCall(callId)
                result.success(null)
            }
            "resumeCall" -> {
                val callId = call.argument<String>("callId").orEmpty()
                native.resumeCall(callId)
                result.success(null)
            }
            "sendDtmf" -> {
                native.sendDtmf(
                    callId = call.argument<String>("callId").orEmpty(),
                    digits = call.argument<String>("digits").orEmpty(),
                )
                result.success(null)
            }
            "setMuted" -> {
                native.setMuted(
                    callId = call.argument<String>("callId").orEmpty(),
                    muted = call.argument<Boolean>("muted") ?: false,
                )
                result.success(null)
            }
            "setAudioRoute" -> {
                val route = call.argument<String>("route").orEmpty()
                audioRouteManager.selectRoute(
                    when (route.lowercase()) {
                        "speaker" -> AudioRouteManager.Route.Speaker
                        "wiredheadset" -> AudioRouteManager.Route.WiredHeadset
                        "bluetooth" -> AudioRouteManager.Route.Bluetooth
                        else -> AudioRouteManager.Route.Receiver
                    },
                )
                native.setAudioRoute(route)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun emit(event: Map<String, Any?>) {
        Log.i(TAG, "Native event: type=${event["type"]} callId=${event["callId"]} state=${event["state"]}")
        handleIncomingCallNotification(event)
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    private fun handleIncomingCallNotification(event: Map<String, Any?>) {
        when (event["type"] as? String) {
            "IncomingCall" -> startIncomingCallService(event)
            "CallStateChanged" -> {
                when ((event["state"] as? String).orEmpty().lowercase()) {
                    "connecting", "incall", "ended", "failed" -> stopIncomingCallService()
                }
            }
        }
    }

    private fun startIncomingCallService(event: Map<String, Any?>) {
        val callId = (event["callId"] as? String).orEmpty()
        val remoteUri = (event["remoteUri"] as? String).orEmpty()
        val displayName = (event["displayName"] as? String).orEmpty()
        Log.i(TAG, "Starting incoming call surface: callId=$callId remoteUri=$remoteUri displayName=$displayName")
        val intent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_SHOW_INCOMING_CALL
            putExtra(IncomingCallService.EXTRA_CALL_ID, callId)
            putExtra(IncomingCallService.EXTRA_CALLER, remoteUri)
            putExtra(IncomingCallService.EXTRA_DISPLAY_NAME, displayName)
        }
        ContextCompat.startForegroundService(context.applicationContext, intent)
        bringActivityToFront(callId, remoteUri, displayName)
    }

    private fun stopIncomingCallService() {
        Log.i(TAG, "Stopping incoming call service")
        val intent = Intent(context, IncomingCallService::class.java).apply {
            action = IncomingCallService.ACTION_STOP_RINGING
        }
        context.applicationContext.startService(intent)
    }

    private fun bringActivityToFront(callId: String, remoteUri: String, displayName: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra(IncomingCallService.EXTRA_CALL_ID, callId)
            putExtra(IncomingCallService.EXTRA_CALLER, remoteUri)
            putExtra(IncomingCallService.EXTRA_DISPLAY_NAME, displayName)
        }
        try {
            context.applicationContext.startActivity(intent)
            Log.i(TAG, "MainActivity bring-to-front requested for incoming call")
        } catch (error: RuntimeException) {
            Log.w(TAG, "Unable to bring MainActivity to front for incoming call", error)
        }
    }

    private fun hasRecordAudioPermission(): Boolean {
        return context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }
}
