import 'package:shared_preferences/shared_preferences.dart';

/// Unencrypted device-local settings.
///
/// Strictly for things that are not secret and not business data: the chosen
/// theme and locale. Business data lives in the database, credentials live in
/// [SecureStorage], and nothing else belongs here -- a preferences store is
/// the classic place for an app's state to quietly fork away from its
/// database.
class PreferencesStorage {
  PreferencesStorage(this._preferences);

  final SharedPreferences _preferences;

  static Future<PreferencesStorage> open() async =>
      PreferencesStorage(await SharedPreferences.getInstance());

  static const String themeModeKey = 'settings.themeMode';
  static const String localeKey = 'settings.locale';

  String? readString(String key) => _preferences.getString(key);

  Future<void> writeString(String key, String value) =>
      _preferences.setString(key, value);

  Future<void> remove(String key) => _preferences.remove(key);
}
