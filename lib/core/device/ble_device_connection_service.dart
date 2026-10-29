import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'device_connection_service.dart';
import 'device_protocol.dart';

/// BLE adapter for a configured Raspberry Pi peripheral.
///
/// The Pi service and characteristic UUIDs must be provided by the approved
/// hardware protocol. This adapter validates every notification as a
/// DeviceMessage before exposing it to the app.
final class BleDeviceConnectionService implements DeviceConnectionService {
  BleDeviceConnectionService({
    required this.serviceUuid,
    required this.eventCharacteristicUuid,
    required this.commandCharacteristicUuid,
    this.messageValidator,
    this.license = License.nonprofit,
  });

  final Guid serviceUuid;
  final Guid eventCharacteristicUuid;
  final Guid commandCharacteristicUuid;
  final License license;
  /// Required before a connection is treated as a usable device transport.
  final DeviceMessageSecurityValidator? messageValidator;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _eventCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  StreamSubscription<List<int>>? _notifications;
  final StreamController<DeviceEvent> _events = StreamController.broadcast();
  DeviceConnectionStatus _status = DeviceConnectionStatus.disconnected;

  @override
  Future<List<DeviceDescriptor>> scanForDevices() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const DeviceUnavailableException('Bluetooth LE is not supported.');
    }
    final found = <String, DeviceDescriptor>{};
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final name = result.advertisementData.advName;
        if (name.isNotEmpty) {
          found[result.device.remoteId.str] = DeviceDescriptor(
            id: result.device.remoteId.str,
            displayName: name,
          );
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(
        withServices: [serviceUuid],
        timeout: const Duration(seconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return found.values.toList(growable: false);
    } finally {
      await subscription.cancel();
      await FlutterBluePlus.stopScan();
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    if (messageValidator == null) {
      throw const DeviceUnavailableException('BLE authentication and replay protection are not configured.');
    }
    _status = DeviceConnectionStatus.connecting;
    final device = BluetoothDevice.fromId(deviceId);
    try {
      await device.connect(license: license, timeout: const Duration(seconds: 20));
      final services = await device.discoverServices();
      final service = services.cast<BluetoothService?>().firstWhere(
            (item) => item?.serviceUuid == serviceUuid,
            orElse: () => null,
          );
      if (service == null) {
        throw const DeviceUnavailableException('Configured BLE service was not found.');
      }
      _eventCharacteristic = service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
            (item) => item?.characteristicUuid == eventCharacteristicUuid,
            orElse: () => null,
          );
      _commandCharacteristic = service.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
            (item) => item?.characteristicUuid == commandCharacteristicUuid,
            orElse: () => null,
          );
      if (_eventCharacteristic == null || _commandCharacteristic == null) {
        throw const DeviceUnavailableException('Configured BLE characteristics were not found.');
      }
      await _eventCharacteristic!.setNotifyValue(true);
      _notifications = _eventCharacteristic!.onValueReceived.listen(
        (value) => unawaited(_handleNotification(value)),
      );
      _device = device;
      _status = DeviceConnectionStatus.connected;
    } catch (_) {
      _status = DeviceConnectionStatus.disconnected;
      await device.disconnect();
      rethrow;
    }
  }

  Future<void> _handleNotification(List<int> value) async {
    try {
      if (value.length > 32 * 1024) return;
      final message = DeviceMessage.fromJson(utf8.decode(value));
      await messageValidator!.validate(message);
      final eventType = _eventType(message.messageType);
      _events.add(DeviceEvent(type: eventType, receivedAt: DateTime.now().toUtc(), message: message));
    } on Object {
      // Malformed device data is rejected and never surfaced as navigation data.
    }
  }

  DeviceEventType _eventType(String type) {
    switch (type) {
      case 'battery_status': return DeviceEventType.batteryStatus;
      case 'navigation_status': return DeviceEventType.navigationStatus;
      case 'obstacle_event': return DeviceEventType.obstacle;
      case 'device_health': return DeviceEventType.deviceHealth;
      case 'update_status': return DeviceEventType.updateStatus;
      default: return DeviceEventType.connectionStatus;
    }
  }

  @override
  Future<void> disconnect() async {
    await _notifications?.cancel();
    _notifications = null;
    final device = _device;
    _device = null;
    _status = DeviceConnectionStatus.disconnected;
    if (device != null) await device.disconnect();
  }

  @override
  Future<DeviceConnectionStatus> getConnectionStatus() async => _status;

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    throw const DeviceUnavailableException('Device info characteristic is not configured.');
  }

  @override
  Future<void> sendCommand(DeviceCommand command) async {
    final characteristic = _commandCharacteristic;
    if (_status != DeviceConnectionStatus.connected || characteristic == null) {
      throw const DeviceUnavailableException('BLE device is not connected.');
    }
    final payload = jsonEncode({'name': command.name, 'payload': command.payload});
    await characteristic.write(Uint8List.fromList(utf8.encode(payload)), withoutResponse: false);
  }

  @override
  Stream<DeviceEvent> subscribeToEvents() => _events.stream;

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}
