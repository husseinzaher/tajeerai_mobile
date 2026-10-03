import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/wallet/domain/entities/wallet.dart';
import 'package:TajeerAi/infrastructure/adapters/wallet/models/wallet_dto.dart';

/// The wallet's wire format, decoded the way the backend actually sends it -
/// `WalletSummaryDto`, `WalletStatementDto`, `PaymentDto` and
/// `TopUpOptionsDto` in `backend/src/modules/{wallet,billing}`.
void main() {
  group('summary', () {
    test('reads balance, available, reserved and a frozen status', () {
      final WalletSummary summary = WalletDto.decodeSummary(<String, Object?>{
        'currency': 'USD',
        'status': 'frozen',
        'balance': 12.5,
        'reserved': 2,
        'available': 10.5,
        'aiAllowance': null,
      });

      expect(summary.balance, 12.5);
      expect(summary.available, 10.5);
      expect(summary.reserved, 2);
      expect(summary.frozen, isTrue);
    });

    test('refuses a summary with no balance rather than show zero', () {
      expect(
        () => WalletDto.decodeSummary(<String, Object?>{'currency': 'USD'}),
        throwsFormatException,
      );
    });
  });

  test('statement skips an unreadable row and keeps the rest', () {
    final WalletStatementPage page = WalletDto.decodeStatement(
      <String, Object?>{
        'entries': <Object?>[
          <String, Object?>{
            'id': 'e1',
            'type': 'topup_credit',
            'direction': 'credit',
            'amount': 10,
            'currency': 'USD',
            'balanceAfter': 10,
            'description': null,
            'createdAt': '2026-10-03T10:00:00.000Z',
          },
          <String, Object?>{'id': 'broken'},
        ],
        'nextCursor': 'e1',
      },
    );

    expect(page.entries, hasLength(1));
    expect(page.entries.single.isCredit, isTrue);
    expect(page.nextCursor, 'e1');
  });

  test('a payment carries the credit and the fee on top separately', () {
    final WalletPayment payment = WalletDto.decodePayment(<String, Object?>{
      'reference': 'REF-1',
      'state': 'paid',
      'gatewayName': 'Google Play',
      'expectedAmount': 11.77,
      'walletCredit': 10,
      'fee': 1.77,
      'currency': 'USD',
      'createdAt': '2026-10-03T10:00:00.000Z',
    });

    expect(payment.total, 11.77);
    expect(payment.walletCredit, 10);
    expect(payment.fee, 1.77);
    expect(payment.isPaid, isTrue);
  });

  group('offers', () {
    Map<String, Object?> options({Object? productId = 'wallet_topup_10'}) =>
        <String, Object?>{
          'currency': 'USD',
          'minimum': 5,
          'allowsCustomAmount': false,
          'methods': <Object?>[
            <String, Object?>{'key': 'google_play', 'type': 'app_store'},
          ],
          'packages': <Object?>[
            <String, Object?>{
              'id': 'pkg-10',
              'credit': 10,
              'currency': 'USD',
              'storeProductId': productId,
              'quotes': <Object?>[
                <String, Object?>{
                  'gatewayKey': 'google_play',
                  'credit': 10,
                  'fee': 1.77,
                  'total': 11.77,
                  'currency': 'USD',
                },
              ],
            },
          ],
        };

    test('one offer per package the store can sell', () {
      final List<TopUpOffer> offers = WalletDto.decodeOffers(options());

      expect(offers, hasLength(1));
      expect(offers.single.storeProductId, 'wallet_topup_10');
      expect(offers.single.credit, 10);
      expect(offers.single.fee, 1.77);
      expect(offers.single.total, 11.77);
    });

    test('a package with no store product is not offered', () {
      expect(WalletDto.decodeOffers(options(productId: null)), isEmpty);
    });
  });

  group('checkout', () {
    test('reads the store handoff', () {
      final StoreCheckout checkout = WalletDto.decodeCheckout(<String, Object?>{
        'reference': 'REF-1',
        'handoff': <String, Object?>{
          'kind': 'store',
          'store': 'google_play',
          'productId': 'wallet_topup_10',
          'obfuscatedProfileId': 'REF-1',
        },
      });

      expect(checkout.productId, 'wallet_topup_10');
      expect(checkout.obfuscatedProfileId, 'REF-1');
    });

    test('refuses any other handoff - nothing to buy in the store', () {
      expect(
        () => WalletDto.decodeCheckout(<String, Object?>{
          'reference': 'REF-1',
          'handoff': <String, Object?>{'kind': 'redirect', 'url': 'https://x'},
        }),
        throwsFormatException,
      );
    });
  });
}
