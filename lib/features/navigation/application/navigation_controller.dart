import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/device/device_connection_service.dart';
import '../../../core/device/device_protocol.dart';
import '../../../core/speech/speech_service.dart';
import '../domain/demo_scenario.dart';
import '../domain/navigation_session.dart';

enum NavigationSource { none, demo, device }

enum AlertSeverity { info, warning, critical }

final class NavigationAlert {
  const NavigationAlert({
    required this.id,
    required this.message,
    required this.severity,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String message;
  final AlertSeverity severity;
  final NavigationSource source;
  final DateTime createdAt;

  bool get isCritical => severity == AlertSeverity.critical;
}

/// Application-level coordinator for navigation sessions.
///
/// The controller owns lifecycle and safety rules. It does not know how BLE,
/// Wi-Fi, camera inference, or TTS work; those are injected behind interfaces.
final class NavigationController extends ChangeNotifier {
  NavigationController({
    NavigationSession? session,
    this.nonCriticalAlertsEnabled = true,
    SpeechService? speechService,
    DateTime Function()? now,
  })  : _session = session ?? NavigationSession(),
        _speechService = speechService,
        _now = now ?? DateTime.now;

  final NavigationSession _session;
  final SpeechService? _speechService;
  final DateTime Function() _now;
  final Map<String, DateTime> _lastAlertAt = <String, DateTime>{};
  NavigationAlert? _latestAlert;
  NavigationSource _source = NavigationSource.none;
  final List<NavigationAlert> _alertHistory = <NavigationAlert>[];
  Timer? _demoTimer;
  int _demoEventIndex = 0;
  bool nonCriticalAlertsEnabled;
  bool _disposed = false;

  NavigationSessionState get state => _session.state;
  NavigationSource get source => _source;
  NavigationAlert? get latestAlert => _latestAlert;
  List<NavigationAlert> get alertHistory => List.unmodifiable(_alertHistory);
  bool get isActive => state != NavigationSessionState.idle;
  bool get isPaused => state == NavigationSessionState.paused;

  void startDemo() {
    _demoTimer?.cancel();
    _demoEventIndex = 0;
    _alertHistory.clear();
    _session.transitionTo(NavigationSessionState.starting);
    _source = NavigationSource.demo;
    _session.transitionTo(NavigationSessionState.demoActive);
    _notify();
    _publishNextDemoEvent();
    _demoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (state == NavigationSessionState.paused || state == NavigationSessionState.idle) {
        return;
      }
      if (state == NavigationSessionState.warning) {
        clearWarning();
      }
      if (state == NavigationSessionState.demoActive) {
        _publishNextDemoEvent();
      }
    });
  }

  void _publishNextDemoEvent() {
    final event = DemoScenario.events[_demoEventIndex % DemoScenario.events.length];
    _demoEventIndex++;
    publishAlert(
      id: event.id,
      message: event.message,
      severity: _alertSeverity(event.severity),
      suppressionWindow: Duration.zero,
    );
  }

  AlertSeverity _alertSeverity(DemoEventSeverity severity) {
    switch (severity) {
      case DemoEventSeverity.info:
        return AlertSeverity.info;
      case DemoEventSeverity.warning:
        return AlertSeverity.warning;
      case DemoEventSeverity.critical:
        return AlertSeverity.critical;
    }
  }

  Future<void> startDevice({
    required String deviceId,
    required DeviceConnectionService service,
  }) async {
    _session.transitionTo(NavigationSessionState.connecting);
    _source = NavigationSource.device;
    _notify();

    try {
      await service.connect(deviceId);
      final status = await service.getConnectionStatus();
      if (status != DeviceConnectionStatus.connected) {
        throw const DeviceUnavailableException(
          'Device did not confirm a connected status.',
        );
      }
      _session.transitionTo(NavigationSessionState.navigating);
      _notify();
    } catch (_) {
      _session.transitionTo(NavigationSessionState.error);
      _notify();
      rethrow;
    }
  }

  Future<void> stop({DeviceConnectionService? service}) async {
    if (!isActive) {
      return;
    }

    _demoTimer?.cancel();
    _demoTimer = null;

    if (state == NavigationSessionState.error) {
      _session.transitionTo(NavigationSessionState.idle);
      _source = NavigationSource.none;
      _latestAlert = null;
      _notify();
      return;
    }

    _session.transitionTo(NavigationSessionState.stopping);
    _notify();

    try {
      if (_source == NavigationSource.device && service != null) {
        await service.disconnect();
      }
      _session.transitionTo(NavigationSessionState.idle);
      _source = NavigationSource.none;
      _latestAlert = null;
      _notify();
    } catch (_) {
      _session.transitionTo(NavigationSessionState.error);
      _notify();
      rethrow;
    }
  }

  void pause() {
    if (state != NavigationSessionState.demoActive &&
        state != NavigationSessionState.navigating &&
        state != NavigationSessionState.warning) {
      return;
    }
    _session.transitionTo(NavigationSessionState.paused);
    _notify();
  }

  void resume() {
    if (state != NavigationSessionState.paused) {
      return;
    }
    final next = _source == NavigationSource.demo
        ? NavigationSessionState.demoActive
        : NavigationSessionState.navigating;
    _session.transitionTo(next);
    _notify();
  }

  /// Publishes an alert unless a noncritical alert is muted or repeated too
  /// soon. Critical alerts always pass through this filter.
  bool publishAlert({
    required String id,
    required String message,
    required AlertSeverity severity,
    Duration suppressionWindow = const Duration(seconds: 8),
  }) {
    if (severity != AlertSeverity.critical && !nonCriticalAlertsEnabled) {
      return false;
    }

    final now = _now();
    final previous = _lastAlertAt[id];
    if (severity != AlertSeverity.critical &&
        previous != null &&
        now.difference(previous) < suppressionWindow) {
      return false;
    }

    _lastAlertAt[id] = now;
    _latestAlert = NavigationAlert(
      id: id,
      message: message,
      severity: severity,
      source: _source,
      createdAt: now,
    );
    _alertHistory.insert(0, _latestAlert!);
    if (_alertHistory.length > 12) {
      _alertHistory.removeLast();
    }

    if (state == NavigationSessionState.demoActive ||
        state == NavigationSessionState.navigating) {
      _session.transitionTo(NavigationSessionState.warning);
    }
    final speech = _speechService;
    if (speech != null) {
      unawaited(
        speech.speak(
          SpeechMessage(
            id: id,
            text: message,
            priority: severity == AlertSeverity.critical
                ? SpeechPriority.critical
                : SpeechPriority.warning,
            repeatAfter: suppressionWindow,
          ),
        ).catchError((_) {}),
      );
    }
    _notify();
    return true;
  }

  void clearWarning() {
    if (state != NavigationSessionState.warning) {
      return;
    }
    _latestAlert = null;
    _session.transitionTo(
      _source == NavigationSource.demo
          ? NavigationSessionState.demoActive
          : NavigationSessionState.navigating,
    );
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
