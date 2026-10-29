/// Boundary for a real store-backed subscription implementation.
///
/// Do not grant Pro access from a client-only flag. A production adapter must
/// validate Google Play/App Store purchases and, ideally, verify receipts on a
/// trusted backend before returning an entitlement snapshot.
abstract interface class PaymentService {
  Future<List<SubscriptionProduct>> loadProducts();

  Future<PurchaseResult> purchase(String productId);

  Future<PurchaseResult> restorePurchases();

  Future<bool> refreshEntitlement();
}

final class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.displayName,
    required this.priceLabel,
  });

  final String id;
  final String displayName;
  final String priceLabel;
}

enum PurchaseStatus { unavailable, pending, purchased, restored, failed }

final class PurchaseResult {
  const PurchaseResult({required this.status, this.message});

  final PurchaseStatus status;
  final String? message;
}

final class UnavailablePaymentService implements PaymentService {
  const UnavailablePaymentService();

  @override
  Future<List<SubscriptionProduct>> loadProducts() async => const [];

  @override
  Future<PurchaseResult> purchase(String productId) async => const PurchaseResult(
        status: PurchaseStatus.unavailable,
        message: 'Store billing is not configured.',
      );

  @override
  Future<PurchaseResult> restorePurchases() async => const PurchaseResult(
        status: PurchaseStatus.unavailable,
        message: 'Store billing is not configured.',
      );

  @override
  Future<bool> refreshEntitlement() async => false;
}
