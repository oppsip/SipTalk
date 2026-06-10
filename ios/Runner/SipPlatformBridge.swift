import Flutter
import Foundation

final class SipPlatformBridge: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func attach(to messenger: FlutterBinaryMessenger) {
        let commandChannel = FlutterMethodChannel(
            name: "siptalk/sip_commands",
            binaryMessenger: messenger
        )
        let eventChannel = FlutterEventChannel(
            name: "siptalk/sip_events",
            binaryMessenger: messenger
        )

        commandChannel.setMethodCallHandler(handle)
        eventChannel.setStreamHandler(self)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            emit(["type": "CoreReady"])
            result(nil)
        case "shutdown", "createAccount", "sendDtmf", "setMuted":
            result(nil)
        case "registerAccount":
            let args = dictionary(from: call.arguments)
            emit([
                "type": "AccountRegistrationChanged",
                "accountId": args["accountId"] as? String ?? "",
                "state": "registering",
            ])
            result(nil)
        case "unregisterAccount":
            let args = dictionary(from: call.arguments)
            emit([
                "type": "AccountRegistrationChanged",
                "accountId": args["accountId"] as? String ?? "",
                "state": "offline",
            ])
            result(nil)
        case "makeCall":
            let args = dictionary(from: call.arguments)
            let callId = String(ProcessInfo.processInfo.systemUptime)
            emit([
                "type": "CallStateChanged",
                "accountId": args["accountId"] as? String ?? "",
                "callId": callId,
                "state": "calling",
                "remoteUri": args["destination"] as? String ?? "",
            ])
            result(callId)
        case "answerCall":
            emitCallState(call: call, state: "connecting")
            result(nil)
        case "rejectCall":
            emitCallState(call: call, state: "ended", reason: "Rejected")
            result(nil)
        case "hangupCall":
            emitCallState(call: call, state: "ended", reason: "Hangup")
            result(nil)
        case "holdCall":
            emitCallState(call: call, state: "held")
            result(nil)
        case "resumeCall":
            emitCallState(call: call, state: "inCall")
            result(nil)
        case "setAudioRoute":
            let args = dictionary(from: call.arguments)
            emit([
                "type": "AudioRouteChanged",
                "route": args["route"] as? String ?? "receiver",
            ])
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func emitCallState(call: FlutterMethodCall, state: String, reason: String? = nil) {
        let args = dictionary(from: call.arguments)
        var event: [String: Any] = [
            "type": "CallStateChanged",
            "callId": args["callId"] as? String ?? "",
            "state": state,
        ]
        if let reason {
            event["reason"] = reason
        }
        emit(event)
    }

    private func emit(_ event: [String: Any]) {
        eventSink?(event)
    }

    private func dictionary(from arguments: Any?) -> [String: Any] {
        arguments as? [String: Any] ?? [:]
    }
}
