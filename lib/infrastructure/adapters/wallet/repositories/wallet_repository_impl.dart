import '../../../../failures/app_failure.dart';
import '../../../api/http_exception.dart';
import '../../../../features/wallet/domain/entities/wallet.dart';
import '../../../../features/wallet/domain/repositories/wallet_repository.dart';
import '../remote/wallet_remote_data_source.dart';

/// The wallet, over HTTP, with the failures this app speaks.
///
/// No local database underneath, like the blog's (ARCHITECTURE.md §11): its
/// job is to call the remote source and translate what goes wrong, because an
/// `HttpException` is an infrastructure type and RULE 27 keeps it out of the
/// layers above.
class WalletRepositoryImpl implements WalletRepository {
  const WalletRepositoryImpl({required WalletRemoteDataSource remote})
    : _remote = remote;

  final WalletRemoteDataSource _remote;

  @override
  Future<WalletSummary> fetchSummary() => _guard(_remote.fetchSummary);

  @override
  Future<WalletStatementPage> fetchStatement({String? cursor}) =>
      _guard(() => _remote.fetchStatement(cursor: cursor));

  @override
  Future<List<WalletPayment>> fetchPayments() => _guard(_remote.fetchPayments);

  @override
  Future<List<TopUpOffer>> fetchTopUpOffers() =>
      _guard(_remote.fetchTopUpOffers);

  @override
  Future<StoreCheckout> startStoreTopUp(TopUpOffer offer) =>
      _guard(() => _remote.startStoreTopUp(offer));

  @override
  Future<WalletPayment> confirmStorePurchase({
    required String reference,
    required String purchaseToken,
  }) => _guard(
    () => _remote.confirmStorePurchase(
      reference: reference,
      purchaseToken: purchaseToken,
    ),
  );

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on HttpException catch (error) {
      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The wallet service sent an unexpected response.',
        cause: error,
      );
    }
  }
}
