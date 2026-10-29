# DRISHTI device transport integration

## Implemented adapters

- `BleDeviceConnectionService` scans for a configured BLE service, connects,
  discovers configured event/command characteristics, subscribes to
  notifications, validates every JSON envelope, and writes commands.
- `WifiDeviceConnectionService` connects to a configured Raspberry Pi HTTP
  gateway, polls `/events/next`, reads `/device-info`, and posts `/commands`.
- Both adapters preserve the existing transport-neutral `DeviceMessage`
  validation boundary, cap incoming message size at 32 KiB, and reject malformed,
  stale/future, unauthenticated, or replayed data. A connection refuses to become
  usable without an injected authentication/replay validator.

## Required hardware configuration

The app does not invent these values. The hardware protocol must supply and
review:

- BLE service UUID;
- BLE event-notification characteristic UUID;
- BLE command-write characteristic UUID;
- Raspberry Pi HTTPS base URI and endpoint contract (isolated-network HTTP
  requires an explicit reviewed opt-in, and is not exposed by the UI);
- authentication/integrity and replay-protection mechanism;
- sensor payload schema and timestamp/clock policy;
- reconnect, timeout, stale-data, and power-loss behavior.

Until those values are approved and supplied, Device Mode must remain disabled
or use the unavailable service. A network response or BLE notification must not
be interpreted as a safe path without validated sensor semantics.

## Important dependency note

`flutter_blue_plus` supports BLE Central use, not Bluetooth Classic. Its package
license distinguishes nonprofit/educational use from commercial use. Confirm
that the intended commercial licensing is acceptable before release.

## Validation still required

Test with the actual Raspberry Pi and sensors for packet loss, malformed data,
stale timestamps, disconnect/reconnect, battery depletion, firmware mismatch,
permissions, and accessibility announcements. No hardware result is claimed
until those tests produce evidence.
