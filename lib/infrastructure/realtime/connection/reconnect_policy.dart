import 'dart:math';

/// How long to wait before the next reconnection attempt.
///
/// Exponential backoff with full jitter. The jitter is not decoration: without
/// it, every client disconnected by one server restart comes back in the same
/// instant and knocks it over again. Randomising across the whole window
/// spreads the herd.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
  });

  final Duration initialDelay;

  /// The ceiling. A phone that has been in a tunnel for an hour should retry
  /// every thirty seconds, not every hour.
  final Duration maxDelay;

  final double multiplier;

  /// The wait before attempt number [attempt], counting from zero.
  ///
  /// [random] is injectable so the backoff is testable without a flaky
  /// assertion on a random value.
  Duration delayFor(int attempt, {Random? random}) {
    if (attempt <= 0) return Duration.zero;

    final exponential =
        initialDelay.inMilliseconds * pow(multiplier, attempt - 1);
    final capped = min(
      exponential.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );

    // Full jitter: anywhere in [0, capped].
    final jittered = (random ?? Random()).nextDouble() * capped;

    return Duration(milliseconds: jittered.round());
  }
}
