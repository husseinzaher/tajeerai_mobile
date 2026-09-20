import '../../../../infrastructure/database/app_database.dart';
import '../../../customers/application/contracts/customer_directory_capability.dart';
import '../../domain/entities/caller_identity.dart';
import '../../domain/repositories/caller_lookup_repository.dart';
import '../../domain/value_objects/normalized_phone.dart';
import '../local/caller_identity_cache_dao.dart';
import '../remote/caller_lookup_remote_data_source.dart';

class CallerLookupRepositoryImpl implements CallerLookupRepository {
  CallerLookupRepositoryImpl({
    required CallerIdentityCacheDao cache,
    required CustomerDirectoryCapability directory,
    required CallerLookupRemoteDataSource remote,
  }) : _cache = cache,
       _directory = directory,
       _remote = remote;

  final CallerIdentityCacheDao _cache;
  final CustomerDirectoryCapability _directory;
  final CallerLookupRemoteDataSource _remote;

  static const Duration cacheTtl = Duration(days: 7);

  @override
  Future<CallerIdentity?> findCached(String normalizedPhone) async {
    final CallerIdentityCache? row = await _cache.findByPhone(normalizedPhone);

    if (row == null) return null;
    if (row.expiresAt.isBefore(DateTime.now())) return null;

    return _fromRow(row);
  }

  @override
  Future<void> cache(CallerIdentity identity, {required DateTime expiresAt}) {
    return _cache.upsert(identity, expiresAt: expiresAt);
  }

  @override
  Future<CallerIdentity?> lookupLocal(String normalizedPhone) async {
    final NormalizedPhone? phone = NormalizedPhone.parse(normalizedPhone);

    if (phone == null) return null;

    final match = await _directory.findByPhone(phone.raw);

    if (match == null) return null;

    return CallerIdentity(
      phoneNumber: normalizedPhone,
      displayName: match.displayName,
      businessName: match.typeName,
      avatarUrl: match.photoUrl,
      tags: match.tags,
      source: CallerIdentitySource.localCustomer,
      customerId: match.id,
    );
  }

  @override
  Future<CallerIdentity?> lookupServer(String normalizedPhone) async {
    final CallerIdentity? remote = await _remote.lookup(normalizedPhone);

    if (remote == null) return null;

    await cache(remote, expiresAt: DateTime.now().add(cacheTtl));

    return remote;
  }

  CallerIdentity _fromRow(CallerIdentityCache row) {
    return CallerIdentity(
      phoneNumber: row.normalizedPhone,
      displayName: row.displayName,
      businessName: row.businessName,
      avatarUrl: row.avatarUrl,
      spamStatus: CallerSpamStatus.values.firstWhere(
        (CallerSpamStatus value) => value.name == row.spamStatus,
        orElse: () => CallerSpamStatus.unknown,
      ),
      tags: _decodeTags(row.tagsJson),
      source: CallerIdentitySource.values.firstWhere(
        (CallerIdentitySource value) => value.name == row.source,
        orElse: () => CallerIdentitySource.localCache,
      ),
      customerId: row.customerId,
    );
  }

  static List<String> _decodeTags(String raw) {
    if (raw.isEmpty || raw == '[]') return const <String>[];

    return raw
        .replaceAll('[', '')
        .replaceAll(']', '')
        .split(',')
        .map((String part) => part.trim().replaceAll('"', ''))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
  }
}
