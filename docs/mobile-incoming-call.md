# Mobile Incoming Call Design

Commercial mobile SIP reliability requires a push-assisted incoming call path. Android and iOS do not allow a third-party app to rely on a permanently alive SIP registration socket in the background.

## States

```text
ForegroundOnline
BackgroundPushReachable
BackgroundSuspended
IncomingPush
IncomingSip
Ringing
InCallProtected
Ended
```

## Normal Foreground Flow

```text
SIP INVITE
  |
PJSIP receives call
  |
SipCore emits IncomingSip(callId)
  |
UI shows incoming call
  |
User answers
  |
SipCommandQueue executes answer
```

## Background Mobile Flow

```text
SIP INVITE at SIP edge
  |
Call Orchestrator creates callId
  |
Push Gateway sends APNs VoIP Push or FCM high priority message
  |
Device wakes
  |
Client reports push_received(callId)
  |
System incoming call UI is shown
  |
Client restores SipCore and REGISTERs if needed
  |
User answers
  |
Client sends answer intent
  |
SIP media is established
```

## Android Requirements

- Use FCM high priority messages for incoming calls.
- Show a high-importance incoming call notification.
- Use full-screen intent when allowed.
- Start a short-lived incoming call service for ringing.
- Start a foreground service during active calls.
- Declare appropriate foreground service types for phone call and microphone usage.
- Request notification permission on Android 13+.
- Provide vendor-specific battery optimization guidance as a fallback, not as the primary mechanism.

## iOS Requirements

- Use APNs VoIP Push through PushKit.
- Report incoming calls through CallKit immediately after VoIP push delivery.
- Do not rely on background SIP keepalive.
- Activate AVAudioSession only when CallKit grants audio.
- Complete or fail the CallKit answer action based on SIP readiness.

## Push Payload

```json
{
  "type": "incoming_call",
  "callId": "server-call-id",
  "sipCallId": "sip-call-id",
  "accountId": "account-id",
  "caller": "1001",
  "displayName": "Alice",
  "timestampMs": 1780000000000,
  "expiresAtMs": 1780000030000
}
```

## Duplicate Handling

The client must deduplicate by `callId`. The backend must treat answer as a compare-and-set operation so only one device wins in multi-device ringing.

## Timeouts

- Push delivery wait: 3-5 seconds before trying next route or continuing multi-device ringing.
- Ring timeout: usually 20-30 seconds.
- Client answer SIP readiness timeout: 5-8 seconds.

## Required Metrics

- push_send_at
- push_provider_accepted_at
- push_received_at
- system_ui_shown_at
- user_answered_at
- sip_registered_at
- media_connected_at
- call_ended_at
- failure_reason
