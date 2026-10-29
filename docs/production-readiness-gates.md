# DRISHTI production-readiness gates

This document separates code integration from validation that requires real
accounts, hardware, release signing, and supervised participants. A demo or
mock must not be labelled production-ready.

## Bengali TTS

Implemented in code through `FlutterTtsSpeechService` using the device's
installed `bn-BD` voice when available. The release gate remains open until a
real target Android device verifies Bengali pronunciation, interruption,
critical-alert priority, volume, Bluetooth audio, offline behavior, and failure
fallback.

## Persistent settings

Implemented through `SharedPreferencesRepository` for non-sensitive settings:
language, speech rate, volume, prompt preference, and demo mode. Payment tokens,
credentials, private keys, and health/location data must not be stored there.

## Raspberry Pi / sensor / Bluetooth / Wi-Fi

The app has a transport-neutral protocol and a release gate, but no real
transport is enabled. Before Device Mode:

- select and document the board, sensors, transport, power budget, and packet
  schema;
- approve authentication, integrity, replay protection, maximum message size,
  clock policy, timeout, stale-data, reconnect, and disconnect behavior;
- test malformed packets, stale packets, packet loss, battery failure, and
  firmware/app version mismatch;
- verify that unknown or stale data never becomes a “safe” instruction.

## Subscription and payment

Not implemented as live billing. A production adapter must use Google Play or
App Store products, handle pending/cancelled/refunded states, and verify
receipts on a trusted backend before granting Pro. Do not put payment secrets
or trust client-only entitlement flags.

## Secure OTA

Not implemented as live OTA. A release pipeline must provide signed artifacts,
key rotation, certificate/public-key pinning as appropriate, hash verification,
anti-rollback/version policy, interrupted-update recovery, power-loss safety,
and a tested rollback path. No update button should apply unsigned content.

## Hardware, accessibility, and field safety validation

These are execution gates, not code-only tasks:

1. Run unit/widget/analyzer checks on a complete Flutter SDK.
2. Test on each supported Android version/device with TalkBack and large-text
   settings.
3. Verify touch targets, focus order, contrast, Bengali pronunciation, audio
   routing, permission explanations, and disconnected-state messaging.
4. Use a controlled obstacle course with trained staff; measure latency, false
   negatives, false alarms, battery, heat, camera occlusion, rain/glare, and
   sensor loss.
5. Never test road crossing or unsupervised mobility with a participant.
6. Obtain ethics approval, informed consent, emergency procedures, trained
   Orientation & Mobility supervision, and a stop/fail-safe protocol before any
   user study.
7. The device remains an assistive aid, not a replacement for a white cane,
   guide dog, or established mobility technique.

## Current status

The codebase contains local adapters and explicit unavailable boundaries. The
hardware, store account, signing keys, backend, complete Flutter SDK, and
supervised validation evidence are not present in this workspace, so those
release gates remain open.
