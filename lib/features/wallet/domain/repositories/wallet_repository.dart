import '../entities/wallet.dart';

/// The wallet and the payments that fill it.
///
/// Like the blog, this repository reaches the network and does not read a
/// local database, and that is a decision rather than an omission
/// (ARCHITECTURE.md §11). A balance shown from a cache is a number somebody
/// acts on after it stopped being true, and a purchase cannot be made offline
/// at all - so these methods say `fetch` and `start`, and an offline reader
/// gets an honest error rather than a stale balance.
abstract interface class WalletRepository {
  Future<WalletSummary> fetchSummary();

  /// One page of the statement, newest first. [cursor] is the previous page's
  /// `nextCursor`.
  Future<WalletStatementPage> fetchStatement({String? cursor});

  /// The workspace's payments - top-ups made on the web and in the app alike.
  Future<List<WalletPayment>> fetchPayments();

  /// What can be bought in the app, already priced with Google Play's fee.
  ///
  /// Empty when Google Play is switched off or no package is synced to it.
  Future<List<TopUpOffer>> fetchTopUpOffers();

  /// Writes the payment record and returns what to buy in the store.
  ///
  /// Nothing is charged here; the server only records that a purchase is
  /// about to start, so a purchase can never exist without a record of it.
  Future<StoreCheckout> startStoreTopUp(TopUpOffer offer);

  /// Hands the store's purchase token to the server, which checks it with
  /// Google before crediting anything. Safe to repeat: a token already
  /// credited changes nothing.
  Future<WalletPayment> confirmStorePurchase({
    required String reference,
    required String purchaseToken,
  });
}
