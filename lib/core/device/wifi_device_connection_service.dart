import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_connection_service.dart';
import 'device_protocol.dart';

/// Configurable Wi-Fi transport for a Raspberry Pi HTTP gateway.
///
/// The endpoint and authentication contract must be approved by the hardware
/// design. This class never invents an endpoint and rejects invalid messages.
final class WifiDeviceConnectionService implements DeviceConnectionService {
  WifiDeviceConnectionService({
    required this.baseUri,
    http.Client? client,
    this.authHeader,
    this.messageValidator,
    this.allowInsecureLocalHttp = false,
  }) : _client = client ?? http.Client();

  final Uri baseUri;
  final String? authHeader;
  final DeviceMessageSecurityValidator? messageValidator;
  /// Local HTTP is permitted only when an approved isolated-network design
  /// explicitly opts in. Production endpoints must be HTTPS.
  final bool allowInsecureLocalHttp;
  final http.Client _client;
  final StreamController<DeviceEvent> _events = StreamController.broadcast();
  Timer? _pollTimer;
  DeviceConnectionStatus _status = DeviceConnectionStatus.disconnected;

  Map<String, String> get _headers => {
        'accept': 'application/json',
        if (authHeader != null) 'authorization': authHeader!,
      };

  @override
  Future<List<DeviceDescriptor>> scanForDevices() async => const [];

  @override
  Future<void> connect(String deviceId) async {
    if (messageValidator == null || authHeader == null || authHeader!.trim().isEmpty) {
      throw const DeviceUnavailableException('Wi-Fi authentication and replay protection are not configured.');
    }
    if (baseUri.scheme != 'https' && !(allowInsecureLocalHttp && baseUri.scheme == 'http')) {
      throw const DeviceUnavailableException('Wi-Fi device endpoint must use HTTPS.');
    }
    _status = DeviceConnectionStatus.connecting;
    final response = await _client.get(baseUri.resolve('/health'), headers: _headers);
    if (response.statusCode != 200) {
      _status = DeviceConnectionStatus.disconnected;
      throw const DeviceUnavailableException('Raspberry Pi Wi-Fi health check failed.');
    }
    _status = DeviceConnectionStatus.connected;
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_pollEvents());
    });
  }

  Future<void> _pollEvents() async {
    if (_status != DeviceConnectionStatus.connected) return;
    try {
      final response = await _client.get(baseUri.resolve('/events/next'), headers: _headers);
      if (response.statusCode != 200 || response.body.trim().isEmpty) return;
      if (response.body.length > 32 * 1024) return;
      final message = DeviceMessage.fromJson(response.body);
      await messageValidator!.validate(message);
      _events.add(DeviceEvent(
        type: _eventType(message.messageType),
        receivedAt: DateTime.now().toUtc(),
        message: message,
      ));
    } on Object {
      // Network loss or invalid payload keeps the state non-authoritative.
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
    _pollTimer?.cancel();
    _pollTimer = null;
    _status = DeviceConnectionStatus.disconnected;
  }

  @override
  Future<DeviceConnectionStatus> getConnectionStatus() async => _status;

  @override
  Future<DeviceInfo> getDeviceInfo() async {
    final response = await _client.get(baseUri.resolve('/device-info'), headers: _headers);
    if (response.statusCode != 200) {
      throw const DeviceUnavailableException('Raspberry Pi device info is unavailable.');
    }
    final map = jsonDecode(response.body);
    if (map is! Map<String, dynamic>) {
      throw const DeviceUnavailableException('Invalid Raspberry Pi device info.');
    }
    return DeviceInfo(
      deviceId: map['device_id'] as String? ?? 'unknown',
      hardwareVersion: map['hardware_version'] as String? ?? 'unknown',
      softwareVersion: map['software_version'] as String? ?? 'unknown',
      protocolVersion: map['protocol_version'] as String? ?? 'unknown',
    );
  }

  @override
  Future<void> sendCommand(DeviceCommand command) async {
    if (_status != DeviceConnectionStatus.connected) {
      throw const DeviceUnavailableException('Wi-Fi device is not connected.');
    }
    final response = await _client.post(
      baseUri.resolve('/commands'),
      headers: {..._headers, 'content-type': 'application/json'},
      body: jsonEncode({'name': command.name, 'payload': command.payload}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DeviceUnavailableException('Raspberry Pi command was rejected.');
    }
  }

  @override
  Stream<DeviceEvent> subscribeToEvents() => _events.stream;

  Future<void> dispose() async {
    await disconnect();
    _client.close();
    await _events.close();
  }
}
