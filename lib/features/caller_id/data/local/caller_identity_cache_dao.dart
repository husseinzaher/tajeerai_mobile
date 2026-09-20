import 'package:drift/drift.dart';

import '../../../../infrastructure/database/app_database.dart';
import '../../domain/entities/caller_identity.dart';
import 'caller_identity_cache_tables.dart';

part 'caller_identity_cache_dao.g.dart';

@DriftAccessor(tables: <Type>[CallerIdentityCaches])
class CallerIdentityCacheDao extends DatabaseAccessor<AppDatabase>
    with _$CallerIdentityCacheDaoMixin {
  CallerIdentityCacheDao(super.db);

  Future<CallerIdentityCache?> findByPhone(String normalizedPhone) {
    return (select(callerIdentityCaches)..where(
          ($CallerIdentityCachesTable tbl) =>
              tbl.normalizedPhone.equals(normalizedPhone),
        ))
        .getSingleOrNull();
  }

  Future<void> upsert(CallerIdentity identity, {required DateTime expiresAt}) {
    return into(callerIdentityCaches).insertOnConflictUpdate(
      CallerIdentityCachesCompanion.insert(
        normalizedPhone: identity.phoneNumber,
        displayName: Value(identity.displayName),
        businessName: Value(identity.businessName),
        avatarUrl: Value(identity.avatarUrl),
        spamStatus: Value(identity.spamStatus.name),
        tagsJson: Value(_encodeTags(identity.tags)),
        source: Value(identity.source.name),
        customerId: Value(identity.customerId),
        fetchedAt: DateTime.now(),
        expiresAt: expiresAt,
      ),
    );
  }

  static String _encodeTags(List<String> tags) {
    if (tags.isEmpty) return '[]';

    return '[${tags.map((String tag) => '"${tag.replaceAll('"', r'\"')}"').join(',')}]';
  }
}
