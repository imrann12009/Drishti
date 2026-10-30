import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'update_configuration.dart';

/// Download and verification for a direct Android APK release.
/// Android still displays its own confirmation UI; this class never silently
/// installs an APK and is deliberately unavailable on unsupported platforms.
final class AndroidApkInstaller {
  AndroidApkInstaller({http.Client? client})
      : _client = client ?? http.Client();

  static const _channel = MethodChannel('com.example.drishti/update_installer');
  final http.Client _client;

  final ValueNotifier<ApkDownloadProgress> progress =
      ValueNotifier(const ApkDownloadProgress.idle());
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  Future<ApkInstallResult> downloadVerifyAndOpen({
    required UpdateConfiguration configuration,
    required InstalledAppVersion installed,
  }) async {
    if (!Platform.isAndroid) {
      return const ApkInstallResult.failure(
          'এই আপডেট পদ্ধতি শুধু Android-এ সমর্থিত।');
    }
    if (!configuration.hasSafeDirectApkPath) {
      return const ApkInstallResult.failure(
          'নিরাপদ APK প্রকাশের তথ্য অসম্পূর্ণ।');
    }
    _cancelled = false;
    File? apk;
    try {
      apk = await _download(Uri.parse(configuration.downloadUrl!));
      if (_cancelled) {
        return const ApkInstallResult.failure('ডাউনলোড বাতিল করা হয়েছে।');
      }

      final actualChecksum = await _sha256(apk);
      if (!_sameFingerprint(actualChecksum, configuration.apkSha256!)) {
        await _deleteQuietly(apk);
        return const ApkInstallResult.failure(
            'APK-এর নিরাপত্তা যাচাই ব্যর্থ হয়েছে।');
      }

      final archive = await _inspect(apk.path);
      if (archive.packageName != installed.packageName ||
          archive.packageName != configuration.packageName) {
        await _deleteQuietly(apk);
        return const ApkInstallResult.failure(
            'ডাউনলোড করা APK এই DRISHTI অ্যাপের নয়।');
      }
      if (archive.versionCode <= installed.versionCode ||
          archive.versionCode != configuration.latestVersionCode) {
        await _deleteQuietly(apk);
        return const ApkInstallResult.failure(
            'APK সংস্করণটি প্রত্যাশিত নতুন সংস্করণ নয়।');
      }
      if (!_sameFingerprint(archive.signingCertificateSha256,
          configuration.signingCertificateSha256!)) {
        await _deleteQuietly(apk);
        return const ApkInstallResult.failure(
            'APK signing certificate যাচাই ব্যর্থ হয়েছে।');
      }

      final permitted =
          await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
              false;
      if (!permitted) {
        await _channel.invokeMethod<void>('openUnknownAppsSettings');
        return const ApkInstallResult.permissionRequired();
      }
      await _channel.invokeMethod<void>('installApk', {'path': apk.path});
      return const ApkInstallResult.installationStarted();
    } on SocketException {
      return const ApkInstallResult.failure('ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    } on TimeoutException {
      return const ApkInstallResult.failure(
          'ডাউনলোড শেষ হতে খুব বেশি সময় লাগছে। আবার চেষ্টা করুন।');
    } on PlatformException {
      return const ApkInstallResult.failure(
          'Android installer চালু করা যায়নি।');
    } catch (_) {
      return const ApkInstallResult.failure(
          'আপডেট ডাউনলোড বা যাচাই করা যায়নি।');
    } finally {
      progress.value = const ApkDownloadProgress.idle();
    }
  }

  Future<File> _download(Uri uri) async {
    progress.value = const ApkDownloadProgress.downloading(0, null);
    final request = http.Request('GET', uri)
      ..headers['Accept'] = 'application/vnd.android.package-archive';
    final response =
        await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != HttpStatus.ok) {
      throw const HttpException('Unexpected download status');
    }
    final directory = await getApplicationSupportDirectory();
    final updates =
        Directory('${directory.path}${Platform.pathSeparator}updates');
    await updates.create(recursive: true);
    final file =
        File('${updates.path}${Platform.pathSeparator}drishti-update.apk');
    final sink = file.openWrite(mode: FileMode.writeOnly);
    var received = 0;
    final total = response.contentLength;
    try {
      await for (final chunk in response.stream) {
        if (_cancelled) {
          await sink.close();
          await _deleteQuietly(file);
          throw const _CancelledDownload();
        }
        sink.add(chunk);
        received += chunk.length;
        progress.value = ApkDownloadProgress.downloading(received, total);
      }
      await sink.close();
      progress.value = ApkDownloadProgress.verifying(received);
      return file;
    } catch (_) {
      await sink.close();
      rethrow;
    }
  }

  Future<String> _sha256(File file) async {
    final sink = _DigestSink();
    final converter = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      converter.add(chunk);
    }
    converter.close();
    return sink.digest!.toString();
  }

  Future<_ApkArchive> _inspect(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'inspectApk',
      {'path': path},
    );
    if (result == null ||
        result['packageName'] is! String ||
        result['versionCode'] is! num ||
        result['signingCertificateSha256'] is! String) {
      throw const FormatException('Invalid Android archive metadata');
    }
    return _ApkArchive(
      packageName: result['packageName'] as String,
      versionCode: (result['versionCode'] as num).toInt(),
      signingCertificateSha256: result['signingCertificateSha256'] as String,
    );
  }

  bool _sameFingerprint(String left, String right) =>
      _normalise(left) == _normalise(right);

  String _normalise(String value) =>
      value.replaceAll(RegExp(r'[^a-fA-F0-9]'), '').toLowerCase();

  Future<void> _deleteQuietly(File file) async {
    if (await file.exists()) await file.delete();
  }

  void dispose() {
    _client.close();
    progress.dispose();
  }
}

final class _ApkArchive {
  const _ApkArchive({
    required this.packageName,
    required this.versionCode,
    required this.signingCertificateSha256,
  });

  final String packageName;
  final int versionCode;
  final String signingCertificateSha256;
}

final class _CancelledDownload implements Exception {
  const _CancelledDownload();
}

final class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

enum ApkDownloadStage { idle, downloading, verifying }

final class ApkDownloadProgress {
  const ApkDownloadProgress._(this.stage, this.receivedBytes, this.totalBytes);
  const ApkDownloadProgress.idle() : this._(ApkDownloadStage.idle, 0, null);
  const ApkDownloadProgress.downloading(int receivedBytes, int? totalBytes)
      : this._(ApkDownloadStage.downloading, receivedBytes, totalBytes);
  const ApkDownloadProgress.verifying(int receivedBytes)
      : this._(ApkDownloadStage.verifying, receivedBytes, null);

  final ApkDownloadStage stage;
  final int receivedBytes;
  final int? totalBytes;
  int? get percentage => totalBytes == null || totalBytes == 0
      ? null
      : ((receivedBytes / totalBytes!) * 100).round();
}

enum ApkInstallStatus { installationStarted, permissionRequired, failed }

final class ApkInstallResult {
  const ApkInstallResult._(this.status, this.message);
  const ApkInstallResult.installationStarted()
      : this._(ApkInstallStatus.installationStarted, null);
  const ApkInstallResult.permissionRequired()
      : this._(ApkInstallStatus.permissionRequired, null);
  const ApkInstallResult.failure(String message)
      : this._(ApkInstallStatus.failed, message);

  final ApkInstallStatus status;
  final String? message;
}
