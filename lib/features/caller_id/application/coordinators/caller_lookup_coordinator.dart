import 'dart:async';

import '../../domain/entities/caller_identity.dart';
import '../../domain/entities/caller_id_settings.dart';
import '../../domain/repositories/caller_lookup_repository.dart';
import '../../domain/value_objects/normalized_phone.dart';

/// Resolves a ringing number into identity without blocking Telecom.
class CallerLookupCoordinator {
  CallerLookupCoordinator({required CallerLookupRepository repository})
    : _repository = repository;

  final CallerLookupRepository _repository;

  static const Duration serverTimeout = Duration(milliseconds: 1200);
  static const Duration cacheTtl = Duration(days: 7);

  /// Returns the best identity available immediately, then optionally refines
  /// it through [onUpdate] when a slower lookup completes.
  Future<CallerIdentity?> resolve({
    required String rawPhone,
    required CallerIdSettings settings,
    void Function(CallerIdentity identity)? onUpdate,
  }) async {
    final NormalizedPhone? phone = NormalizedPhone.parse(rawPhone);

    if (phone == null) {
      return CallerIdentity(
        phoneNumber: rawPhone,
        displayName: null,
        source: CallerIdentitySource.unknown,
      );
    }

    final String key = phone.e164;

    if (settings.useCachedData) {
      final CallerIdentity? cached = await _repository.findCached(key);

      if (cached != null) return cached;
    }

    CallerIdentity? identity;

    if (settings.localLookupEnabled) {
      identity = await _repository.lookupLocal(key);
    }

    if (identity != null) {
      await _repository.cache(
        identity,
        expiresAt: DateTime.now().add(cacheTtl),
      );

      return identity;
    }

    if (settings.serverLookupEnabled && onUpdate != null) {
      unawaited(
        _lookupServerWithTimeout(
          key,
          onUpdate: onUpdate,
        ),
      );
    } else if (settings.serverLookupEnabled) {
      identity = await _lookupServerWithTimeout(key);
    }

    return identity ??
        CallerIdentity(
          phoneNumber: key,
          source: CallerIdentitySource.unknown,
        );
  }

  Future<CallerIdentity?> _lookupServerWithTimeout(
    String normalizedPhone, {
    void Function(CallerIdentity identity)? onUpdate,
  }) async {
    try {
      final CallerIdentity? remote = await _repository
          .lookupServer(normalizedPhone)
          .timeout(serverTimeout);

      if (remote != null) {
        onUpdate?.call(remote);
      }

      return remote;
    } on Object {
      return null;
    }
  }
}
