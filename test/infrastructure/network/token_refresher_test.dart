import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/network/token_refresher.dart';

/// A renewer that holds every renewal open until the test answers it.
class _GatedRenewer implements CredentialRenewer {
  final List<Completer<RefreshOutcome>> pending = <Completer<RefreshOutcome>>[];

  @override
  Future<RefreshOutcome> renew() {
    final Completer<RefreshOutcome> renewal = Completer<RefreshOutcome>();
    pending.add(renewal);

    return renewal.future;
  }
}

void main() {
  late _GatedRenewer renewer;
  late TokenRefresher refresher;

  setUp(() {
    renewer = _GatedRenewer();
    refresher = TokenRefresher(renewer);
  });

  test('a caller arriving during a renewal waits for that one', () async {
    final Future<RefreshOutcome> first = refresher.refresh();
    final Future<RefreshOutcome> second = refresher.refresh();

    // One renewal, not two: the refresh token it spends is single-use.
    expect(renewer.pending, hasLength(1));

    renewer.pending.single.complete(const TokenRefreshed('token-2'));

    expect(await first, isA<TokenRefreshed>());
    expect(await second, same(await first));
  });

  test('a renewal after the last one finished starts afresh', () async {
    final Future<RefreshOutcome> first = refresher.refresh();
    renewer.pending.single.complete(const RefreshUnavailable());
    await first;

    final Future<RefreshOutcome> second = refresher.refresh();
    expect(renewer.pending, hasLength(2));

    renewer.pending.last.complete(const TokenRefreshed('token-3'));
    expect(await second, isA<TokenRefreshed>());
  });

  test('a renewal that throws does not wedge the next one', () async {
    final Future<RefreshOutcome> first = refresher.refresh();
    renewer.pending.single.completeError(StateError('boom'));
    await expectLater(first, throwsStateError);

    final Future<RefreshOutcome> second = refresher.refresh();
    expect(renewer.pending, hasLength(2));

    renewer.pending.last.complete(const RefreshRejected());
    expect(await second, isA<RefreshRejected>());
  });
}
