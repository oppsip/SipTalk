# PJSIP Core Design

The native SIP core wraps PJSUA2 and exposes a narrow, stable API to the rest of the application. UI code never owns PJSUA2 objects.

## Threading Model

```text
UI thread
  |
Platform bridge
  |
SipCommandQueue thread
  |
PJSUA2 objects
```

PJSIP callbacks must not perform blocking work. They translate native events into app events and post them to the event stream.

## Object Ownership

```text
SipCore
  |
  |-- Endpoint
  |-- SipAccountManager
  |     |-- Account objects
  |
  |-- SipCallManager
        |-- Call objects
```

Flutter, Kotlin, and Swift should only see `accountId` and `callId`.

## Commands

```text
initialize
shutdown
createAccount
registerAccount
unregisterAccount
deleteAccount
makeCall
answerCall
rejectCall
hangupCall
holdCall
resumeCall
sendDtmf
setMute
setAudioRoute
startRecording
stopRecording
```

## Events

```text
CoreReady
CoreFailed
AccountRegistrationChanged
IncomingCall
OutgoingCallProgress
CallStateChanged
CallMediaChanged
CallQualityChanged
AudioRouteChanged
DiagnosticLog
```

## Account States

```text
Unconfigured
Configured
Registering
Registered
RegistrationFailed
PushReachable
Offline
```

## Call States

```text
Idle
IncomingPush
IncomingSip
Ringing
Calling
Connecting
InCall
Held
Reconnecting
Terminating
Ended
Failed
```

## Deadlock Avoidance

- Do not destroy calls inside their own callbacks.
- Do not switch audio devices inside media callbacks.
- Do not call into UI from PJSIP callbacks.
- Do not run network requests on the SIP worker.
- Do not let multiple threads operate the same PJSUA2 object.

## Native Dependency Rules

- Pin PJSIP, OpenSSL, libsrtp, and codec versions.
- Build all native dependencies with the same NDK/toolchain per target.
- Prefer Android `arm64-v8a` for production first.
- Verify shared libraries in CI.
- Keep TLS certificate verification enabled in production.
