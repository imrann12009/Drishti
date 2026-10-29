import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/features/navigation/domain/navigation_session.dart';

void main() {
  test('allows a valid demo session sequence', () {
    final session = NavigationSession();

    session.transitionTo(NavigationSessionState.starting);
    session.transitionTo(NavigationSessionState.demoActive);
    session.transitionTo(NavigationSessionState.warning);
    session.transitionTo(NavigationSessionState.demoActive);
    session.transitionTo(NavigationSessionState.stopping);
    session.transitionTo(NavigationSessionState.idle);

    expect(session.state, NavigationSessionState.idle);
  });

  test('rejects invalid transitions', () {
    final session = NavigationSession();

    expect(
      () => session.transitionTo(NavigationSessionState.navigating),
      throwsA(isA<InvalidNavigationTransition>()),
    );
    expect(session.state, NavigationSessionState.idle);
  });
}
