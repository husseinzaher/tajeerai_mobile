import '../../../api/http_client.dart';
import '../../../../features/wallet/domain/entities/wallet.dart';
import '../models/wallet_dto.dart';

/// The wallet's HTTP calls - the only file in the feature allowed to name
/// `HttpClient` (RULE 36), and the only place its endpoints are written down.
///
/// HTTP rather than the socket because the backend exposes the wallet and
/// billing over HTTP alone, and a purchase is an online act by nature
/// (ARCHITECTURE.md §11).
class WalletRemoteDataSource {
  const WalletRemoteDataSource(this._http);

  final HttpClient _http;

  /// The app is the only surface that may offer Google Play, and the server
  /// filters what it offers by the surface asking.
  static const String _channel = 'android';

  Future<WalletSummary> fetchSummary() async =>
      WalletDto.decodeSummary(await _http.get('/v1/wallet'));

  Future<WalletStatementPage> fetchStatement({String? cursor}) async {
    return WalletDto.decodeStatement(
      await _http.get(
        '/v1/wallet/statement',
        query: <String, Object?>{'limit': 25, 'cursor': ?cursor},
      ),
    );
  }

  Future<List<WalletPayment>> fetchPayments() async {
    return WalletDto.decodePayments(
      await _http.get(
        '/v1/billing/payments',
        query: <String, Object?>{'perPage': 25},
      ),
    );
  }

  Future<List<TopUpOffer>> fetchTopUpOffers() async {
    return WalletDto.decodeOffers(
      await _http.get(
        '/v1/billing/topups/options',
        query: <String, Object?>{'channel': _channel},
      ),
    );
  }

  /// No amount is sent: the package names the credit, and the server adds the
  /// fee. A client that could name an amount could name a smaller one.
  Future<StoreCheckout> startStoreTopUp(TopUpOffer offer) async {
    return WalletDto.decodeCheckout(
      await _http.post(
        '/v1/billing/topups',
        body: <String, Object?>{
          'packageId': offer.packageId,
          'gatewayKey': offer.gatewayKey,
        },
      ),
    );
  }

  Future<WalletPayment> confirmStorePurchase({
    required String reference,
    required String purchaseToken,
  }) async {
    return WalletDto.decodePayment(
      await _http.post(
        '/v1/billing/payments/${Uri.encodeComponent(reference)}/store-purchase',
        body: <String, Object?>{'purchaseToken': purchaseToken},
      ),
    );
  }
}
