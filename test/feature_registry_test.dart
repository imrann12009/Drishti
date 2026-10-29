import 'package:flutter_test/flutter_test.dart';
import 'package:drishti/core/entitlement/feature_registry.dart';

void main() {
  test('free tier enables only baseline voice feature', () async {
    const registry = FeatureRegistry(
      entitlementProvider: MockEntitlementProvider(),
    );

    expect(
      await registry.isEnabled(FeatureId.BengaliVoiceNavigation),
      isTrue,
    );
    expect(await registry.isEnabled(FeatureId.OcrSigns), isFalse);
  });

  test('pro tier enables planned gated features through provider boundary',
      () async {
    const registry = FeatureRegistry(
      entitlementProvider: MockEntitlementProvider(tier: EntitlementTier.pro),
    );

    expect(await registry.isEnabled(FeatureId.OcrSigns), isTrue);
  });
}
