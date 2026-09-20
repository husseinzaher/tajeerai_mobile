import '../entities/caller_identity.dart';

/// Reads and writes caller identity data for the Caller Card.
abstract interface class CallerLookupRepository {
  Future<CallerIdentity?> findCached(String normalizedPhone);

  Future<void> cache(CallerIdentity identity, {required DateTime expiresAt});

  Future<CallerIdentity?> lookupLocal(String normalizedPhone);

  Future<CallerIdentity?> lookupServer(String normalizedPhone);
}
