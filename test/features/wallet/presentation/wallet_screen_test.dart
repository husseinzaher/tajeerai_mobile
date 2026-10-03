import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/design_system/design_system.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/auth/application/contracts/session_capability.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/wallet/application/ports/store_billing_port.dart';
import 'package:TajeerAi/features/wallet/domain/entities/wallet.dart';
import 'package:TajeerAi/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:TajeerAi/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

import '../../../support/widget_harness.dart';

/// The wallet screen in the states it is actually in: loading, failed,
/// empty, and with money and history - and the top-up shelf, which appears
/// only for a member who may spend and a device that has Google Play.
void main() {
  late PreferencesStorage preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: 'en',
    });
    preferences = await PreferencesStorage.open();
  });

  Widget subject({
    required WalletRepository repository,
    Set<String> permissions = const <String>{'read:Wallet', 'update:Wallet'},
    bool storeAvailable = true,
  }) {
    return ProviderScope(
      overrides: [
        walletRepositoryProvider.overrideWithValue(repository),
        storeBillingPortProvider.overrideWithValue(
          _Store(available: storeAvailable),
        ),
        sessionCapabilityProvider.overrideWithValue(_Session(permissions)),
        preferencesStorageProvider.overrideWithValue(preferences),
        appStringsProvider.overrideWithValue(
          const AppStrings(AppLocale.english),
        ),
      ],
      child: wrapWidget(const WalletScreen()),
    );
  }

  testWidgets('shows a spinner while the balance is on its way', (
    tester,
  ) async {
    await tester.pumpWidget(subject(repository: _Repository(hang: true)));

    expect(find.byType(AppLoadingState), findsWidgets);
  });

  testWidgets('says so when the wallet cannot be loaded', (tester) async {
    await tester.pumpWidget(subject(repository: _Repository(fail: true)));
    await tester.pumpAndSettle();

    expect(
      find.text(const AppStrings(AppLocale.english).walletLoadFailed),
      findsWidgets,
    );
  });

  testWidgets('says there is no history yet rather than drawing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(subject(repository: _Repository(empty: true)));
    await tester.pumpAndSettle();

    expect(find.text('No top-ups yet'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets(
    'shows the balance, the offer with its fee on top, and the history',
    (tester) async {
      await tester.pumpWidget(subject(repository: _Repository()));
      await tester.pumpAndSettle();

      expect(find.text(r'$10.50'), findsOneWidget);
      expect(find.text(r'$10.00 to your wallet'), findsOneWidget);
      expect(
        find.textContaining(r'Payment fee $1.77 · Total to pay $11.77'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Google Play charges SAR 44.99'),
        findsOneWidget,
      );
      expect(find.text('Buy'), findsOneWidget);
      expect(find.text('Paid'), findsOneWidget);
    },
  );

  testWidgets('offers nothing to buy to a member who may not spend', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(
        repository: _Repository(),
        permissions: const <String>{'read:Wallet'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy'), findsNothing);
    expect(find.text(r'$10.50'), findsOneWidget);
  });

  testWidgets('offers nothing to buy on a device without Google Play', (
    tester,
  ) async {
    await tester.pumpWidget(
      subject(repository: _Repository(), storeAvailable: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy'), findsNothing);
  });
}

final class _Repository implements WalletRepository {
  _Repository({this.hang = false, this.fail = false, this.empty = false});

  final bool hang;
  final bool fail;
  final bool empty;

  Future<T> _answer<T>(T value) {
    if (hang) return Completer<T>().future;
    if (fail) {
      return Future<T>.error(
        const TransportFailure(message: 'offline', isOffline: true),
      );
    }

    return Future<T>.value(value);
  }

  @override
  Future<WalletSummary> fetchSummary() => _answer(
    const WalletSummary(
      currency: 'USD',
      balance: 10.5,
      available: 10.5,
      reserved: 0,
      frozen: false,
    ),
  );

  @override
  Future<List<WalletPayment>> fetchPayments() => _answer(
    empty
        ? const <WalletPayment>[]
        : <WalletPayment>[
            WalletPayment(
              reference: 'REF-1',
              state: 'paid',
              gatewayName: 'Google Play',
              total: 11.77,
              walletCredit: 10,
              fee: 1.77,
              currency: 'USD',
              createdAt: DateTime.utc(2026, 10, 1),
            ),
          ],
  );

  @override
  Future<WalletStatementPage> fetchStatement({String? cursor}) => _answer(
    WalletStatementPage(
      entries: empty
          ? const <WalletEntry>[]
          : <WalletEntry>[
              WalletEntry(
                id: 'e1',
                type: 'topup_credit',
                isCredit: true,
                amount: 10,
                currency: 'USD',
                balanceAfter: 10.5,
                description: null,
                createdAt: DateTime.utc(2026, 10, 1),
              ),
            ],
      nextCursor: null,
    ),
  );

  @override
  Future<List<TopUpOffer>> fetchTopUpOffers() => _answer(const <TopUpOffer>[
    TopUpOffer(
      packageId: 'pkg-10',
      gatewayKey: 'google_play',
      storeProductId: 'wallet_topup_10',
      credit: 10,
      fee: 1.77,
      total: 11.77,
      currency: 'USD',
    ),
  ]);

  @override
  Future<StoreCheckout> startStoreTopUp(TopUpOffer offer) =>
      throw UnimplementedError();

  @override
  Future<WalletPayment> confirmStorePurchase({
    required String reference,
    required String purchaseToken,
  }) => throw UnimplementedError();
}

final class _Store implements StoreBillingPort {
  const _Store({required this.available});

  final bool available;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, String>> localizedPrices(Set<String> productIds) async =>
      <String, String>{for (final String id in productIds) id: 'SAR 44.99'};

  @override
  Future<void> buy({
    required String productId,
    required String obfuscatedProfileId,
  }) async {}

  @override
  Stream<List<StorePurchase>> get purchases =>
      const Stream<List<StorePurchase>>.empty();

  @override
  Future<List<StorePurchase>> unfinishedPurchases() async =>
      const <StorePurchase>[];
}

final class _Session implements SessionCapability {
  _Session(this.permissions);

  final Set<String> permissions;

  @override
  Session? get currentSession => Session(
    user: AuthenticatedUser(
      id: 'u1',
      name: 'Owner',
      email: 'owner@demo.test',
      role: 'owner',
      locale: 'en',
      permissions: permissions,
    ),
  );

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  String? get currentUserId => 'u1';

  @override
  String? get currentWorkspaceId => 'w1';

  @override
  Future<void> signOut() async {}
}
