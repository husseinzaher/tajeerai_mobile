/// A clock that does not move, for deterministic timestamp assertions.
///
/// Everything in this codebase that reads the time takes a `DateTime
/// Function()` rather than calling `DateTime.now()` directly, which is what
/// makes backoff, cursors and ordering testable without sleeping.
class FixedClock {
  FixedClock(this._now);

  DateTime _now;

  DateTime call() => _now;

  /// Moves time forward, so a test can assert on what happens after a backoff
  /// without waiting for one.
  void advance(Duration duration) => _now = _now.add(duration);

  set now(DateTime value) => _now = value;
}

/// A fixed instant used across the suite, so expected values can be written
/// out rather than computed.
final DateTime testEpoch = DateTime.utc(2026, 3, 1, 12);
