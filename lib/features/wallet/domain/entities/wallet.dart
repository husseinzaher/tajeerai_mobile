/// The workspace's AI wallet, as the server reports it.
///
/// Money arrives in major units - `12.5`, not micros - because the backend
/// converts once on the way out and the app only ever displays it. Nothing in
/// this app computes with a balance: what the wallet holds is the server's
/// answer, never the client's arithmetic.
final class WalletSummary {
  const WalletSummary({
    required this.currency,
    required this.balance,
    required this.available,
    required this.reserved,
    required this.frozen,
  });

  final String currency;
  final double balance;

  /// What can actually be spent: the balance less what is held for requests
  /// still in flight.
  final double available;
  final double reserved;

  /// A frozen wallet spends nothing until an administrator unfreezes it.
  final bool frozen;
}

/// One line of the wallet's statement.
final class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.type,
    required this.isCredit,
    required this.amount,
    required this.currency,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  final String id;

  /// The server's entry type - `topup_credit`, `ai_usage`, `refund`... Kept as
  /// text: the backend adds types without a schema change here.
  final String type;
  final bool isCredit;
  final double amount;
  final String currency;
  final double balanceAfter;
  final String? description;
  final DateTime createdAt;
}

/// A page of the statement, newest first.
final class WalletStatementPage {
  const WalletStatementPage({required this.entries, required this.nextCursor});

  final List<WalletEntry> entries;

  /// Null on the last page.
  final String? nextCursor;
}

/// One payment, as the purchase history lists it - on the web or in the app.
final class WalletPayment {
  const WalletPayment({
    required this.reference,
    required this.state,
    required this.gatewayName,
    required this.total,
    required this.walletCredit,
    required this.fee,
    required this.currency,
    required this.createdAt,
  });

  final String reference;

  /// `pending`, `submitted`, `paid`, `failed`, `cancelled`.
  final String state;
  final String gatewayName;

  /// What was charged, the fee included.
  final double total;

  /// What reached - or will reach - the wallet. Null on payments from before
  /// the fee was charged separately.
  final double? walletCredit;
  final double? fee;
  final String currency;
  final DateTime createdAt;

  bool get isPaid => state == 'paid';
}

/// A top-up the merchant can buy in the app.
///
/// The fee is added on top of the credit, never taken out of it (owner,
/// 2026-10-03): `total` is `credit + fee`, and the wallet receives `credit`.
final class TopUpOffer {
  const TopUpOffer({
    required this.packageId,
    required this.gatewayKey,
    required this.storeProductId,
    required this.credit,
    required this.fee,
    required this.total,
    required this.currency,
  });

  final String packageId;
  final String gatewayKey;

  /// What Google Play sells this top-up as.
  final String storeProductId;
  final double credit;
  final double fee;
  final double total;
  final String currency;
}

/// The server's half of a store purchase: which product to buy, and the
/// reference to tag the purchase with so the server can match it back.
final class StoreCheckout {
  const StoreCheckout({
    required this.reference,
    required this.productId,
    required this.obfuscatedProfileId,
  });

  final String reference;
  final String productId;
  final String obfuscatedProfileId;
}
