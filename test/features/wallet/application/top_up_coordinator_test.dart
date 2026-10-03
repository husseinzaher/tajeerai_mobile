import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/wallet/application/coordinators/top_up_coordinator.dart';
import 'package:TajeerAi/features/wallet/application/ports/store_billing_port.dart';
import 'package:TajeerAi/features/wallet/domain/entities/wallet.dart';
import 'package:TajeerAi/features/wallet/domain/repositories/wallet_repository.dart';

const TopUpOffer _offer = TopUpOffer(
  packageId: 'pkg-10',
  gatewayKey: 'google_play',
  storeProductId: 'wallet_topup_10',
  credit: 10,
  fee: 1.77,
  total: 11.77,
  currency: 'USD',
);

WalletPayment _payment(String state) => WalletPayment(
  reference: 'REF-1',
  state: state,
  gatewayName: 'Google Play',
  total: 11.77,
  walletCredit: 10,
  fee: 1.77,
  currency: 'USD',
  createdAt: DateTime.utc(2026, 10, 3),
);

StorePurchase _purchased({
  String token = 'token-1',
  String? reference = 'REF-1',
}) => StorePurchase(
  productId: 'wallet_topup_10',
  status: StorePurchaseStatus.purchased,
  purchaseToken: token,
  obfuscatedProfileId: reference,
);

void main() {
  late _FakeRepository repository;
  late _FakeStore store;
  late TopUpCoordinator coordinator;
  late List<TopUpOutcome> outcomes;

  setUp(() {
    repository = _FakeRepository();
    store = _FakeStore();
    coordinator = TopUpCoordinator(repository: repository, store: store)
      ..start();
    outcomes = <TopUpOutcome>[];
    coordinator.outcomes.listen(outcomes.add);
  });

  tearDown(() async {
    await coordinator.dispose();
    await store.close();
  });

  test(
    'records the payment with the server before opening the store',
    () async {
      await coordinator.buy(_offer);

      expect(repository.calls, <String>['start:pkg-10']);
      expect(store.bought, <String>['wallet_topup_10#REF-1']);
    },
  );

  test('does not open the store when the server refuses to start', () async {
    repository.refuseStart = true;

    await expectLater(
      coordinator.buy(_offer),
      throwsA(isA<ValidationFailure>()),
    );
    expect(store.bought, isEmpty);
  });

  test(
    'hands a completed purchase to the server and reports the credit',
    () async {
      store.report(<StorePurchase>[_purchased()]);
      await pumpEventQueue();

      expect(repository.calls, <String>['confirm:REF-1:token-1']);
      expect(outcomes.single, isA<TopUpCredited>());
    },
  );

  test(
    'sends the same purchase once even if the store reports it twice at once',
    () async {
      store.report(<StorePurchase>[_purchased(), _purchased()]);
      await pumpEventQueue();

      expect(repository.calls, <String>['confirm:REF-1:token-1']);
    },
  );

  test('ignores a purchase this app did not start', () async {
    store.report(<StorePurchase>[_purchased(reference: null)]);
    await pumpEventQueue();

    expect(repository.calls, isEmpty);
    expect(outcomes, isEmpty);
  });

  test(
    'a cancel and a pending purchase are reported, and nothing is confirmed',
    () async {
      store.report(const <StorePurchase>[
        StorePurchase(productId: 'p', status: StorePurchaseStatus.canceled),
        StorePurchase(productId: 'p', status: StorePurchaseStatus.pending),
      ]);
      await pumpEventQueue();

      expect(repository.calls, isEmpty);
      expect(outcomes, <Matcher>[isA<TopUpCanceled>(), isA<TopUpPending>()]);
    },
  );

  test('a purchase the server has not settled yet reads as pending', () async {
    repository.confirmState = 'pending';
    store.report(<StorePurchase>[_purchased()]);
    await pumpEventQueue();

    expect(outcomes.single, isA<TopUpPending>());
  });

  test('a refused confirmation is a failure, not a credit', () async {
    repository.refuseConfirm = true;
    store.report(<StorePurchase>[_purchased()]);
    await pumpEventQueue();

    expect(outcomes.single, isA<TopUpFailed>());
  });

  test('recover re-sends every purchase the store still holds', () async {
    store.unfinished = <StorePurchase>[
      _purchased(token: 'a'),
      _purchased(token: 'b'),
    ];

    await coordinator.recover();

    expect(repository.calls, <String>['confirm:REF-1:a', 'confirm:REF-1:b']);
  });
}

final class _FakeRepository implements WalletRepository {
  final List<String> calls = <String>[];
  bool refuseStart = false;
  bool refuseConfirm = false;
  String confirmState = 'paid';

  @override
  Future<StoreCheckout> startStoreTopUp(TopUpOffer offer) async {
    if (refuseStart) {
      throw const ValidationFailure(message: 'This top-up is being updated.');
    }

    calls.add('start:${offer.packageId}');

    return const StoreCheckout(
      reference: 'REF-1',
      productId: 'wallet_topup_10',
      obfuscatedProfileId: 'REF-1',
    );
  }

  @override
  Future<WalletPayment> confirmStorePurchase({
    required String reference,
    required String purchaseToken,
  }) async {
    calls.add('confirm:$reference:$purchaseToken');

    if (refuseConfirm) {
      throw const ValidationFailure(
        message: 'That purchase is not for this top-up.',
      );
    }

    return _payment(confirmState);
  }

  @override
  Future<WalletSummary> fetchSummary() => throw UnimplementedError();

  @override
  Future<WalletStatementPage> fetchStatement({String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<List<WalletPayment>> fetchPayments() => throw UnimplementedError();

  @override
  Future<List<TopUpOffer>> fetchTopUpOffers() => throw UnimplementedError();
}

final class _FakeStore implements StoreBillingPort {
  final StreamController<List<StorePurchase>> _updates =
      StreamController<List<StorePurchase>>.broadcast();
  final List<String> bought = <String>[];
  List<StorePurchase> unfinished = const <StorePurchase>[];

  void report(List<StorePurchase> purchases) => _updates.add(purchases);

  Future<void> close() => _updates.close();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String>> localizedPrices(Set<String> productIds) async =>
      const <String, String>{};

  @override
  Future<void> buy({
    required String productId,
    required String obfuscatedProfileId,
  }) async => bought.add('$productId#$obfuscatedProfileId');

  @override
  Stream<List<StorePurchase>> get purchases => _updates.stream;

  @override
  Future<List<StorePurchase>> unfinishedPurchases() async => unfinished;
}
