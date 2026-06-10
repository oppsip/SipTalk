# Push Gateway Protocol

The Push Gateway bridges SIP incoming calls to mobile OS wakeup mechanisms.

## Device Registration

```http
POST /v1/devices/register
Content-Type: application/json
Authorization: Bearer <user-token>
```

```json
{
  "deviceId": "stable-device-id",
  "platform": "android",
  "pushProvider": "fcm",
  "pushToken": "token",
  "sipAccountId": "account-id",
  "appVersion": "1.0.0",
  "capabilities": ["audio", "tls", "srtp"]
}
```

## Incoming Call Created

The SIP edge or PBX adapter calls the orchestrator when an INVITE arrives.

```http
POST /v1/calls/incoming
Content-Type: application/json
```

```json
{
  "sipCallId": "sip-call-id",
  "calleeAccountId": "account-id",
  "caller": "1001",
  "displayName": "Alice",
  "expiresAtMs": 1780000030000
}
```

The orchestrator creates a server `callId`, finds registered devices, and sends push notifications.

## Client Acknowledges Push

```http
POST /v1/calls/{callId}/push-received
Content-Type: application/json
Authorization: Bearer <user-token>
```

```json
{
  "deviceId": "stable-device-id",
  "receivedAtMs": 1780000001200
}
```

## Client Reports Ringing

```http
POST /v1/calls/{callId}/ringing
Content-Type: application/json
Authorization: Bearer <user-token>
```

```json
{
  "deviceId": "stable-device-id",
  "systemUiShownAtMs": 1780000001600
}
```

## Client Attempts Answer

```http
POST /v1/calls/{callId}/answer
Content-Type: application/json
Authorization: Bearer <user-token>
```

```json
{
  "deviceId": "stable-device-id",
  "answeredAtMs": 1780000005000
}
```

Answer must be atomic. If another device has already answered, return `409 Conflict`.

## Client Declines

```http
POST /v1/calls/{callId}/decline
Content-Type: application/json
Authorization: Bearer <user-token>
```

```json
{
  "deviceId": "stable-device-id",
  "reason": "user_declined"
}
```

## Failure Reasons

Use stable reason codes:

```text
push_provider_error
push_not_delivered
client_not_reachable
call_expired
answered_elsewhere
user_declined
sip_registration_failed
sip_answer_failed
media_failed
```

## Production Rules

- Store device tokens encrypted at rest.
- Expire stale device tokens.
- Deduplicate calls by SIP Call-ID plus callee account.
- Keep a complete timeline for every call.
- Do not include SIP credentials in push payloads.
- Keep push payload small and non-sensitive.
