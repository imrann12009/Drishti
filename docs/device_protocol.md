# DRISHTI device protocol — provisional contract

This document defines the app-side validation boundary. It is **not** the final BLE characteristic layout, Wi-Fi endpoint, or sensor packet format. The hardware team must approve the transport, authentication, replay protection, clock policy, and update mechanism before Device Mode is enabled.

## Envelope

Every device message must be a UTF-8 JSON object with:

| Field | Type | Requirement |
|---|---|---|
| `protocol_version` | string | Must equal the app-supported version. Current value: `0.1-provisional`. |
| `message_type` | string | Non-empty type name. |
| `timestamp` | ISO-8601 string | Parsed and normalized to UTC. |
| `session_id` | string | Non-empty opaque navigation session identifier. |
| `payload` | object | Message-specific object. Arrays and scalar values are rejected. |
| `error_code` | string or null | Optional error identifier. |
| `authentication` | object or null | Required by a configured transport security validator before the message is accepted. Its exact signed/MAC schema is hardware-team owned. |

Example shape:

```json
{
  "protocol_version": "0.1-provisional",
  "message_type": "obstacle_event",
  "timestamp": "2026-01-01T12:00:00Z",
  "session_id": "opaque-session-id",
  "payload": {},
  "error_code": null
}
```

## Initial message names

These names are provisional and require hardware review:

- `connection_status`
- `battery_status`
- `navigation_status`
- `obstacle_event`
- `device_health`
- `update_status`

No field inside these payloads is considered final yet.

## Safety rules

1. Unknown protocol versions are rejected.
2. Malformed JSON, missing required fields, invalid timestamps, and invalid field types are rejected.
3. A configured security validator rejects messages more than five seconds older or newer than its receive time, and rejects repeated envelopes within its replay-retention window.
4. Stale or unavailable sensor information must be presented as unknown, never as safe.
5. Transport adapters must not bypass `DeviceMessage` validation.
6. A real adapter must provide an authentication verifier; without it BLE and Wi-Fi connections refuse to become usable. The verifier, integrity scheme, rotating key IDs, nonce policy, and key revocation process remain hardware-team configuration, not app defaults.
7. No OTA update is allowed through this protocol until packages are authenticated, signed, integrity-checked, rollback-capable, and safe against power loss.
