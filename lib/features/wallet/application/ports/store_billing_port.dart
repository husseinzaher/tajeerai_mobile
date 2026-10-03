/// The device's app store, as the wallet needs it.
///
/// A port because what is behind it is a platform plugin - Google Play
/// Billing - which cannot run in a unit test. The coordinator speaks this
/// vocabulary; `PlayBillingAdapter` translates it to the plugin.
abstract interface class StoreBillingPort {
  /// Whether this device can buy from the store at all. False on iOS (the
  /// wallet is view-only there) and on an Android device without Play.
  Future<bool> isAvailable();

  /// The store's own price for each product, formatted in the buyer's
  /// currency as Google will charge it. A product the store does not know is
  /// left out.
  Future<Map<String, String>> localizedPrices(Set<String> productIds);

  /// Opens the store's purchase sheet. Returns once the sheet is up; the
  /// outcome arrives on [purchases].
  ///
  /// [obfuscatedProfileId] is stored by the store on the purchase and read
  /// back by the server - it is what ties the purchase to one payment.
  Future<void> buy({
    required String productId,
    required String obfuscatedProfileId,
  });

  /// Every purchase update the store reports, for as long as the app runs.
  Stream<List<StorePurchase>> get purchases;

  /// Purchases the store still holds unconsumed - an app killed mid-purchase,
  /// or a confirmation that never reached the server.
  Future<List<StorePurchase>> unfinishedPurchases();
}

enum StorePurchaseStatus { pending, purchased, canceled, error }

/// One purchase, as the store reports it.
final class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.purchaseToken,
    this.obfuscatedProfileId,
  });

  final String productId;
  final StorePurchaseStatus status;

  /// What the server verifies with Google. Absent until the store has one.
  final String? purchaseToken;

  /// Our payment reference, as the store stored it on the purchase.
  final String? obfuscatedProfileId;
}
