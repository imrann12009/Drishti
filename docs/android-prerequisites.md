# Android prerequisites for camera and device integrations

The repository contains Android platform scaffolding. It is configured with
Flutter's current Android values (compile/target SDK 36 and min SDK 24 in the
local Flutter 3.47.7 SDK), Java 17, CameraX/ML Kit, and Google Play Billing.
The debug manifest merge was inspected: it includes camera, Bluetooth,
Internet, and the billing permission. Microphone and legacy external-storage
permissions inherited from CameraX are explicitly removed because this app
does not record audio or save camera media.

Run from the project root:

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
```

Before a device build, review the generated Android manifest and add only the
permissions required by the selected release configuration:

- camera access for the live camera screen;
- microphone access only after the user explicitly starts Drishti AI voice input;
- Bluetooth scan/connect permissions for Android versions that require them;
- Internet access for the configured Raspberry Pi Wi-Fi gateway and backend.

The legacy Android (API 30 and lower) BLE location permission remains capped at
API 30 because Android requires it for discovery on those versions. Do not add
microphone or other location permissions without a separately reviewed feature.
Explain each runtime permission in accessible Bengali before requesting it.

`applicationId` and Kotlin package are both currently `com.example.drishti`.
This is a development placeholder, not a Play-ready identity. Choose a unique
final identifier before Play Console setup and update the backend environment
to the same value. Release signing is deliberately absent; do not use the
debug key for a production release.

The ML Kit object detector currently uses Android NV21 camera frames and
returns 2-D labels/bounding boxes. It does not provide depth in metres. Depth
requires a validated depth sensor or model and separate evaluation.

The BLE adapter requires the approved Raspberry Pi service UUID and event/
command characteristic UUIDs. The Wi-Fi adapter requires the approved HTTPS
(or isolated local HTTP) base URL, authentication, and endpoint schema. No
sample UUID, host, secret, or fake sensor payload is included.
