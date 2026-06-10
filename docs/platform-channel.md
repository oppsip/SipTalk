# Platform Channel Contract

The Flutter app talks to native code through two channels.

```text
MethodChannel: siptalk/sip_commands
EventChannel:  siptalk/sip_events
```

## Command Rules

- Commands are intent-based and must not expose PJSUA2 objects.
- Native code must serialize commands onto `SipCommandQueue`.
- Commands return only simple values such as `callId`.
- Long-running state is reported through the event channel.

## Commands

```text
initialize
shutdown
createAccount
registerAccount
unregisterAccount
makeCall
answerCall
rejectCall
hangupCall
holdCall
resumeCall
sendDtmf
setMuted
setAudioRoute
```

## Event Shape

All native events are maps with a required `type`.

```json
{
  "type": "CallStateChanged",
  "accountId": "default",
  "callId": "call-1",
  "state": "inCall"
}
```

## State Names

Use Dart enum names in lower camel case:

```text
registering
registered
pushReachable
incomingPush
incomingSip
inCall
reconnecting
```

## Android Bridge

`SipPlatformBridge` currently provides a stub implementation. It should be registered by the Android Flutter activity or plugin and later connected to JNI.

## iOS Bridge

The iOS bridge should mirror the same contract with `FlutterMethodChannel` and `FlutterEventChannel`, then forward commands to the Objective-C++ PJSIP wrapper.
