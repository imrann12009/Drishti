// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';

enum FeatureId {
  BengaliVoiceNavigation,
  AdvancedObstacleAlerts,
  OcrSigns,
  CurrencyRecognition,
  BusNumberReading,
  CloudSceneDescriptions,
}

enum EntitlementTier { free, pro }

@immutable
final class EntitlementSnapshot {
  const EntitlementSnapshot({
    required this.tier,
    required this.expiresAt,
    required this.source,
  });

  final EntitlementTier tier;
  final DateTime? expiresAt;
  final String source;

  bool get isPro {
    if (tier != EntitlementTier.pro) {
      return false;
    }
    final expiry = expiresAt;
    return expiry == null || expiry.isAfter(DateTime.now().toUtc());
  }
}

abstract interface class EntitlementProvider {
  Future<EntitlementSnapshot> getSnapshot();
}

/// Production must replace this with trusted store/backend verification. The
/// client must never be the only authority for paid access.
final class MockEntitlementProvider implements EntitlementProvider {
  const MockEntitlementProvider({this.tier = EntitlementTier.free});

  final EntitlementTier tier;

  @override
  Future<EntitlementSnapshot> getSnapshot() async => EntitlementSnapshot(
        tier: tier,
        expiresAt: null,
        source: 'mock-development-only',
      );
}

final class FeatureRegistry {
  const FeatureRegistry({required this.entitlementProvider});

  final EntitlementProvider entitlementProvider;

  Future<bool> isEnabled(FeatureId feature) async {
    final snapshot = await entitlementProvider.getSnapshot();
    switch (feature) {
      case FeatureId.BengaliVoiceNavigation:
        return true;
      case FeatureId.AdvancedObstacleAlerts:
      case FeatureId.OcrSigns:
      case FeatureId.CurrencyRecognition:
      case FeatureId.BusNumberReading:
      case FeatureId.CloudSceneDescriptions:
        return snapshot.isPro;
    }
  }
}
