import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/core/device/device_connection_service.dart';
import 'package:drishti/core/device/device_protocol.dart';

void main() {
  test('unavailable device service never claims a connection', () async {
    const service = UnavailableDeviceConnectionService();

    expect(
      await service.getConnectionStatus(),
      DeviceConnectionStatus.unavailable,
    );
    expect(await service.subscribeToEvents().isEmpty, isTrue);
    await expectLater(
      service.connect('unknown-device'),
      throwsA(isA<DeviceUnavailableException>()),
    );
  });
}
