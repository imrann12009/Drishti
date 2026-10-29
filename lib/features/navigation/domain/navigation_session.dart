enum NavigationSessionState {
  idle,
  starting,
  demoActive,
  connecting,
  navigating,
  warning,
  paused,
  stopping,
  error,
}

class InvalidNavigationTransition implements Exception {
  InvalidNavigationTransition(this.from, this.to);

  final NavigationSessionState from;
  final NavigationSessionState to;

  @override
  String toString() => 'Invalid navigation transition: $from → $to';
}

class NavigationSession {
  NavigationSession({this.state = NavigationSessionState.idle});

  NavigationSessionState state;

  static const Map<NavigationSessionState, Set<NavigationSessionState>>
      allowedTransitions = {
    NavigationSessionState.idle: {
      NavigationSessionState.starting,
      NavigationSessionState.connecting,
    },
    NavigationSessionState.starting: {
      NavigationSessionState.demoActive,
      NavigationSessionState.error,
      NavigationSessionState.stopping,
    },
    NavigationSessionState.demoActive: {
      NavigationSessionState.warning,
      NavigationSessionState.paused,
      NavigationSessionState.stopping,
      NavigationSessionState.error,
    },
    NavigationSessionState.connecting: {
      NavigationSessionState.navigating,
      NavigationSessionState.error,
      NavigationSessionState.stopping,
    },
    NavigationSessionState.navigating: {
      NavigationSessionState.warning,
      NavigationSessionState.paused,
      NavigationSessionState.stopping,
      NavigationSessionState.error,
    },
    NavigationSessionState.warning: {
      NavigationSessionState.navigating,
      NavigationSessionState.demoActive,
      NavigationSessionState.paused,
      NavigationSessionState.stopping,
      NavigationSessionState.error,
    },
    NavigationSessionState.paused: {
      NavigationSessionState.demoActive,
      NavigationSessionState.navigating,
      NavigationSessionState.stopping,
      NavigationSessionState.error,
    },
    NavigationSessionState.stopping: {
      NavigationSessionState.idle,
      NavigationSessionState.error,
    },
    NavigationSessionState.error: {
      NavigationSessionState.idle,
      NavigationSessionState.starting,
      NavigationSessionState.connecting,
    },
  };

  void transitionTo(NavigationSessionState next) {
    if (next == state) {
      return;
    }

    final allowed = allowedTransitions[state] ?? const <NavigationSessionState>{};
    if (!allowed.contains(next)) {
      throw InvalidNavigationTransition(state, next);
    }
    state = next;
  }
}
