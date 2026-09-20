import 'dart:convert';

import '../../../../infrastructure/storage/preferences_storage.dart';
import '../../domain/entities/caller_id_settings.dart';

/// Persists Caller ID settings through the app's preferences abstraction.
class CallerIdSettingsStore {
  CallerIdSettingsStore(this._preferences);

  final PreferencesStorage _preferences;

  static const String settingsKey = 'settings.callerId';

  Future<CallerIdSettings> read() async {
    final String? raw = _preferences.readString(settingsKey);

    if (raw == null || raw.isEmpty) return const CallerIdSettings();

    try {
      final Object? decoded = jsonDecode(raw);

      if (decoded is Map<String, Object?>) {
        return CallerIdSettings.fromJson(decoded);
      }
    } on Object {
      // Corrupt settings fall back to defaults rather than blocking settings.
    }

    return const CallerIdSettings();
  }

  Future<void> write(CallerIdSettings settings) {
    return _preferences.writeString(
      settingsKey,
      jsonEncode(settings.toJson()),
    );
  }
}
