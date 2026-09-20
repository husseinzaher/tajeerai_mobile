import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/infrastructure/database/app_database.dart';
import 'package:TajeerAi/infrastructure/database/migrations/schema_migrations.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

/// Upgrades, tested against the schema each version actually shipped with.
///
/// `generated/` is written by `make migrations` from the snapshots in
/// `drift_schemas/`. Each test opens a database exactly as an old version left
/// it, then runs the app's real upgrade over it.
void main() {
  // Every upgrade test opens the old database and then the app's.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('the newest snapshot is the schema in code', () async {
    // A table changed without a new version and snapshot ships a schema no
    // upgrade produces: a fresh install gets one shape, an upgraded phone
    // another.
    expect(GeneratedHelper.versions.last, SchemaMigrations.version);

    final schema = await verifier.schemaAt(SchemaMigrations.version);
    final AppDatabase database = AppDatabase(schema.newConnection());
    addTearDown(database.close);

    await verifier.migrateAndValidate(database, SchemaMigrations.version);
  });

  group('an upgrade ends at exactly what a new install creates', () {
    const List<int> versions = GeneratedHelper.versions;

    for (final (int index, int from) in versions.indexed) {
      for (final int to in versions.skip(index + 1)) {
        test('from v$from to v$to', () async {
          final schema = await verifier.schemaAt(from);
          final AppDatabase database = AppDatabase(schema.newConnection());
          addTearDown(database.close);

          await verifier.migrateAndValidate(database, to);
        });
      }
    }
  });

  test('v1 to v2 keeps every sync state, with nothing to resume', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (Batch batch, v1.DatabaseAtV1 old) {
        batch.insertAll(old.syncStates, <v1.SyncStatesCompanion>[
          v1.SyncStatesCompanion.insert(
            scope: 'conversations',
            syncedAt: const Value<String?>('2026-09-01T08:00:00.000Z'),
            status: const Value<String>('synchronized'),
            lastAttemptAt: const Value<String?>('2026-09-01T08:00:02.000Z'),
          ),
          v1.SyncStatesCompanion.insert(
            scope: 'messages:c1',
            status: const Value<String>('failed'),
            lastError: const Value<String?>('offline'),
          ),
        ]);
      },
      validateItems: (v2.DatabaseAtV2 migrated) async {
        final List<v2.SyncStatesData> rows =
            await (migrated.select(migrated.syncStates)
                  ..orderBy(<OrderClauseGenerator<v2.SyncStates>>[
                    (v2.SyncStates table) =>
                        OrderingTerm(expression: table.scope),
                  ]))
                .get();

        // The cursors a phone already had must survive: losing one sends
        // that scope back to a full first pass.
        expect(rows, const <v2.SyncStatesData>[
          v2.SyncStatesData(
            scope: 'conversations',
            syncedAt: '2026-09-01T08:00:00.000Z',
            status: 'synchronized',
            lastAttemptAt: '2026-09-01T08:00:02.000Z',
          ),
          v2.SyncStatesData(
            scope: 'messages:c1',
            status: 'failed',
            lastError: 'offline',
          ),
        ]);
      },
    );
  });

  test('v2 to v3 keeps the cached session, with nothing withheld', () async {
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (Batch batch, v2.DatabaseAtV2 old) {
        batch.insert(
          old.sessionUsers,
          v2.SessionUsersCompanion.insert(
            id: 'u1',
            name: 'Ada Lovelace',
            email: 'ada@demo.test',
            role: 'owner',
            locale: 'ar',
            permissions: const Value<String>('["manage:all"]'),
            tenantId: const Value<String?>('t1'),
            tenantName: const Value<String?>('Demo'),
            updatedAt: '2026-09-01T08:00:00.000Z',
          ),
        );
      },
      validateItems: (v3.DatabaseAtV3 migrated) async {
        // A member signed in before the upgrade is still signed in after it,
        // holding what they held, until the next session read names anything
        // withheld.
        expect(
          await migrated.select(migrated.sessionUsers).get(),
          const <v3.SessionUsersData>[
            v3.SessionUsersData(
              id: 'u1',
              name: 'Ada Lovelace',
              email: 'ada@demo.test',
              role: 'owner',
              locale: 'ar',
              isPlatformAdmin: 0,
              permissions: '["manage:all"]',
              denied: '[]',
              tenantId: 't1',
              tenantName: 'Demo',
              updatedAt: '2026-09-01T08:00:00.000Z',
            ),
          ],
        );
      },
    );
  });
}
