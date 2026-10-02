import 'package:TajeerAi/infrastructure/storage/secure_storage.dart';

/// A [SecureStorage] backed by a map.
///
/// The real one talks to the Keychain and to EncryptedSharedPreferences, which
/// need a platform channel no unit test has.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
