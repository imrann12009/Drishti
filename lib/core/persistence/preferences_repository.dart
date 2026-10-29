import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable app preference contract. The concrete storage adapter can later use
/// SharedPreferences or another reviewed local store without coupling UI code
/// to a storage package.
abstract interface class PreferencesRepository {
  Future<AppPreferences> read();

  Future<void> write(AppPreferences preferences);
}

@immutable
final class AppPreferences {
  const AppPreferences({
    this.language = AppLanguage.bengali,
    this.speechRate = 0.5,
    this.volume = 0.8,
    this.nonCriticalPromptsEnabled = true,
    this.demoModeEnabled = true,
  });

  final AppLanguage language;
  final double speechRate;
  final double volume;
  final bool nonCriticalPromptsEnabled;
  final bool demoModeEnabled;

  AppPreferences copyWith({
    AppLanguage? language,
    double? speechRate,
    double? volume,
    bool? nonCriticalPromptsEnabled,
    bool? demoModeEnabled,
  }) {
    return AppPreferences(
      language: language ?? this.language,
      speechRate: speechRate ?? this.speechRate,
      volume: volume ?? this.volume,
      nonCriticalPromptsEnabled:
          nonCriticalPromptsEnabled ?? this.nonCriticalPromptsEnabled,
      demoModeEnabled: demoModeEnabled ?? this.demoModeEnabled,
    );
  }
}

enum AppLanguage { bengali, english }

/// Persistent local settings backed by the platform preference store.
///
/// This is suitable for non-sensitive UX settings only. It must not be used
/// for payment tokens, credentials, health data, or security keys.
final class SharedPreferencesRepository implements PreferencesRepository {
  SharedPreferencesRepository(this._preferences);

  final SharedPreferencesAsync _preferences;

  static const _languageKey = 'drishti.language';
  static const _speechRateKey = 'drishti.speechRate';
  static const _volumeKey = 'drishti.volume';
  static const _nonCriticalKey = 'drishti.nonCriticalPromptsEnabled';
  static const _demoModeKey = 'drishti.demoModeEnabled';

  @override
  Future<AppPreferences> read() async {
    final language = await _preferences.getString(_languageKey);
    return AppPreferences(
      language: language == AppLanguage.english.name
          ? AppLanguage.english
          : AppLanguage.bengali,
      speechRate: _clamp(
        await _preferences.getDouble(_speechRateKey) ?? 0.5,
      ),
      volume: _clamp(await _preferences.getDouble(_volumeKey) ?? 0.8),
      nonCriticalPromptsEnabled:
          await _preferences.getBool(_nonCriticalKey) ?? true,
      demoModeEnabled: await _preferences.getBool(_demoModeKey) ?? true,
    );
  }

  @override
  Future<void> write(AppPreferences preferences) async {
    await _preferences.setString(_languageKey, preferences.language.name);
    await _preferences.setDouble(_speechRateKey, _clamp(preferences.speechRate));
    await _preferences.setDouble(_volumeKey, _clamp(preferences.volume));
    await _preferences.setBool(
      _nonCriticalKey,
      preferences.nonCriticalPromptsEnabled,
    );
    await _preferences.setBool(_demoModeKey, preferences.demoModeEnabled);
  }

  double _clamp(double value) => value.clamp(0.0, 1.0).toDouble();
}

/// Deterministic repository for tests.
final class InMemoryPreferencesRepository implements PreferencesRepository {
  InMemoryPreferencesRepository({AppPreferences initial = const AppPreferences()})
      : _preferences = initial;

  AppPreferences _preferences;

  @override
  Future<AppPreferences> read() async => _preferences;

  @override
  Future<void> write(AppPreferences preferences) async {
    _preferences = preferences;
  }
}
