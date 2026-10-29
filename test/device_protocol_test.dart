import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/core/device/device_protocol.dart';

void main() {
  final validMap = <String, dynamic>{
    'protocol_version': currentProtocolVersion,
    'message_type': 'battery_status',
    'timestamp': '2026-01-01T12:00:00Z',
    'session_id': 'session-1',
    'payload': {'percent': 80},
    'error_code': null,
  };

  test('parses and serializes a valid protocol envelope', () {
    final message = DeviceMessage.fromMap(validMap);

    expect(message.messageType, 'battery_status');
    expect(message.payload['percent'], 80);
    expect(DeviceMessage.fromJson(message.toJson()).sessionId, 'session-1');
  });

  test('rejects unsupported protocol versions', () {
    final invalid = {...validMap, 'protocol_version': '9.9'};

    expect(
      () => DeviceMessage.fromMap(invalid),
      throwsA(isA<DeviceProtocolException>()),
    );
  });

  test('rejects malformed payload and timestamp', () {
    expect(
      () => DeviceMessage.fromMap({...validMap, 'payload': []}),
      throwsA(isA<DeviceProtocolException>()),
    );
    expect(
      () => DeviceMessage.fromMap({...validMap, 'timestamp': 'not-a-date'}),
      throwsA(isA<DeviceProtocolException>()),
    );
  });

  test('marks events older than five seconds as stale', () {
    final receivedAt = DateTime.utc(2026, 1, 1, 12, 0, 10);
    final message = DeviceMessage.fromMap(validMap);
    final event = DeviceEvent(
      type: DeviceEventType.batteryStatus,
      receivedAt: receivedAt,
      message: message,
    );

    expect(event.isStale, isTrue);
  });

  test('security validator rejects missing authentication and replay',
      () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final validator = DeviceMessageSecurityValidator(
      authenticator: const _AcceptingAuthenticator(),
      clock: () => now,
    );
    final unauthenticated = DeviceMessage.fromMap(
        {...validMap, 'timestamp': now.toIso8601String()});
    await expectLater(
      validator.validate(unauthenticated),
      throwsA(isA<DeviceProtocolException>()),
    );

    final authenticated = DeviceMessage.fromMap({
      ...validMap,
      'timestamp': now.toIso8601String(),
      'authentication': {
        'key_id': 'test',
        'nonce': 'nonce-1',
        'signature': 'test'
      },
    });
    await validator.validate(authenticated);
    await expectLater(
      validator.validate(authenticated),
      throwsA(isA<DeviceProtocolException>()),
    );
  });
}

final class _AcceptingAuthenticator implements DeviceMessageAuthenticator {
  const _AcceptingAuthenticator();

  @override
  bool isAuthenticated(DeviceMessage message) => message.authentication != null;
}
