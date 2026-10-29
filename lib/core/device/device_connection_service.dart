import 'dart:async';

import 'device_protocol.dart';

/// Boundary between the app and future BLE/Wi-Fi device transports.
///
/// This interface deliberately contains no BLE characteristic, Wi-Fi endpoint,
/// or sensor packet assumptions. Those details belong in a transport adapter
/// after the hardware protocol is approved.
abstract interface class DeviceConnectionService {
  Future<List<DeviceDescriptor>> scanForDevices();

  Future<void> connect(String deviceId);

  Future<void> disconnect();

  Future<DeviceConnectionStatus> getConnectionStatus();

  Future<DeviceInfo> getDeviceInfo();

  Future<void> sendCommand(DeviceCommand command);

  Stream<DeviceEvent> subscribeToEvents();
}

/// Safe default used until a real transport adapter is selected and tested.
/// It prevents the app from pretending that a device connection exists.
final class UnavailableDeviceConnectionService
    implements DeviceConnectionService {
  const UnavailableDeviceConnectionService();

  Never _unavailable() {
    throw const DeviceUnavailableException(
      'Device Mode is unavailable until a validated hardware adapter is added.',
    );
  }

  @override
  Future<List<DeviceDescriptor>> scanForDevices() async => _unavailable();

  @override
  Future<void> connect(String deviceId) async => _unavailable();

  @override
  Future<void> disconnect() async {}

  @override
  Future<DeviceConnectionStatus> getConnectionStatus() async =>
      DeviceConnectionStatus.unavailable;

  @override
  Future<DeviceInfo> getDeviceInfo() async => _unavailable();

  @override
  Future<void> sendCommand(DeviceCommand command) async => _unavailable();

  @override
  Stream<DeviceEvent> subscribeToEvents() => const Stream.empty();
}

class DeviceUnavailableException implements Exception {
  const DeviceUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'DeviceUnavailableException: $message';
}
