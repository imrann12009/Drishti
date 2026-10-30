import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'update_configuration.dart';
import 'update_configuration_source.dart';

/// Coordinates version checks, a small local cache, and concurrent callers.
/// It does not download or install anything by itself.
final class UpdateManager {
  UpdateManager({
    required UpdateConfigurationSource source,
    Future<PackageInfo> Function()? packageInfo,
    SharedPreferencesAsync? preferences,
    Future<List<ConnectivityResult>> Function()? connectivity,
    DateTime Function()? clock,
  })  : _source = source,
        _packageInfo = packageInfo ?? PackageInfo.fromPlatform,
        _preferences = preferences ?? SharedPreferencesAsync(),
        _connectivity = connectivity ?? Connectivity().checkConnectivity,
        _clock = clock ?? DateTime.now;

  static const _cacheValueKey = 'update_configuration_v1';
  static const _cacheTimeKey = 'update_configuration_v1_time';
  static const _minimumRemoteInterval = Duration(minutes: 15);

  final UpdateConfigurationSource _source;
  final Future<PackageInfo> Function() _packageInfo;
  final SharedPreferencesAsync _preferences;
  final Future<List<ConnectivityResult>> Function() _connectivity;
  final DateTime Function() _clock;

  final ValueNotifier<UpdateSnapshot?> snapshot = ValueNotifier(null);
  Future<UpdateSnapshot>? _inFlight;
  DateTime? _lastRemoteCheck;

  Future<UpdateSnapshot> check({bool refresh = false}) {
    final active = _inFlight;
    if (active != null) return active;
    final future = _check(refresh: refresh);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<UpdateSnapshot> _check({required bool refresh}) async {
    final installed = await _installedVersion();
    final cached = await _readCached();
    final current = _snapshotFor(installed, cached, fromCache: true);
    snapshot.value = UpdateSnapshot(
      status: UpdateStatus.checking,
      installed: installed,
      configuration: cached,
      fromCache: cached != null,
    );

    final recentlyChecked = _lastRemoteCheck != null &&
        _clock().difference(_lastRemoteCheck!) < _minimumRemoteInterval;
    if ((!refresh && recentlyChecked) || await _isOffline()) {
      snapshot.value = current;
      return current;
    }

    try {
      final remote = await _source.fetch().timeout(const Duration(seconds: 12));
      _lastRemoteCheck = _clock();
      if (remote != null) await _cache(remote);
      final result = _snapshotFor(installed, remote, fromCache: false);
      snapshot.value = result;
      return result;
    } on TimeoutException {
      return _withErrorOrCache(
          installed, cached, 'আপডেট তথ্য পেতে সময় শেষ হয়েছে।');
    } catch (_) {
      return _withErrorOrCache(installed, cached,
          'আপডেট তথ্য এখন পাওয়া যাচ্ছে না। পরে আবার চেষ্টা করুন।');
    }
  }

  Future<bool> _isOffline() async {
    final results = await _connectivity();
    return results.isEmpty ||
        results.every((item) => item == ConnectivityResult.none);
  }

  UpdateSnapshot _withErrorOrCache(
    InstalledAppVersion installed,
    UpdateConfiguration? cached,
    String message,
  ) {
    final cacheResult = _snapshotFor(installed, cached, fromCache: true);
    final result = cached == null
        ? UpdateSnapshot(
            status: UpdateStatus.error, installed: installed, message: message)
        : UpdateSnapshot(
            status: cacheResult.status,
            installed: installed,
            configuration: cached,
            message: message,
            fromCache: true,
          );
    snapshot.value = result;
    return result;
  }

  UpdateSnapshot _snapshotFor(
    InstalledAppVersion installed,
    UpdateConfiguration? configuration, {
    required bool fromCache,
  }) {
    if (configuration == null) {
      return UpdateSnapshot(
        status: UpdateStatus.unavailable,
        installed: installed,
        message: 'এখন কোনো প্রকাশিত আপডেট তথ্য নেই।',
        fromCache: fromCache,
      );
    }
    if (!configuration.isNewerThan(installed.versionCode)) {
      return UpdateSnapshot(
        status: UpdateStatus.upToDate,
        installed: installed,
        configuration: configuration,
        fromCache: fromCache,
      );
    }
    if (!configuration.hasUsableDeliveryPath) {
      return UpdateSnapshot(
        status: UpdateStatus.unavailable,
        installed: installed,
        configuration: configuration,
        message:
            'নতুন সংস্করণ প্রকাশিত হলেও নিরাপদ ডাউনলোড বা Play পথ এখনো দেওয়া হয়নি।',
        fromCache: fromCache,
      );
    }
    return UpdateSnapshot(
      status: configuration.requiresUpdateFor(installed.versionCode)
          ? UpdateStatus.required
          : UpdateStatus.available,
      installed: installed,
      configuration: configuration,
      fromCache: fromCache,
    );
  }

  Future<InstalledAppVersion> _installedVersion() async {
    final info = await _packageInfo();
    return InstalledAppVersion(
      versionCode: int.tryParse(info.buildNumber) ?? 0,
      versionName: info.version,
      packageName: info.packageName,
    );
  }

  Future<UpdateConfiguration?> _readCached() async =>
      UpdateConfiguration.decode(
          await _preferences.getString(_cacheValueKey) ?? '');

  Future<void> _cache(UpdateConfiguration configuration) async {
    await _preferences.setString(_cacheValueKey, configuration.encode());
    await _preferences.setString(_cacheTimeKey, _clock().toIso8601String());
  }

  void dispose() => snapshot.dispose();
}
