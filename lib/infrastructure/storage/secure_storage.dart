import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key/value storage, backed by the Keychain on iOS and by
/// EncryptedSharedPreferences on Android.
///
/// The only place credentials are allowed to rest. Keys are declared as
/// constants rather than passed as strings at call sites, so the set of
/// secrets the app holds is greppable from one file -- and so a typo cannot
/// silently write a second, never-read entry.
class SecureStorage {
  SecureStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              // Readable only while the device is unlocked, and never
              // restored onto a different device from a backup.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  /// The JWT the socket handshake and the API send.
  static const String accessTokenKey = 'tj_access';

  /// The rotation credential. Long-lived, so it never leaves secure storage.
  static const String refreshTokenKey = 'tj_refresh';

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  /// Wipes every secret. Called on sign-out and whenever the server tells the
  /// client its session is gone.
  Future<void> clear() => _storage.deleteAll();
}
