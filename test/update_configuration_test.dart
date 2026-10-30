import 'package:drishti/core/updates/update_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  UpdateConfiguration config({
    int latestVersionCode = 2,
    int minimumSupportedVersionCode = 1,
    bool updateAvailable = true,
    bool forceUpdate = false,
    String? downloadUrl = 'https://releases.example.test/drishti.apk',
    String? checksum =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  }) =>
      UpdateConfiguration(
        updateAvailable: updateAvailable,
        latestVersionCode: latestVersionCode,
        latestVersionName: '1.0.1',
        minimumSupportedVersionCode: minimumSupportedVersionCode,
        forceUpdate: forceUpdate,
        updateTitle: 'DRISHTI নতুন আপডেট',
        updateDescription: '',
        releaseDate: '2026-10-30',
        releaseNotes: const [],
        downloadUrl: downloadUrl,
        apkSha256: checksum,
        signingCertificateSha256: checksum,
        packageName: 'com.example.drishti',
      );

  test('does not advertise a version that is already installed', () {
    final release = config();

    expect(release.isNewerThan(2), isFalse);
    expect(release.isNewerThan(3), isFalse);
  });

  test('recognises an optional newer release with a secure direct path', () {
    final release = config();

    expect(release.isNewerThan(1), isTrue);
    expect(release.requiresUpdateFor(1), isFalse);
    expect(release.hasSafeDirectApkPath, isTrue);
  });

  test('requires an update below the published minimum version', () {
    final release = config(minimumSupportedVersionCode: 2);

    expect(release.requiresUpdateFor(1), isTrue);
  });

  test('rejects a release without a HTTPS URL or checksum', () {
    expect(config(downloadUrl: 'http://example.test/update.apk').hasSafeDirectApkPath,
        isFalse);
    expect(config(checksum: null).hasSafeDirectApkPath, isFalse);
  });
}
