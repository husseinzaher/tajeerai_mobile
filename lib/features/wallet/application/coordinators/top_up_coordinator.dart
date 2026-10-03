import 'dart:async';

import '../../../../failures/app_failure.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../ports/store_billing_port.dart';

/// What happened to a top-up, for the screen to say.
sealed class TopUpOutcome {
  const TopUpOutcome();
}

/// The store is waiting on the buyer's bank or a cash payment. Google will
/// finish it later, and the server hears about it then.
final class TopUpPending extends TopUpOutcome {
  const TopUpPending();
}

/// The server checked the purchase with Google and credited the wallet.
final class TopUpCredited extends TopUpOutcome {
  const TopUpCredited(this.payment);

  final WalletPayment payment;
}

/// The buyer closed the store's sheet. Not an error.
final class TopUpCanceled extends TopUpOutcome {
  const TopUpCanceled();
}

final class TopUpFailed extends TopUpOutcome {
  const TopUpFailed(this.failure);

  /// Null when the store itself reported the error.
  final AppFailure? failure;
}

/// A wallet top-up bought through Google Play, from the sheet to the credit.
///
/// ## The sequence
///
/// ```
/// 1. server: write the payment record, get the product and a reference
/// 2. store:  open the purchase sheet, the reference tagged on the purchase
/// 3. store:  report the purchase, with its token        (on [StoreBillingPort.purchases])
/// 4. server: check the token with Google, credit, consume
/// ```
///
/// Step 1 comes first so that no purchase can exist without a record behind
/// it. Step 4 is the only one that moves money, and it is the server's: the
/// app never credits anything and never consumes a purchase itself. Consuming
/// on the device before the server had credited would let the store forget a
/// purchase the wallet never received.
///
/// ## Recovery
///
/// The app can die between 3 and 4, and the network can drop the
/// confirmation. Either way Google still holds the purchase unconsumed, so
/// [recover] re-sends every one of them each time the wallet opens. The
/// server's confirmation is idempotent on the token, so a purchase sent twice
/// is credited once - and Google's own notification settles it server-side
/// even if the app never opens again.
class TopUpCoordinator {
  TopUpCoordinator({
    required WalletRepository repository,
    required StoreBillingPort store,
  }) : _repository = repository,
       _store = store;

  final WalletRepository _repository;
  final StoreBillingPort _store;

  final StreamController<TopUpOutcome> _outcomes =
      StreamController<TopUpOutcome>.broadcast();

  /// Tokens being confirmed right now, so a store that reports the same
  /// purchase twice in a burst sends it to the server once.
  final Set<String> _inFlight = <String>{};

  StreamSubscription<List<StorePurchase>>? _subscription;

  Stream<TopUpOutcome> get outcomes => _outcomes.stream;

  /// Starts listening to the store. Safe to call more than once.
  void start() {
    _subscription ??= _store.purchases.listen((List<StorePurchase> updates) {
      for (final StorePurchase purchase in updates) {
        unawaited(_handle(purchase));
      }
    });
  }

  /// Steps 1 and 2. The outcome arrives on [outcomes].
  ///
  /// Throws an [AppFailure] when the server refuses to start - Google Play
  /// switched off, or the package changed price since it was listed.
  Future<void> buy(TopUpOffer offer) async {
    final StoreCheckout checkout = await _repository.startStoreTopUp(offer);

    await _store.buy(
      productId: checkout.productId,
      obfuscatedProfileId: checkout.obfuscatedProfileId,
    );
  }

  /// Re-sends every purchase the store still holds unconsumed.
  Future<void> recover() async {
    final List<StorePurchase> unfinished = await _store.unfinishedPurchases();

    for (final StorePurchase purchase in unfinished) {
      await _handle(purchase);
    }
  }

  Future<void> _handle(StorePurchase purchase) async {
    switch (purchase.status) {
      case StorePurchaseStatus.pending:
        _emit(const TopUpPending());
      case StorePurchaseStatus.canceled:
        _emit(const TopUpCanceled());
      case StorePurchaseStatus.error:
        _emit(const TopUpFailed(null));
      case StorePurchaseStatus.purchased:
        await _confirm(purchase);
    }
  }

  Future<void> _confirm(StorePurchase purchase) async {
    final String? token = purchase.purchaseToken;
    final String? reference = purchase.obfuscatedProfileId;

    /*
      A purchase with no reference was not started by this app - bought before
      the wallet existed, or by another build. The server could not match it
      to a payment, so there is nothing to send.
    */
    if (token == null || reference == null || reference.isEmpty) return;
    if (!_inFlight.add(token)) return;

    try {
      final WalletPayment payment = await _repository.confirmStorePurchase(
        reference: reference,
        purchaseToken: token,
      );

      _emit(payment.isPaid ? TopUpCredited(payment) : const TopUpPending());
    } on AppFailure catch (failure) {
      _emit(TopUpFailed(failure));
    } finally {
      _inFlight.remove(token);
    }
  }

  void _emit(TopUpOutcome outcome) {
    if (!_outcomes.isClosed) _outcomes.add(outcome);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _outcomes.close();
  }
}
