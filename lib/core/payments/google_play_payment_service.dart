import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

import 'payment_service.dart';

/// Google Play subscription adapter.
///
/// Product IDs must exactly match Google Play Console. A successful store
/// transaction is not enough to grant Pro: the purchase token must be sent to a
/// trusted backend for verification before entitlement changes.
final class GooglePlayPaymentService implements PaymentService {
  GooglePlayPaymentService({
    iap.InAppPurchase? store,
    required this.verificationEndpoint,
    this.authorizationTokenProvider,
    http.Client? client,
  })  : _store = store ?? iap.InAppPurchase.instance,
        _client = client ?? http.Client();

  static const productIds = <String>{
    'drishti_pro_monthly',
    'drishti_pro_6_month',
    'drishti_pro_yearly',
  };

  static const catalog = <SubscriptionProduct>[
    SubscriptionProduct(
      id: 'drishti_pro_monthly',
      displayName: 'DRISHTI PRO মাসিক',
      priceLabel: '৳299 / মাস',
    ),
    SubscriptionProduct(
      id: 'drishti_pro_6_month',
      displayName: 'DRISHTI PRO ৬ মাস',
      priceLabel: '৳1,699 / ৬ মাস',
    ),
    SubscriptionProduct(
      id: 'drishti_pro_yearly',
      displayName: 'DRISHTI PRO বার্ষিক',
      priceLabel: '৳2,899 / বছর',
    ),
  ];

  final iap.InAppPurchase _store;
  final Uri? verificationEndpoint;
  final Future<String?> Function()? authorizationTokenProvider;
  final http.Client _client;
  StreamSubscription<List<iap.PurchaseDetails>>? _purchaseSubscription;
  final StreamController<PurchaseResult> _results = StreamController.broadcast();

  Stream<PurchaseResult> get purchaseResults => _results.stream;

  Future<void> initialize() async {
    _purchaseSubscription ??= _store.purchaseStream.listen(
      _handlePurchases,
      onError: (Object error, StackTrace stack) {
        _results.add(PurchaseResult(status: PurchaseStatus.failed, message: error.toString()));
      },
    );
  }

  @override
  Future<List<SubscriptionProduct>> loadProducts() async {
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(productIds);
    return [
      for (final product in response.productDetails)
        SubscriptionProduct(
          id: product.id,
          displayName: product.title,
          priceLabel: product.price,
        ),
    ];
  }

  @override
  Future<PurchaseResult> purchase(String productId) async {
    if (!productIds.contains(productId)) {
      return const PurchaseResult(
        status: PurchaseStatus.failed,
        message: 'এই product ID Google Play catalog-এ অনুমোদিত নয়।',
      );
    }
    if (!await _store.isAvailable()) {
      return const PurchaseResult(
        status: PurchaseStatus.unavailable,
        message: 'Google Play billing এই device-এ পাওয়া যায়নি।',
      );
    }
    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      return const PurchaseResult(
        status: PurchaseStatus.unavailable,
        message: 'Product এখনো Google Play Console-এ প্রকাশিত/পরীক্ষার জন্য available নয়।',
      );
    }
    await _store.buyNonConsumable(
      purchaseParam: iap.PurchaseParam(productDetails: response.productDetails.single),
    );
    return const PurchaseResult(status: PurchaseStatus.pending);
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    if (!await _store.isAvailable()) {
      return const PurchaseResult(status: PurchaseStatus.unavailable);
    }
    await _store.restorePurchases();
    return const PurchaseResult(status: PurchaseStatus.pending);
  }

  Future<void> _handlePurchases(List<iap.PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == iap.PurchaseStatus.pending) {
        _results.add(const PurchaseResult(status: PurchaseStatus.pending));
        continue;
      }
      if (purchase.status == iap.PurchaseStatus.error || purchase.status == iap.PurchaseStatus.canceled) {
        _results.add(PurchaseResult(status: PurchaseStatus.failed, message: purchase.error?.message));
      } else if (purchase.status == iap.PurchaseStatus.purchased || purchase.status == iap.PurchaseStatus.restored) {
        final verified = await _verifyWithBackend(purchase);
        _results.add(
          PurchaseResult(
            status: verified
                ? (purchase.status == iap.PurchaseStatus.restored ? PurchaseStatus.restored : PurchaseStatus.purchased)
                : PurchaseStatus.failed,
            message: verified ? null : 'Purchase backend verification ব্যর্থ হয়েছে।',
          ),
        );
        if (verified && purchase.pendingCompletePurchase) {
          await _store.completePurchase(purchase);
        }
      }
    }
  }

  Future<bool> _verifyWithBackend(iap.PurchaseDetails purchase) async {
    final endpoint = verificationEndpoint;
    final token = purchase.verificationData.serverVerificationData;
    if (endpoint == null || token.isEmpty) return false;
    try {
      final authorizationToken = await authorizationTokenProvider?.call();
      if (authorizationToken == null || authorizationToken.isEmpty) return false;
      final response = await _client.post(
        endpoint,
        headers: {
          'content-type': 'application/json',
          'authorization': 'Bearer $authorizationToken',
        },
        body: jsonEncode({
          'platform': 'google_play',
          'productId': purchase.productID,
          'purchaseToken': token,
        }),
      );
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      return body is Map<String, dynamic> && body['entitled'] == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> refreshEntitlement() async => false;

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    _client.close();
    await _results.close();
  }
}
