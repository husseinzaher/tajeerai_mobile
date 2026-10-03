import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../../../failures/app_failure.dart';
import '../../../../features/wallet/application/ports/store_billing_port.dart';

/// Google Play Billing, behind [StoreBillingPort].
///
/// ## What it deliberately does not do
///
/// **It never consumes a purchase, and never acknowledges one.** The server
/// consumes each purchase after crediting the wallet (`GooglePlayGateway.fulfil`),
/// and a consumed purchase is acknowledged by definition. Consuming here first
/// would let Google forget a purchase the server has not credited yet - money
/// taken, nothing received. So `buyConsumable` is called with
/// `autoConsume: false` and `completePurchase` is never called.
///
/// **It never decides that money moved.** It reports what the store said; the
/// coordinator hands the token to the server, which asks Google itself.
class PlayBillingAdapter implements StoreBillingPort {
  PlayBillingAdapter({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<Map<String, String>> localizedPrices(Set<String> productIds) async {
    if (productIds.isEmpty) return const <String, String>{};

    final ProductDetailsResponse response = await _store.queryProductDetails(
      productIds,
    );

    return <String, String>{
      for (final ProductDetails product in response.productDetails)
        product.id: product.price,
    };
  }

  @override
  Future<void> buy({
    required String productId,
    required String obfuscatedProfileId,
  }) async {
    final ProductDetailsResponse response = await _store.queryProductDetails(
      <String>{productId},
    );

    final ProductDetails? product = response.productDetails
        .where((ProductDetails details) => details.id == productId)
        .firstOrNull;

    if (product == null) {
      // Not synced to Play yet, or not offered in this buyer's country.
      throw NotFoundFailure(
        message: 'Google Play does not sell $productId here.',
      );
    }

    await _store.buyConsumable(
      purchaseParam: GooglePlayPurchaseParam(
        productDetails: product,
        obfuscatedProfileId: obfuscatedProfileId,
      ),
      autoConsume: false,
    );
  }

  @override
  Stream<List<StorePurchase>> get purchases => _store.purchaseStream.map(
    (List<PurchaseDetails> updates) => updates.map(_toPurchase).toList(),
  );

  @override
  Future<List<StorePurchase>> unfinishedPurchases() async {
    final InAppPurchaseAndroidPlatformAddition android = _store
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final QueryPurchaseDetailsResponse response = await android
        .queryPastPurchases();

    return response.pastPurchases.map(_toPurchase).toList();
  }

  StorePurchase _toPurchase(PurchaseDetails details) {
    final String? reference = details is GooglePlayPurchaseDetails
        ? details.billingClientPurchase.obfuscatedProfileId
        : null;

    return StorePurchase(
      productId: details.productID,
      status: switch (details.status) {
        PurchaseStatus.pending => StorePurchaseStatus.pending,
        PurchaseStatus.purchased ||
        PurchaseStatus.restored => StorePurchaseStatus.purchased,
        PurchaseStatus.canceled => StorePurchaseStatus.canceled,
        PurchaseStatus.error => StorePurchaseStatus.error,
      },
      purchaseToken: details.verificationData.serverVerificationData.isEmpty
          ? null
          : details.verificationData.serverVerificationData,
      obfuscatedProfileId: reference,
    );
  }
}

/// No store to buy from: iOS, where the wallet is view-only for now (owner,
/// 2026-10-03), and any device without Google Play. The wallet still shows
/// its balance and history; it simply offers nothing to buy.
class UnavailableStoreBillingAdapter implements StoreBillingPort {
  const UnavailableStoreBillingAdapter();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Map<String, String>> localizedPrices(Set<String> productIds) async =>
      const <String, String>{};

  @override
  Future<void> buy({
    required String productId,
    required String obfuscatedProfileId,
  }) async =>
      throw const UnknownFailure(message0: 'No app store on this device.');

  @override
  Stream<List<StorePurchase>> get purchases =>
      const Stream<List<StorePurchase>>.empty();

  @override
  Future<List<StorePurchase>> unfinishedPurchases() async =>
      const <StorePurchase>[];
}
