import 'dart:convert';

/// Read-only release metadata published by the DRISHTI release team.
///
/// It is data, never executable code. A release is only eligible for a direct
/// Android install when all of the security fields required by the client are
/// present and valid.
final class UpdateConfiguration {
  const UpdateConfiguration({
    required this.updateAvailable,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.minimumSupportedVersionCode,
    required this.forceUpdate,
    required this.updateTitle,
    required this.updateDescription,
    required this.releaseDate,
    required this.releaseNotes,
    this.downloadUrl,
    this.apkSha256,
    this.signingCertificateSha256,
    this.packageName,
    this.apkSizeBytes,
    this.distribution = UpdateDistribution.directApk,
    this.playStoreUrl,
  });

  final bool updateAvailable;
  final int latestVersionCode;
  final String latestVersionName;
  final int minimumSupportedVersionCode;
  final bool forceUpdate;
  final String updateTitle;
  final String updateDescription;
  final String releaseDate;
  final List<String> releaseNotes;
  final String? downloadUrl;
  final String? apkSha256;
  final String? signingCertificateSha256;
  final String? packageName;
  final int? apkSizeBytes;
  final UpdateDistribution distribution;
  final String? playStoreUrl;

  bool isNewerThan(int installedVersionCode) =>
      updateAvailable && latestVersionCode > installedVersionCode;

  bool requiresUpdateFor(int installedVersionCode) =>
      isNewerThan(installedVersionCode) &&
      (forceUpdate || installedVersionCode < minimumSupportedVersionCode);

  /// A direct install needs a secure URL plus integrity and signer pins.
  bool get hasSafeDirectApkPath {
    final uri = Uri.tryParse(downloadUrl ?? '');
    return distribution == UpdateDistribution.directApk &&
        uri != null &&
        uri.isScheme('https') &&
        _isSha256(apkSha256) &&
        _isSha256(signingCertificateSha256) &&
        (packageName?.isNotEmpty ?? false);
  }

  bool get hasValidPlayPath {
    final uri = Uri.tryParse(playStoreUrl ?? '');
    return distribution == UpdateDistribution.googlePlay &&
        uri != null &&
        uri.isScheme('https');
  }

  bool get hasUsableDeliveryPath => hasSafeDirectApkPath || hasValidPlayPath;

  Map<String, Object?> toJson() => {
        'updateAvailable': updateAvailable,
        'latestVersionCode': latestVersionCode,
        'latestVersionName': latestVersionName,
        'minimumSupportedVersionCode': minimumSupportedVersionCode,
        'forceUpdate': forceUpdate,
        'updateTitle': updateTitle,
        'updateDescription': updateDescription,
        'releaseDate': releaseDate,
        'releaseNotes': releaseNotes,
        'downloadUrl': downloadUrl,
        'apkSha256': apkSha256,
        'signingCertificateSha256': signingCertificateSha256,
        'packageName': packageName,
        'apkSizeBytes': apkSizeBytes,
        'distribution': distribution.name,
        'playStoreUrl': playStoreUrl,
      };

  String encode() => jsonEncode(toJson());

  static UpdateConfiguration? decode(String encoded) {
    try {
      final raw = jsonDecode(encoded);
      if (raw is! Map<String, dynamic>) return null;
      return fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  static UpdateConfiguration? fromJson(Map<String, dynamic> raw) {
    final latestCode = _asInt(raw['latestVersionCode']);
    final minimumCode = _asInt(raw['minimumSupportedVersionCode']);
    final versionName = raw['latestVersionName'];
    final available = raw['updateAvailable'];
    if (latestCode == null ||
        minimumCode == null ||
        versionName is! String ||
        available is! bool ||
        latestCode < 1 ||
        minimumCode < 1) {
      return null;
    }
    final notes = raw['releaseNotes'];
    final distributionName = raw['distribution'];
    return UpdateConfiguration(
      updateAvailable: available,
      latestVersionCode: latestCode,
      latestVersionName: versionName,
      minimumSupportedVersionCode: minimumCode,
      forceUpdate: raw['forceUpdate'] == true,
      updateTitle: raw['updateTitle'] is String
          ? raw['updateTitle'] as String
          : 'DRISHTI আপডেট',
      updateDescription: raw['updateDescription'] is String
          ? raw['updateDescription'] as String
          : '',
      releaseDate:
          raw['releaseDate'] is String ? raw['releaseDate'] as String : '',
      releaseNotes: notes is List
          ? notes.whereType<String>().take(20).toList(growable: false)
          : const [],
      downloadUrl: raw['downloadUrl'] as String?,
      apkSha256: raw['apkSha256'] as String?,
      signingCertificateSha256: raw['signingCertificateSha256'] as String?,
      packageName: raw['packageName'] as String?,
      apkSizeBytes: _asInt(raw['apkSizeBytes']),
      distribution: distributionName == UpdateDistribution.googlePlay.name
          ? UpdateDistribution.googlePlay
          : UpdateDistribution.directApk,
      playStoreUrl: raw['playStoreUrl'] as String?,
    );
  }

  static int? _asInt(Object? value) => switch (value) {
        int value => value,
        num value => value.toInt(),
        String value => int.tryParse(value),
        _ => null,
      };

  static bool _isSha256(String? value) =>
      value != null && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value);
}

enum UpdateDistribution { directApk, googlePlay }

final class InstalledAppVersion {
  const InstalledAppVersion({
    required this.versionCode,
    required this.versionName,
    required this.packageName,
  });

  final int versionCode;
  final String versionName;
  final String packageName;
}

enum UpdateStatus {
  checking,
  upToDate,
  available,
  required,
  unavailable,
  error
}

final class UpdateSnapshot {
  const UpdateSnapshot({
    required this.status,
    required this.installed,
    this.configuration,
    this.message,
    this.fromCache = false,
  });

  final UpdateStatus status;
  final InstalledAppVersion installed;
  final UpdateConfiguration? configuration;
  final String? message;
  final bool fromCache;

  bool get canUpdate =>
      (status == UpdateStatus.available || status == UpdateStatus.required) &&
      (configuration?.hasUsableDeliveryPath ?? false);
}
