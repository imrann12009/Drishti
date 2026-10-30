# DRISHTI Android app-update publishing

This is an app update mechanism, not a Raspberry Pi firmware/OTA mechanism.
The existing hardware OTA boundary remains disabled.

## One-time Firebase setup

1. Create/select the production Firebase project and add Android app
   `com.example.drishti`. Change that temporary package identifier **before**
   creating a Play Console production app; every released APK must then retain
   the chosen final identifier.
2. Download `google-services.json` from Firebase and place it at
   `android/app/google-services.json`. It is application configuration, not an
   Admin credential. Do not commit service-account JSON or private keys.
3. Enable Cloud Firestore in production mode and deploy
   [`firestore.rules`](firestore.rules). The app can read only
   `public_config/app_update`; no Flutter client can publish a release.
4. Publish release metadata only from a protected CI workflow or an internal
   developer tool backed by Firebase Admin SDK. Require Firebase Authentication
   and server-side authorization there. Do not give an APK client write access.

## Published Firestore document

Create exactly this document path: `public_config/app_update`.

```json
{
  "updateAvailable": false,
  "latestVersionCode": 1,
  "latestVersionName": "0.1.0",
  "minimumSupportedVersionCode": 1,
  "forceUpdate": false,
  "updateTitle": "DRISHTI নতুন আপডেট",
  "updateDescription": "উন্নতি ও সংশোধন।",
  "releaseDate": "2026-10-30",
  "releaseNotes": ["নতুন সুবিধা", "পারফরম্যান্স উন্নতি", "বাগ সংশোধন"],
  "distribution": "directApk",
  "downloadUrl": "https://releases.example.com/drishti/app-release.apk",
  "apkSha256": "64-character-lowercase-or-uppercase-SHA-256-of-the-APK",
  "signingCertificateSha256": "64-character-SHA-256-of-the-release-signing-certificate",
  "packageName": "com.example.drishti",
  "apkSizeBytes": 12345678
}
```

The URLs and checksum above are placeholders only. Never publish them as a
real release. `latestVersionCode` must be larger than every previously
distributed version. Never use this system to distribute a downgrade.

### Direct APK publishing checklist

1. Build a release-signed APK with the same final `applicationId` and signing
   certificate as users’ installed app.
2. Host the immutable APK at an official **HTTPS** URL you control. Do not use
   a mutable redirect, arbitrary file host, or an untrusted mirror.
3. Calculate the artifact checksum without printing a signing key, for example:

   ```sh
   shasum -a 256 path/to/app-release.apk
   ```

4. Obtain the SHA-256 certificate fingerprint from the production keystore in
   a secure release environment. It is a public fingerprint, not the private
   key. Publish its normalized 64-hex-character value.
5. Confirm the APK archive package name, versionCode and signer locally before
   setting `updateAvailable: true`.
6. First test a non-forced release on a separate test track/device. Test bad
   URL, interrupted download, bad checksum, bad signer, old version, denied
   installation permission and user cancellation.

The client downloads only to its app-private directory, hashes the artifact,
checks archive package/version/signer, and opens Android’s own installer. It
does not silently install, replace Android consent, or report success before
the user completes installation.

### Google Play distribution

Use this document instead when the installed app is from Google Play:

```json
{
  "updateAvailable": true,
  "latestVersionCode": 42,
  "latestVersionName": "1.2.0",
  "minimumSupportedVersionCode": 40,
  "forceUpdate": false,
  "updateTitle": "DRISHTI নতুন আপডেট",
  "updateDescription": "উন্নতি ও সংশোধন।",
  "releaseDate": "2026-10-30",
  "releaseNotes": ["উন্নতি"],
  "distribution": "googlePlay",
  "playStoreUrl": "https://play.google.com/store/apps/details?id=com.example.drishti"
}
```

The app invokes the official Google Play in-app update API. Google Play, not
Firestore, remains the authority for availability, download, and installation.

## Client behavior

- Version comparison uses Android `versionCode` / Flutter build number, never
  a semantic version name.
- Successful configuration is cached locally and requests are deduplicated.
  Startup/resume uses the cache as an offline fallback; opening the update
  screen or pull-to-refresh asks Firestore again.
- A red badge appears only for enabled, newer releases that have a valid
  delivery path.
- A forced-update message appears only when a newer secure release exists and
  `forceUpdate` is true or the installed version is below
  `minimumSupportedVersionCode`. It never traps a user in an endless loop.

## Still required before production

- A real Firebase project and `google-services.json` for the final Android ID.
- A protected server/CI release publisher with Firebase Admin credentials held
  only in secret storage.
- Final package name, production signing keystore, verified certificate
  fingerprint, official HTTPS artifact hosting and tested signed APK.
- A physical-device test of Android package installer behavior and a Play
  internal-track test if using Play distribution.
