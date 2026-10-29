# DRISHTI

Accessible Flutter foundation for **DRISHTI — an AI Pocket Navigator for Blind and Visually Impaired People**.

## Current scope

Stages A–C are represented:

- architecture and safety assumptions
- Flutter/Dart project baseline
- accessible onboarding flow
- home dashboard with clearly labelled Demo Mode
- navigation session state machine
- settings for language, speed, volume, and alert preferences
- explicit device, subscription, update, privacy, and help boundaries
- Bengali TTS adapter using the device's installed `bn-BD` voice when available
- persistent non-sensitive settings through a reviewed local preference adapter
- Android camera preview plus ML Kit 2-D object detection stream
- configurable Raspberry Pi BLE and Wi-Fi transport adapters behind protocol validation
- Google Play subscription adapter and planned DRISHTI PRO catalog; live billing remains gated on Play Console and backend verification
- Drishti AI Chat with secure server-side model gateway, contextual Bangla/English text chat, optional voice input, replay/auto-read TTS, and an explicit hands-free turn-by-turn mode
- production-readiness gates for hardware, billing verification, secure OTA, accessibility, and field safety
- unit tests for valid and invalid navigation transitions
- provisional device protocol validation with malformed-message and stale-data tests
- device communication abstraction that refuses to claim hardware availability
- preferences repository contract with deterministic in-memory implementation for tests
- navigation controller with source tracking, pause/resume, stop, safety alert suppression, repeatable Demo Mode events, and bounded event history
- speech service boundary with priority queue and repeated-warning suppression
- feature registry with Free/Pro provider boundary (mock provider only)

No physical Raspberry Pi/sensor is connected in this workspace. The camera and 2-D ML Kit stream are implemented as Android adapters, but require a complete Android build and device validation. Depth estimation, live AI service configuration, live payment entitlement, firmware update, and subscription backend remain unavailable.

## Toolchain prerequisite

The project uses the Flutter SDK at `/Users/imran/flutter`. It is not on the shell PATH, so run it explicitly or add `/Users/imran/flutter/bin` to PATH. Android command-line tools/licenses are still incomplete according to `flutter doctor -v`.

The directory is source-first. From the project root, generate the standard platform scaffolding once if it is not already present:

```bash
flutter create --platforms=android .
flutter pub get
flutter analyze
flutter test
flutter run
```

For Android-first development, use Java 17 for Gradle/Android builds.

## Source map

```text
lib/
├── app.dart
├── main.dart
├── core/
│   ├── device/
│   │   ├── device_connection_service.dart
│   │   └── device_protocol.dart
│   ├── persistence/preferences_repository.dart
│   └── theme/app_theme.dart
└── features/
    ├── help/presentation/help_screen.dart
    ├── home/presentation/home_screen.dart
    ├── navigation/domain/navigation_session.dart
    ├── onboarding/presentation/onboarding_screen.dart
    └── settings/presentation/settings_screen.dart

test/
├── device_connection_service_test.dart
├── device_protocol_test.dart
├── feature_registry_test.dart
├── navigation_controller_test.dart
├── navigation_session_test.dart
├── preferences_repository_test.dart
├── speech_queue_test.dart
└── widget_test.dart

docs/device_protocol.md
ARCHITECTURE.md
analysis_options.yaml
pubspec.yaml
```

## Accessibility decisions

- Large primary controls with a minimum height of 56 logical pixels.
- High-contrast navy/blue text and surfaces.
- Screen-reader labels for progress, demo status, actions, and icons.
- Safety messages are written as text and icon plus text; colour is not the only warning channel.
- Critical alerts cannot be disabled in the prototype.
- Demo/live distinction is present wherever navigation status is shown.
- UI avoids claiming that a simulated or future AI output establishes crossing safety.

## Verified local checks

The following commands were run against this repository:

```bash
/Users/imran/flutter/bin/flutter doctor -v
/Users/imran/flutter/bin/flutter pub get
/Users/imran/flutter/bin/flutter analyze
/Users/imran/flutter/bin/flutter test
cd backend/google-play-verifier && npm test
cd server && npm run check && npm test
```

Results: dependency resolution succeeded; analyzer reported **No issues found**;
Flutter tests passed (**19 tests**); the legacy payment backend tests passed
(**6 tests**); the Groq TypeScript AI server type-check and **3 tests** passed; and
`flutter build apk --debug` succeeded. The APK is
[`build/app/outputs/flutter-apk/app-debug.apk`](build/app/outputs/flutter-apk/app-debug.apk)
(202 MiB; SHA-256 `1b6296479de15edff1d1f58b7010f9a563a8b09120e7dfae3608bbdcb46e84da`).
The build warns that `flutter_tts` still applies the legacy Kotlin Gradle
Plugin; it does not fail this build but must be tracked before a future Flutter
version makes Built-in Kotlin mandatory. These checks do not validate a
physical camera, Raspberry Pi, real Play purchase, or OTA.

## Automated tests

Expected command:

```bash
flutter test
```

Current tests cover the navigation state machine, protocol parsing/rejection,
stale-data/authentication/replay rules, and the preferences repository contract.

## Manual verification checklist

1. Complete onboarding with a screen reader enabled.
2. Confirm each primary button is easy to find and activate.
3. Confirm the dashboard says `ডেমো মোড` and explains that data is simulated.
4. Start and stop Demo Navigation; confirm the visible Stop control remains available.
5. Open Settings and confirm critical alerts cannot be switched off.
6. Adjust speed and volume sliders and confirm their values are announced.
7. Check that warning text is understandable without colour perception.
8. Rotate or resize the device and confirm content remains reachable without horizontal clipping.
9. Test TalkBack focus order, minimum touch targets, and Bengali text pronunciation on a target Android device.
10. Record any device-specific TTS behavior; do not document offline Bengali support until verified.

## Known limitations

- Android scaffolding is present. The temporary Android application ID remains
  `com.example.drishti`; choose the final unique ID before Play Console setup
  and configure the backend to match it.
- The camera and device quick actions now open their integration screens; hardware-specific UUID/URL configuration is still required.
- Demo Mode now emits a repeatable local event timeline, supports pause/resume, and keeps a bounded in-session event history. Events remain explicitly simulated and are not live sensor data.
- Preferences use the persistent adapter for app UX settings; payment credentials and security keys are not stored there.
- Device authentication, subscription receipt verification, analytics, and secure updates remain production services to be configured.
- Navigation controller, speech queue, camera detector, and feature registry are implemented as testable boundaries; they still require platform/device validation.
- BLE and Wi-Fi adapters exist, but require the approved Raspberry Pi UUIDs, endpoint contract, authentication, and sensor schema.
- Depth estimation remains unavailable until a validated depth sensor or model is integrated and benchmarked.
- A debug APK may be built only after the local Android SDK command-line tools
  and licenses are repaired. Release signing is intentionally not configured;
  a real keystore is required before any release bundle.
- AI Chat has a dedicated Groq server in `server/`, but cannot reply until its
  server-only `GROQ_API_KEY` is configured and it is deployed behind a
  production HTTPS/authentication boundary. See `docs/ai-chat-setup.md`; no
  provider key belongs in the app.
