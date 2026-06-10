# SipTalk

SipTalk is a commercial-grade cross-platform SIP phone project based on PJSIP/PJSUA2.

The design prioritizes reliable mobile incoming calls, native SIP lifecycle isolation, deterministic audio routing, and production diagnostics.

## Current Status

Initial architecture and scaffolding are in place:

- `docs/architecture.md`
- `docs/mobile-incoming-call.md`
- `docs/pjsip-core-design.md`
- `docs/push-gateway-protocol.md`
- `docs/implementation-plan.md`
- `docs/platform-channel.md`
- `docs/native-dependencies.md`
- `lib/sip/`
- `native/sip_core/`
- Android incoming-call/audio placeholders
- iOS PushKit/CallKit/audio placeholders

## Core Principle

PJSIP is treated as a native communication engine. UI code talks to a stable SIP controller API and never directly owns PJSUA2 objects.

## Mobile Incoming Calls

Mobile background reliability requires a backend Push Gateway:

```text
SIP INVITE -> Call Orchestrator -> FCM/APNs -> App wakeup -> system call UI -> PJSIP recovery
```

Persistent background SIP registration is not considered reliable enough for a commercial mobile app.
