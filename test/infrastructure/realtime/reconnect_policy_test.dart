import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/connection/connection_state.dart';
import 'package:tajeerai_mobile/infrastructure/realtime/connection/reconnect_policy.dart';

void main() {
  group('ReconnectPolicy', () {
    const policy = ReconnectPolicy();

    test('does not wait before the first attempt', () {
      expect(policy.delayFor(0), Duration.zero);
    });

    test('stays within the exponential envelope', () {
      // Full jitter picks anywhere in [0, capped], so the assertion is on the
      // ceiling rather than on an exact value -- a test that pinned the delay
      // would be asserting on `Random`.
      final random = Random(7);

      for (var attempt = 1; attempt <= 10; attempt++) {
        final delay = policy.delayFor(attempt, random: random);

        expect(delay, greaterThanOrEqualTo(Duration.zero));
        expect(delay, lessThanOrEqualTo(policy.maxDelay));
      }
    });

    test('never exceeds the ceiling however many attempts have failed', () {
      final random = Random(1);

      // A phone that has been in a tunnel for an hour should retry every
      // thirty seconds, not every hour.
      final delay = policy.delayFor(50, random: random);

      expect(delay, lessThanOrEqualTo(policy.maxDelay));
    });

    test('produces a spread rather than one fixed delay', () {
      final random = Random(3);

      final delays = List<int>.generate(
        20,
        (_) => policy.delayFor(6, random: random).inMilliseconds,
      );

      // Without jitter every client disconnected by one server restart comes
      // back in the same instant and knocks it over again.
      expect(delays.toSet().length, greaterThan(1));
    });

    test('grows with the attempt count on average', () {
      final random = Random(11);

      int average(int attempt) {
        final samples = List<int>.generate(
          200,
          (_) => policy.delayFor(attempt, random: random).inMilliseconds,
        );

        return samples.reduce((a, b) => a + b) ~/ samples.length;
      }

      expect(average(5), greaterThan(average(2)));
    });

    test('honours a custom initial delay', () {
      const fast = ReconnectPolicy(
        initialDelay: Duration(milliseconds: 10),
        maxDelay: Duration(milliseconds: 20),
      );

      expect(
        fast.delayFor(1, random: Random(1)),
        lessThanOrEqualTo(const Duration(milliseconds: 20)),
      );
    });
  });

  group('SocketConnectionState', () {
    test('only a connected socket may send', () {
      expect(SocketConnectionState.connected.canSend, isTrue);

      // Queueing is the outbox's job; a second queue in the transport would
      // retry the same command from two places.
      expect(SocketConnectionState.reconnecting.canSend, isFalse);
      expect(SocketConnectionState.disconnected.canSend, isFalse);
      expect(SocketConnectionState.unauthenticated.canSend, isFalse);
    });

    test('distinguishes a first connection from a reconnection', () {
      // Reconnecting means the client already holds data, so the UI keeps
      // showing it rather than falling back to a first-run empty state.
      expect(SocketConnectionState.connecting.isTransient, isTrue);
      expect(SocketConnectionState.reconnecting.isTransient, isTrue);
      expect(SocketConnectionState.connected.isTransient, isFalse);
      expect(SocketConnectionState.unauthenticated.isTransient, isFalse);
    });
  });
}
