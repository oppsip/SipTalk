# SipTalk Architecture

SipTalk is designed as a commercial-grade cross-platform SIP phone built around PJSIP/PJSUA2. PJSIP owns SIP signaling, media, NAT traversal, and codec integration, while the app owns lifecycle, background reachability, audio routing, state management, observability, and platform call integration.

## Goals

- Reliable audio calling on Android, iOS, Windows, macOS, and Linux.
- No direct UI access to PJSUA2 objects.
- Background incoming calls are delivered through push wakeup, not by assuming a persistent SIP socket.
- All SIP operations are serialized through a command queue.
- Audio routing is isolated per platform.
- Native libraries are built reproducibly and verified in CI.
- Logs and metrics are good enough to diagnose failed calls in production.

## High-Level Shape

```text
Flutter UI
  |
  |-- SipController
  |-- SipStateStore
  |-- SipEventStream
  |
Platform Bridge
  |
  |-- Android: Kotlin + JNI/C++
  |-- iOS: Swift + Objective-C++
  |-- Desktop: FFI/C++
  |
Native SipCore
  |
  |-- SipCommandQueue
  |-- SipStateMachine
  |-- SipAccountManager
  |-- SipCallManager
  |-- AudioRouteAdapter
  |-- Diagnostics
  |
PJSUA2 / PJSIP / PJMEDIA / PJNATH
```

## Backend Shape

```text
SIP Edge / PBX Adapter
  |
Call Orchestrator
  |
  |-- Device Registry
  |-- Push Gateway
  |-- Call State Store
  |-- Metrics
```

The backend is required for commercial mobile reliability. Without control over a push-capable SIP edge or adapter, background incoming calls on mobile cannot be guaranteed.

## Reliability Principles

1. Treat PJSIP as a native communication engine.
2. Keep PJSUA2 object lifetime inside native code.
3. Expose only stable app-level IDs to Flutter.
4. Never execute heavy operations inside PJSIP callbacks.
5. Serialize all SIP commands on a SIP worker queue.
6. Use PushKit/CallKit on iOS and FCM/full-screen notification/foreground service on Android.
7. Build observability into the first version.

## Core Modules

### SipController

The Flutter-facing API. It accepts user commands and subscribes to events. It does not know about PJSUA2.

### SipCommandQueue

Single-threaded native queue for operations such as register, answer, hangup, hold, resume, DTMF, and route switching.

### SipStateMachine

Owns legal transitions for account, call, and background states. Invalid transitions are rejected and logged.

### PushCallManager

Coordinates incoming push payloads with SIP registration, duplicate call suppression, timeout handling, and system call UI.

### AudioRouteManager

Owns audio focus, communication mode, route selection, Bluetooth, wired headset, speaker, receiver, interruptions, and platform-specific recovery.

### Diagnostics

Collects PJSIP logs, registration attempts, call state transitions, push latency, RTP quality, audio route changes, and crash breadcrumbs.

The first app-level diagnostic primitive is the call timeline. It records durable milestones such as push delivery, system incoming UI, user answer, SIP registration recovery, media connection, call end, and failure reason.

## Initial Milestones

1. Project skeleton, state model, and native core interfaces.
2. Android audio call MVP with foreground service.
3. iOS CallKit/PushKit skeleton.
4. Push Gateway protocol and call orchestration.
5. TLS/SRTP/STUN/TURN/ICE.
6. Production diagnostics and stress tests.
