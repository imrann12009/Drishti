/// Release gate for a real Raspberry Pi/BLE/Wi-Fi adapter.
///
/// The app may use [UnavailableDeviceConnectionService] until every item is
/// approved. This keeps a disconnected or stale device from being presented as
/// live navigation.
final class DeviceTransportRequirements {
  const DeviceTransportRequirements({
    required this.transport,
    required this.protocolApproved,
    required this.authenticated,
    required this.replayProtection,
    required this.timeoutHandling,
    required this.staleDataHandling,
    required this.disconnectRecovery,
  });

  final String transport;
  final bool protocolApproved;
  final bool authenticated;
  final bool replayProtection;
  final bool timeoutHandling;
  final bool staleDataHandling;
  final bool disconnectRecovery;

  bool get readyForDeviceMode =>
      protocolApproved &&
      authenticated &&
      replayProtection &&
      timeoutHandling &&
      staleDataHandling &&
      disconnectRecovery;
}
