import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/conversations/domain/value_objects/session_window.dart';

/// The rule itself lives on the server. What is asserted here is the *client's*
/// half: which of the server's three answers closes a composer, and what a
/// phone does with an answer that has gone stale in its pocket.
void main() {
  final DateTime now = DateTime.utc(2026, 9, 21, 12);

  group('a window the server reported as open', () {
    test('is open while its expiry is still ahead', () {
      final window = SessionWindow(
        isOpenPerServer: true,
        expiresAt: now.add(const Duration(hours: 3)),
      );

      expect(window.isClosed(now), isFalse);
      expect(window.remaining(now), const Duration(hours: 3));
    });

    /*
      The case a phone has and a fresh page load does not. The answer was true
      when it was fetched; the server already said when it stops being true.
      Trusting the verdict alone would leave the composer usable for hours
      after the window shut, and the member would find out from a failed send.
    */
    test('closes on its own once the expiry passes, without a sync', () {
      final window = SessionWindow(
        isOpenPerServer: true,
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );

      expect(window.isClosed(now), isTrue);
      expect(window.remaining(now), isNull);
    });

    test('closes exactly at the expiry, not a moment after', () {
      final window = SessionWindow(isOpenPerServer: true, expiresAt: now);

      expect(window.isClosed(now), isTrue);
      expect(window.remaining(now), isNull);
    });

    test('stays open when the server named no expiry', () {
      // Reported open with nothing to expire: a channel the server considers
      // always open. Nothing to count down, nothing to close.
      const window = SessionWindow(isOpenPerServer: true);

      expect(window.isClosed(DateTime.utc(2030)), isFalse);
      expect(window.remaining(DateTime.utc(2030)), isNull);
    });
  });

  group('a window the server reported as closed', () {
    test('is closed, whatever the clock says', () {
      // Including a device whose clock is wrong: the verdict is not re-derived
      // from an expiry this app does not own.
      final window = SessionWindow(
        isOpenPerServer: false,
        lastCustomerMessageAt: now.subtract(const Duration(days: 3)),
      );

      expect(window.isClosed(now), isTrue);
      expect(window.isClosed(now.subtract(const Duration(days: 30))), isTrue);
    });
  });

  group('a window the server did not report', () {
    /*
      A channel with no window, or a server too old to answer. Nothing is
      claimed, so nothing is blocked - the alternative is an app that silently
      disables its own composer against a backend that would have accepted the
      message.
    */
    test('blocks nothing and shows nothing', () {
      expect(SessionWindow.unreported.isReported, isFalse);
      expect(SessionWindow.unreported.isClosed(now), isFalse);
      expect(SessionWindow.unreported.remaining(now), isNull);
    });

    test('is not confused with a closed one', () {
      const closed = SessionWindow(isOpenPerServer: false);

      expect(closed.isReported, isTrue);
      expect(SessionWindow.unreported.isReported, isFalse);
    });
  });

  group('value semantics', () {
    test('two windows carrying the same answer are the same window', () {
      final a = SessionWindow(isOpenPerServer: true, expiresAt: now);
      final b = SessionWindow(isOpenPerServer: true, expiresAt: now);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('copyWith replaces only what it is given', () {
      final window = SessionWindow(
        isOpenPerServer: true,
        expiresAt: now,
        lastCustomerMessageAt: now.subtract(const Duration(hours: 1)),
      );

      final next = window.copyWith(isOpenPerServer: false);

      expect(next.isOpenPerServer, isFalse);
      expect(next.expiresAt, window.expiresAt);
      expect(next.lastCustomerMessageAt, window.lastCustomerMessageAt);
    });
  });
}
