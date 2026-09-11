import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/auth/data/local/auth_local_data_source.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/conversations/data/local/conversation_tables.dart';
import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';
import 'package:tajeerai_mobile/infrastructure/storage/secure_storage.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import 'fakes/in_memory_secure_storage.dart';

const _session = Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada Lovelace',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
  ),
  workspace: Workspace(id: 't1', name: 'Demo', slug: 'demo', locale: 'ar'),
);

void main() {
  late AppDatabase database;
  late InMemorySecureStorage secureStorage;
  late AuthLocalDataSource local;

  setUp(() {
    database = openTestDatabase();
    secureStorage = InMemorySecureStorage();
    local = AuthLocalDataSource(
      database: database,
      secureStorage: secureStorage,
    );
  });

  tearDown(() => database.close());

  group('clear', () {
    test('forgets the session, the workspace data and the tokens', () async {
      await local.saveSession(_session, now: testEpoch);
      await database
          .into(database.conversations)
          .insert(
            ConversationsCompanion.insert(
              id: 'c1',
              state: ConversationStateRow.open,
              createdAt: testEpoch,
            ),
          );
      await secureStorage.write(SecureStorage.accessTokenKey, 'access-1');
      await secureStorage.write(SecureStorage.refreshTokenKey, 'refresh-1');

      await local.clear();

      // Whoever signs in next on this phone starts from nothing: no session
      // to resume, no conversation from the last workspace, no credential.
      expect(await database.select(database.sessionUsers).get(), isEmpty);
      expect(await database.select(database.conversations).get(), isEmpty);
      expect(await local.readAccessToken(), isNull);
      expect(await secureStorage.read(SecureStorage.refreshTokenKey), isNull);
    });
  });
}
