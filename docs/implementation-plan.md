# Implementation Plan

## Phase 0: Foundation

- Create public Dart SIP API.
- Create native SIP core boundary.
- Add command queue and event model.
- Define mobile incoming call protocol.
- Define account, call, and background states.

## Phase 1: Local Audio Call MVP

- Build PJSIP 2.17 and native dependencies.
- Wire PJSUA2 `Endpoint`.
- Implement account registration.
- Implement outbound and inbound audio calls.
- Implement hangup, answer, reject, DTMF, mute, and speaker.
- Export PJSIP logs.

## Phase 2: Android Reliability

- Implement FCM incoming call push handling.
- Implement `IncomingCallService`.
- Implement foreground service for active calls.
- Implement full-screen incoming call notification.
- Implement Android `AudioRouteManager`.
- Add battery optimization guidance screens.

## Phase 3: iOS Reliability

- Implement PushKit registration.
- Implement CallKit incoming call reporting.
- Implement CallKit answer/end actions.
- Implement AVAudioSession activation flow.
- Recover PJSIP registration after VoIP push.

## Phase 4: Secure Media and NAT

- Enable SIP TLS.
- Enable SRTP.
- Add STUN/TURN/ICE configuration.
- Add certificate validation and private CA support.

## Phase 5: Production Diagnostics

- Add call timeline logging.
- Add RTP quality reporting.
- Add native crash breadcrumbs.
- Add one-tap diagnostic export.
- Add backend call metrics.

## Phase 6: Stress and Compatibility

- 100 registration cycles.
- 100 call setup/teardown cycles.
- Wi-Fi to cellular handoff.
- Bluetooth connect/disconnect during active call.
- Lock-screen incoming call.
- Killed-app incoming call.
- Weak network and packet loss tests.
