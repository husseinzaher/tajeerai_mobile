import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/caller_id/application/coordinators/caller_lookup_coordinator.dart';
import 'package:TajeerAi/features/caller_id/domain/entities/caller_id_settings.dart';
import 'package:TajeerAi/features/caller_id/domain/entities/caller_identity.dart';
import 'package:TajeerAi/features/caller_id/domain/repositories/caller_lookup_repository.dart';

class _FakeLookupRepository implements CallerLookupRepository {
  _FakeLookupRepository({
    this.cached,
    this.local,
    this.remote,
    this.remoteDelay = Duration.zero,
  });

  final CallerIdentity? cached;
  final CallerIdentity? local;
  final CallerIdentity? remote;
  final Duration remoteDelay;
  int serverCalls = 0;

  @override
  Future<void> cache(CallerIdentity identity, {required DateTime expiresAt}) async {}

  @override
  Future<CallerIdentity?> findCached(String normalizedPhone) async => cached;

  @override
  Future<CallerIdentity?> lookupLocal(String normalizedPhone) async => local;

  @override
  Future<CallerIdentity?> lookupServer(String normalizedPhone) async {
    serverCalls += 1;
    await Future<void>.delayed(remoteDelay);
    return remote;
  }
}

void main() {
  group('CallerLookupCoordinator', () {
    test('returns cached identity immediately', () async {
      const CallerIdentity cached = CallerIdentity(
        phoneNumber: '+966501234567',
        displayName: 'Sara',
        source: CallerIdentitySource.localCache,
      );
      final _FakeLookupRepository repository = _FakeLookupRepository(cached: cached);
      final CallerLookupCoordinator coordinator = CallerLookupCoordinator(
        repository: repository,
      );

      final CallerIdentity? identity = await coordinator.resolve(
        rawPhone: '+966501234567',
        settings: const CallerIdSettings(useCachedData: true),
      );

      expect(identity?.displayName, 'Sara');
      expect(repository.serverCalls, 0);
    });

    test('falls back to unknown when server lookup is disabled', () async {
      final _FakeLookupRepository repository = _FakeLookupRepository();
      final CallerLookupCoordinator coordinator = CallerLookupCoordinator(
        repository: repository,
      );

      final CallerIdentity? identity = await coordinator.resolve(
        rawPhone: '+966501234567',
        settings: const CallerIdSettings(serverLookupEnabled: false),
      );

      expect(identity?.phoneNumber, isNotEmpty);
      expect(identity?.source, CallerIdentitySource.unknown);
      expect(repository.serverCalls, 0);
    });

    test('does not block on a slow server lookup when onUpdate is provided', () async {
      final _FakeLookupRepository repository = _FakeLookupRepository(
        remote: const CallerIdentity(
          phoneNumber: '+966501234567',
          displayName: 'Remote Sara',
          source: CallerIdentitySource.server,
        ),
        remoteDelay: const Duration(seconds: 5),
      );
      final CallerLookupCoordinator coordinator = CallerLookupCoordinator(
        repository: repository,
      );
      CallerIdentity? updated;

      final CallerIdentity? immediate = await coordinator.resolve(
        rawPhone: '+966501234567',
        settings: const CallerIdSettings(serverLookupEnabled: true),
        onUpdate: (CallerIdentity identity) => updated = identity,
      );

      expect(immediate?.source, CallerIdentitySource.unknown);
      expect(updated, isNull);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(repository.serverCalls, 1);
    });
  });
}
