import 'dart:convert';

import 'dart:async';

const currentProtocolVersion = '0.1-provisional';

/// Transport-neutral envelope. The version remains provisional until the
/// hardware team approves authentication, replay protection, and schemas.
final class DeviceMessage {
  const DeviceMessage({
    required this.protocolVersion,
    required this.messageType,
    required this.timestamp,
    required this.sessionId,
    required this.payload,
    this.errorCode,
    this.authentication,
  });

  factory DeviceMessage.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const DeviceProtocolException('Message must be a JSON object.');
    }
    return DeviceMessage.fromMap(decoded);
  }

  factory DeviceMessage.fromMap(Map<String, dynamic> map) {
    final protocolVersion = _requiredString(map, 'protocol_version');
    final messageType = _requiredString(map, 'message_type');
    final timestampValue = _requiredString(map, 'timestamp');
    final sessionId = _requiredString(map, 'session_id');
    final payload = map['payload'];

    if (payload is! Map<String, dynamic>) {
      throw const DeviceProtocolException('payload must be a JSON object.');
    }

    final timestamp = DateTime.tryParse(timestampValue)?.toUtc();
    if (timestamp == null) {
      throw const DeviceProtocolException('timestamp must be ISO-8601.');
    }

    if (protocolVersion != currentProtocolVersion) {
      throw DeviceProtocolException(
        'Unsupported protocol version: $protocolVersion',
      );
    }

    final errorCode = map['error_code'];
    if (errorCode != null && errorCode is! String) {
      throw const DeviceProtocolException('error_code must be a string or null.');
    }

    final authentication = map['authentication'];
    if (authentication != null && authentication is! Map<String, dynamic>) {
      throw const DeviceProtocolException('authentication must be an object or null.');
    }

    return DeviceMessage(
      protocolVersion: protocolVersion,
      messageType: messageType,
      timestamp: timestamp,
      sessionId: sessionId,
      payload: Map<String, dynamic>.unmodifiable(payload),
      errorCode: errorCode as String?,
      authentication: authentication == null
          ? null
          : Map<String, dynamic>.unmodifiable(authentication as Map<String, dynamic>),
    );
  }

  final String protocolVersion;
  final String messageType;
  final DateTime timestamp;
  final String sessionId;
  final Map<String, dynamic> payload;
  final String? errorCode;
  /// Detached/in-envelope authentication metadata agreed by the hardware team.
  /// The app never contains a default key or accepts this field on its own.
  final Map<String, dynamic>? authentication;

  Map<String, dynamic> toMap() => {
        'protocol_version': protocolVersion,
        'message_type': messageType,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'session_id': sessionId,
        'payload': payload,
        'error_code': errorCode,
        'authentication': authentication,
      };

  String toJson() => jsonEncode(toMap());

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw DeviceProtocolException('$key must be a non-empty string.');
    }
    return value;
  }
}

/// Configurable security boundary for device transports.
///
/// An implementation must verify the approved integrity/authentication scheme
/// (for example a rotating-key MAC or mutually authenticated transport). It is
/// deliberately supplied by deployment configuration: no UUID, key, signature,
/// or server address is invented by this project.
abstract interface class DeviceMessageAuthenticator {
  FutureOr<bool> isAuthenticated(DeviceMessage message);
}

/// Rejects unauthenticated, stale, future-dated, and replayed device messages
/// before they can be exposed as navigation data.
final class DeviceMessageSecurityValidator {
  DeviceMessageSecurityValidator({
    required this.authenticator,
    DateTime Function()? clock,
    this.maximumClockSkew = const Duration(seconds: 5),
    this.replayRetention = const Duration(minutes: 5),
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final DeviceMessageAuthenticator authenticator;
  final DateTime Function() _clock;
  final Duration maximumClockSkew;
  final Duration replayRetention;
  final Map<String, DateTime> _seen = {};

  Future<void> validate(DeviceMessage message) async {
    final now = _clock().toUtc();
    if (message.timestamp.difference(now).abs() > maximumClockSkew) {
      throw const DeviceProtocolException('Message timestamp is stale or outside the permitted clock skew.');
    }
    if (message.authentication == null || !await authenticator.isAuthenticated(message)) {
      throw const DeviceProtocolException('Message authentication failed.');
    }
    _seen.removeWhere((_, seenAt) => now.difference(seenAt) > replayRetention);
    final replayKey = '${message.sessionId}:${message.timestamp.toIso8601String()}:${message.messageType}:${jsonEncode(message.payload)}';
    if (_seen.containsKey(replayKey)) {
      throw const DeviceProtocolException('Replayed device message.');
    }
    _seen[replayKey] = now;
  }
}

enum DeviceConnectionStatus { unavailable, disconnected, connecting, connected }

enum DeviceEventType {
  connectionStatus,
  batteryStatus,
  navigationStatus,
  obstacle,
  deviceHealth,
  updateStatus,
}

final class DeviceDescriptor {
  const DeviceDescriptor({required this.id, required this.displayName});

  final String id;
  final String displayName;
}

final class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.hardwareVersion,
    required this.softwareVersion,
    required this.protocolVersion,
  });

  final String deviceId;
  final String hardwareVersion;
  final String softwareVersion;
  final String protocolVersion;
}

final class DeviceCommand {
  const DeviceCommand(this.name, {this.payload = const {}});

  final String name;
  final Map<String, dynamic> payload;
}

final class DeviceEvent {
  const DeviceEvent({
    required this.type,
    required this.receivedAt,
    required this.message,
  });

  final DeviceEventType type;
  final DateTime receivedAt;
  final DeviceMessage message;

  bool get isStale =>
      receivedAt.toUtc().difference(message.timestamp).inSeconds > 5;
}

class DeviceProtocolException implements Exception {
  const DeviceProtocolException(this.message);

  final String message;

  @override
  String toString() => 'DeviceProtocolException: $message';
}
