package com.siptalk.siptalk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build

class AudioRouteManager(private val context: Context) {
    enum class Route {
        Receiver,
        Speaker,
        WiredHeadset,
        Bluetooth,
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var previousMode = AudioManager.MODE_NORMAL
    private var previousSpeakerphone = false
    private var focusRequest: AudioFocusRequest? = null
    private var currentRoute = Route.Receiver
    private var receiverRegistered = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                selectRoute(Route.Receiver)
            }
        }
    }

    fun prepareForCall() {
        previousMode = audioManager.mode
        previousSpeakerphone = audioManager.isSpeakerphoneOn

        requestAudioFocus()
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        registerNoisyReceiver()
        selectRoute(currentRoute)
    }

    fun releaseAfterCall() {
        unregisterNoisyReceiver()
        clearPreferredDevice()
        audioManager.isSpeakerphoneOn = previousSpeakerphone
        audioManager.mode = previousMode
        abandonAudioFocus()
    }

    fun selectRoute(route: Route) {
        currentRoute = route

        when (route) {
            Route.Speaker -> {
                clearPreferredDevice()
                audioManager.isSpeakerphoneOn = true
            }
            Route.Receiver -> {
                clearPreferredDevice()
                audioManager.isSpeakerphoneOn = false
            }
            Route.WiredHeadset -> {
                audioManager.isSpeakerphoneOn = false
                preferDevice(AudioDeviceInfo.TYPE_WIRED_HEADSET, AudioDeviceInfo.TYPE_WIRED_HEADPHONES)
            }
            Route.Bluetooth -> {
                audioManager.isSpeakerphoneOn = false
                preferDevice(AudioDeviceInfo.TYPE_BLUETOOTH_SCO, AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
            }
        }
    }

    fun hasRoute(route: Route): Boolean {
        return when (route) {
            Route.Receiver -> true
            Route.Speaker -> true
            Route.WiredHeadset -> hasDevice(
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            )
            Route.Bluetooth -> hasDevice(
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            )
        }
    }

    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .setAcceptsDelayedFocusGain(false)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let(audioManager::abandonAudioFocusRequest)
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }

    private fun preferDevice(vararg types: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return
        }

        val device = audioManager.availableCommunicationDevices.firstOrNull { device ->
            types.contains(device.type)
        }
        if (device != null) {
            audioManager.setCommunicationDevice(device)
        }
    }

    private fun clearPreferredDevice() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        }
    }

    private fun hasDevice(vararg types: Int): Boolean {
        val devices = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.availableCommunicationDevices
        } else {
            audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
        }
        return devices.any { device -> types.contains(device.type) }
    }

    private fun registerNoisyReceiver() {
        if (receiverRegistered) {
            return
        }

        context.registerReceiver(noisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        receiverRegistered = true
    }

    private fun unregisterNoisyReceiver() {
        if (!receiverRegistered) {
            return
        }

        context.unregisterReceiver(noisyReceiver)
        receiverRegistered = false
    }
}
