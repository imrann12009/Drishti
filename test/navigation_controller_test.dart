import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/features/navigation/application/navigation_controller.dart';
import 'package:drishti/features/navigation/domain/navigation_session.dart';

void main() {
  test('starts and stops a demo session', () async {
    final controller = NavigationController();

    controller.startDemo();
    expect(controller.state, NavigationSessionState.warning);
    expect(controller.source, NavigationSource.demo);
    expect(controller.alertHistory, hasLength(1));

    await controller.stop();
    expect(controller.state, NavigationSessionState.idle);
    expect(controller.source, NavigationSource.none);
  });

  test('pauses and resumes the demo timeline', () {
    final controller = NavigationController();

    controller.startDemo();
    controller.clearWarning();
    controller.pause();
    expect(controller.state, NavigationSessionState.paused);

    controller.resume();
    expect(controller.state, NavigationSessionState.demoActive);
  });

  test('suppresses repeated noncritical alerts but never critical alerts', () {
    var now = DateTime.utc(2026, 1, 1, 12);
    final controller = NavigationController(now: () => now);
    controller.startDemo();

    expect(
      controller.publishAlert(
        id: 'obstacle',
        message: 'Obstacle ahead',
        severity: AlertSeverity.warning,
      ),
      isTrue,
    );
    expect(
      controller.publishAlert(
        id: 'obstacle',
        message: 'Obstacle ahead',
        severity: AlertSeverity.warning,
      ),
      isFalse,
    );

    expect(
      controller.publishAlert(
        id: 'urgent',
        message: 'Stop now',
        severity: AlertSeverity.critical,
      ),
      isTrue,
    );
    now = now.add(const Duration(seconds: 1));
    expect(
      controller.publishAlert(
        id: 'urgent',
        message: 'Stop now',
        severity: AlertSeverity.critical,
      ),
      isTrue,
    );
  });

  test('muting noncritical alerts does not mute critical alerts', () {
    final controller = NavigationController(nonCriticalAlertsEnabled: false);
    controller.startDemo();

    expect(
      controller.publishAlert(
        id: 'info',
        message: 'Information',
        severity: AlertSeverity.info,
      ),
      isFalse,
    );
    expect(
      controller.publishAlert(
        id: 'critical',
        message: 'Stop',
        severity: AlertSeverity.critical,
      ),
      isTrue,
    );
  });
}
