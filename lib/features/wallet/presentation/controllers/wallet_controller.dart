import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../application/coordinators/top_up_coordinator.dart';
import '../../domain/entities/wallet.dart';

/// The balance. Network-backed and dropped when the screen closes, so opening
/// the wallet always shows the server's current answer (ARCHITECTURE.md §11).
final FutureProvider<WalletSummary> walletSummaryProvider =
    FutureProvider.autoDispose<WalletSummary>(
      (Ref ref) => ref.watch(walletRepositoryProvider).fetchSummary(),
    );

/// Purchase history - every top-up, on the web and in the app.
final FutureProvider<List<WalletPayment>> walletPaymentsProvider =
    FutureProvider.autoDispose<List<WalletPayment>>(
      (Ref ref) => ref.watch(walletRepositoryProvider).fetchPayments(),
    );

/// The newest page of the statement.
final FutureProvider<WalletStatementPage> walletStatementProvider =
    FutureProvider.autoDispose<WalletStatementPage>(
      (Ref ref) => ref.watch(walletRepositoryProvider).fetchStatement(),
    );

/// What the member may buy here, with Google Play's own price beside ours.
final class TopUpShelf {
  const TopUpShelf({
    required this.storeAvailable,
    required this.canTopUp,
    required this.offers,
    required this.storePrices,
  });

  /// False on iOS and on a device without Google Play.
  final bool storeAvailable;

  /// The member holds `update:Wallet`. Without it the shelf is not drawn at
  /// all - a buy button that the server will refuse is a question asked twice.
  final bool canTopUp;
  final List<TopUpOffer> offers;

  /// Google's formatted price per product, in the buyer's own currency.
  final Map<String, String> storePrices;

  bool get isOpen => storeAvailable && canTopUp && offers.isNotEmpty;
}

final FutureProvider<TopUpShelf> topUpShelfProvider =
    FutureProvider.autoDispose<TopUpShelf>((Ref ref) async {
      final bool canTopUp =
          ref
              .watch(sessionCapabilityProvider)
              .currentSession
              ?.user
              .can('update:Wallet') ??
          false;
      final bool storeAvailable = await ref
          .watch(storeBillingPortProvider)
          .isAvailable();

      if (!canTopUp || !storeAvailable) {
        return TopUpShelf(
          storeAvailable: storeAvailable,
          canTopUp: canTopUp,
          offers: const <TopUpOffer>[],
          storePrices: const <String, String>{},
        );
      }

      final List<TopUpOffer> offers = await ref
          .watch(walletRepositoryProvider)
          .fetchTopUpOffers();
      final Map<String, String> prices = await ref
          .watch(storeBillingPortProvider)
          .localizedPrices(<String>{
            for (final TopUpOffer offer in offers) offer.storeProductId,
          });

      return TopUpShelf(
        storeAvailable: storeAvailable,
        canTopUp: canTopUp,
        offers: offers,
        storePrices: prices,
      );
    });

/// Where a purchase stands, for the screen.
final class TopUpState {
  const TopUpState({this.buyingPackageId, this.outcome});

  /// The package whose purchase sheet is opening, so only its button spins.
  final String? buyingPackageId;

  /// The last thing that happened. Null until something has.
  final TopUpOutcome? outcome;
}

/// Buying a top-up, and hearing how it ended.
///
/// Listens to the coordinator for as long as the wallet is open, re-sends any
/// purchase the store still holds unfinished each time it opens, and refreshes
/// the balance and history the moment a credit lands.
class TopUpController extends Notifier<TopUpState> {
  StreamSubscription<TopUpOutcome>? _subscription;

  @override
  TopUpState build() {
    final TopUpCoordinator coordinator = ref.watch(topUpCoordinatorProvider);

    coordinator.start();
    _subscription = coordinator.outcomes.listen(_onOutcome);
    ref.onDispose(() => _subscription?.cancel());

    unawaited(coordinator.recover().catchError((Object _) {}));

    return const TopUpState();
  }

  Future<void> buy(TopUpOffer offer) async {
    if (state.buyingPackageId != null) return;

    state = TopUpState(
      buyingPackageId: offer.packageId,
      outcome: state.outcome,
    );

    try {
      await ref.read(topUpCoordinatorProvider).buy(offer);
      state = TopUpState(outcome: state.outcome);
    } on Object catch (_) {
      state = const TopUpState(outcome: TopUpFailed(null));
    }
  }

  void _onOutcome(TopUpOutcome outcome) {
    state = TopUpState(outcome: outcome);

    if (outcome is TopUpCredited) {
      ref
        ..invalidate(walletSummaryProvider)
        ..invalidate(walletPaymentsProvider)
        ..invalidate(walletStatementProvider);
    }
  }
}

final NotifierProvider<TopUpController, TopUpState> topUpControllerProvider =
    NotifierProvider.autoDispose<TopUpController, TopUpState>(
      TopUpController.new,
    );
