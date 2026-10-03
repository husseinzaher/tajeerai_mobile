import '../../../../features/wallet/domain/entities/wallet.dart';

/// The backend's wallet and billing JSON, as this app's entities.
///
/// Strict where a wrong value would mislead about money - a summary with no
/// balance, an offer with no product - and forgiving everywhere else: one
/// unreadable statement row must not cost the reader the rest of the page.
abstract final class WalletDto {
  /// `GET /v1/wallet`.
  static WalletSummary decodeSummary(Map<String, Object?> json) {
    final double? balance = _number(json['balance']);

    if (balance == null) {
      throw const FormatException('A wallet summary without a balance.');
    }

    return WalletSummary(
      currency: _string(json['currency']) ?? 'USD',
      balance: balance,
      available: _number(json['available']) ?? balance,
      reserved: _number(json['reserved']) ?? 0,
      frozen: json['status'] == 'frozen',
    );
  }

  /// `GET /v1/wallet/statement` - `{ entries, nextCursor }`.
  static WalletStatementPage decodeStatement(Map<String, Object?> json) {
    final List<WalletEntry> entries = <WalletEntry>[];

    for (final Map<String, Object?> row in _rows(json['entries'])) {
      final String? id = _string(row['id']);
      final double? amount = _number(row['amount']);
      final DateTime? at = _date(row['createdAt']);

      if (id == null || amount == null || at == null) continue;

      entries.add(
        WalletEntry(
          id: id,
          type: _string(row['type']) ?? '',
          isCredit: row['direction'] == 'credit',
          amount: amount,
          currency: _string(row['currency']) ?? 'USD',
          balanceAfter: _number(row['balanceAfter']) ?? 0,
          description: _string(row['description']),
          createdAt: at,
        ),
      );
    }

    return WalletStatementPage(
      entries: entries,
      nextCursor: _string(json['nextCursor']),
    );
  }

  /// `GET /v1/billing/payments` - `{ data, meta }`.
  static List<WalletPayment> decodePayments(Map<String, Object?> json) {
    final List<WalletPayment> payments = <WalletPayment>[];

    for (final Map<String, Object?> row in _rows(json['data'])) {
      try {
        payments.add(decodePayment(row));
      } on FormatException {
        continue;
      }
    }

    return payments;
  }

  /// One payment, from the list or from `POST …/store-purchase`.
  static WalletPayment decodePayment(Map<String, Object?> json) {
    final String? reference = _string(json['reference']);
    final double? total = _number(json['expectedAmount']);
    final DateTime? at = _date(json['createdAt']);

    if (reference == null || total == null || at == null) {
      throw const FormatException(
        'A payment without a reference, amount or date.',
      );
    }

    return WalletPayment(
      reference: reference,
      state: _string(json['state']) ?? 'pending',
      gatewayName: _string(json['gatewayName']) ?? '',
      total: total,
      walletCredit: _number(json['walletCredit']),
      fee: _number(json['fee']),
      currency: _string(json['currency']) ?? 'USD',
      createdAt: at,
    );
  }

  /// `GET /v1/billing/topups/options?channel=android`.
  ///
  /// One offer per package that carries a store product *and* a store quote -
  /// a package without both cannot be bought in the app, and listing it would
  /// be a button that fails.
  static List<TopUpOffer> decodeOffers(Map<String, Object?> json) {
    final Set<String> storeKeys = <String>{
      for (final Map<String, Object?> method in _rows(json['methods']))
        if (method['type'] == 'app_store') ?_string(method['key']),
    };

    final List<TopUpOffer> offers = <TopUpOffer>[];

    for (final Map<String, Object?> pkg in _rows(json['packages'])) {
      final String? packageId = _string(pkg['id']);
      final String? productId = _string(pkg['storeProductId']);

      if (packageId == null || productId == null) continue;

      for (final Map<String, Object?> quote in _rows(pkg['quotes'])) {
        final String? gatewayKey = _string(quote['gatewayKey']);
        final double? credit = _number(quote['credit']);
        final double? fee = _number(quote['fee']);
        final double? total = _number(quote['total']);

        if (gatewayKey == null || !storeKeys.contains(gatewayKey)) continue;
        if (credit == null || fee == null || total == null) continue;

        offers.add(
          TopUpOffer(
            packageId: packageId,
            gatewayKey: gatewayKey,
            storeProductId: productId,
            credit: credit,
            fee: fee,
            total: total,
            currency: _string(quote['currency']) ?? 'USD',
          ),
        );
      }
    }

    return offers;
  }

  /// `POST /v1/billing/topups` through a store: the payment with a `store`
  /// handoff. Anything else means the server did not start a store purchase.
  static StoreCheckout decodeCheckout(Map<String, Object?> json) {
    final String? reference = _string(json['reference']);
    final Map<String, Object?>? handoff = _map(json['handoff']);

    if (reference == null || handoff == null || handoff['kind'] != 'store') {
      throw const FormatException('The server did not start a store purchase.');
    }

    final String? productId = _string(handoff['productId']);
    final String? profileId = _string(handoff['obfuscatedProfileId']);

    if (productId == null || profileId == null) {
      throw const FormatException(
        'A store handoff without a product or reference.',
      );
    }

    return StoreCheckout(
      reference: reference,
      productId: productId,
      obfuscatedProfileId: profileId,
    );
  }

  static Iterable<Map<String, Object?>> _rows(Object? raw) sync* {
    if (raw is! List) return;

    for (final Object? entry in raw) {
      final Map<String, Object?>? row = _map(entry);

      if (row != null) yield row;
    }
  }

  static Map<String, Object?>? _map(Object? raw) =>
      raw is Map ? raw.cast<String, Object?>() : null;

  static String? _string(Object? raw) =>
      raw is String && raw.isNotEmpty ? raw : null;

  static double? _number(Object? raw) => switch (raw) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;
}
