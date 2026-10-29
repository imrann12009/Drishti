import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../persistence/preferences_repository.dart';

enum SpeechPriority { normal, warning, critical }

enum SpeechStatus { unavailable, ready, speaking }

final class SpeechMessage {
  const SpeechMessage({
    required this.id,
    required this.text,
    required this.priority,
    this.repeatAfter,
  });

  final String id;
  final String text;
  final SpeechPriority priority;
  final Duration? repeatAfter;
}

abstract interface class SpeechService {
  Future<SpeechStatus> initialize({required AppLanguage language});

  Future<void> speak(SpeechMessage message);

  Future<void> stopNonCritical();

  Future<void> stopAll();

  Future<SpeechStatus> getStatus();
}

/// Android/iOS platform TTS adapter. Bengali output depends on the device's
/// installed voice engine and must be verified on each target device.
final class FlutterTtsSpeechService implements SpeechService {
  FlutterTtsSpeechService({FlutterTts? engine})
      : _engine = engine ?? FlutterTts();

  final FlutterTts _engine;
  SpeechStatus _status = SpeechStatus.unavailable;
  double _rate = 0.5;
  double _volume = 0.8;

  @override
  Future<SpeechStatus> initialize({required AppLanguage language}) async {
    final locale = language == AppLanguage.bengali ? 'bn-BD' : 'en-US';
    // On browsers the system voice list may arrive after the first user tap.
    // Retry briefly before reporting that a language is unavailable.
    final supported = await _languageIsAvailable(locale);
    // Mobile browsers sometimes do not enumerate Bengali voices even though
    // the browser can synthesize speech after a user gesture. Give web
    // playback a chance; speak() still fails closed if the browser rejects it.
    if (supported != true && !kIsWeb) {
      _status = SpeechStatus.unavailable;
      return _status;
    }
    try {
      await _engine.setLanguage(locale);
      await _engine.setSpeechRate(_rate);
      await _engine.setVolume(_volume);
      await _engine.awaitSpeakCompletion(true);
      _status = SpeechStatus.ready;
      return _status;
    } on Object {
      _status = SpeechStatus.unavailable;
      return _status;
    }
  }

  Future<bool> _languageIsAvailable(String locale) async {
    final initial = await _engine.isLanguageAvailable(locale);
    if (initial == true || !kIsWeb) return initial == true;
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await _engine.isLanguageAvailable(locale) == true) return true;
    }
    return false;
  }

  Future<void> configure({double? rate, double? volume}) async {
    _rate = (rate ?? _rate).clamp(0.1, 1.0).toDouble();
    _volume = (volume ?? _volume).clamp(0.0, 1.0).toDouble();
    await _engine.setSpeechRate(_rate);
    await _engine.setVolume(_volume);
  }

  @override
  Future<void> speak(SpeechMessage message) async {
    if (_status == SpeechStatus.unavailable) {
      throw const SpeechUnavailableException(
          'Bengali TTS is not installed or available.');
    }
    _status = SpeechStatus.speaking;
    try {
      final result = await _engine.speak(message.text);
      if (result != 0) {
        _status = SpeechStatus.ready;
        return;
      }
    } on Object {
      // Normalize browser and platform engine failures for the UI.
    }
    _status = SpeechStatus.unavailable;
    throw const SpeechUnavailableException(
        'The platform TTS engine rejected speech.');
  }

  @override
  Future<void> stopNonCritical() async {
    await _engine.stop();
    _status = SpeechStatus.ready;
  }

  @override
  Future<void> stopAll() async {
    await _engine.stop();
    _status = SpeechStatus.ready;
  }

  @override
  Future<SpeechStatus> getStatus() async => _status;
}

/// Safe default until a tested Android TTS adapter is selected.
final class UnavailableSpeechService implements SpeechService {
  const UnavailableSpeechService();

  @override
  Future<SpeechStatus> initialize({required AppLanguage language}) async =>
      SpeechStatus.unavailable;

  @override
  Future<void> speak(SpeechMessage message) async {
    throw const SpeechUnavailableException(
      'Speech output is unavailable until a verified provider is configured.',
    );
  }

  @override
  Future<void> stopNonCritical() async {}

  @override
  Future<void> stopAll() async {}

  @override
  Future<SpeechStatus> getStatus() async => SpeechStatus.unavailable;
}

/// Priority queue with a small repeat suppression window. A real platform TTS
/// implementation can consume this queue without changing the app contract.
final class SpeechQueue {
  SpeechQueue({
    required SpeechService service,
    DateTime Function()? now,
  })  : _service = service,
        _now = now ?? DateTime.now;

  final SpeechService _service;
  final DateTime Function() _now;
  final List<SpeechMessage> _queue = <SpeechMessage>[];
  final Map<String, DateTime> _lastSpokenAt = <String, DateTime>{};
  bool _draining = false;
  bool _stopRequested = false;

  Future<void> enqueue(SpeechMessage message) async {
    final previous = _lastSpokenAt[message.id];
    if (previous != null &&
        message.repeatAfter != null &&
        _now().difference(previous) < message.repeatAfter!) {
      return;
    }

    if (message.priority == SpeechPriority.critical) {
      _queue.removeWhere((item) => item.priority != SpeechPriority.critical);
      _queue.insert(0, message);
    } else {
      _queue.add(message);
    }
    await _drain();
  }

  Future<void> muteNonCritical() async {
    _stopRequested = true;
    _queue.removeWhere((item) => item.priority != SpeechPriority.critical);
    await _service.stopNonCritical();
    _stopRequested = false;
  }

  Future<void> stopAll() async {
    _stopRequested = true;
    _queue.clear();
    await _service.stopAll();
    _stopRequested = false;
  }

  Future<void> _drain() async {
    if (_draining) {
      return;
    }
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_stopRequested) {
        final message = _queue.removeAt(0);
        _lastSpokenAt[message.id] = _now();
        try {
          await _service.speak(message);
        } on SpeechUnavailableException {
          _queue.clear();
          rethrow;
        }
      }
    } finally {
      _draining = false;
    }
  }
}

class SpeechUnavailableException implements Exception {
  const SpeechUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'SpeechUnavailableException: $message';
}
