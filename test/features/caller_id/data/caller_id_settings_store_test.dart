import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/features/caller_id/data/local/caller_id_settings_store.dart';
import 'package:TajeerAi/features/caller_id/domain/entities/caller_id_settings.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

void main() {
  group('CallerIdSettingsStore', () {
    late PreferencesStorage preferences;
    late CallerIdSettingsStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      preferences = await PreferencesStorage.open();
      store = CallerIdSettingsStore(preferences);
    });

    test('returns defaults when nothing is stored', () async {
      final CallerIdSettings settings = await store.read();

      expect(settings.enabled, isFalse);
      expect(settings.showIncoming, isTrue);
    });

    test('persists and reads settings', () async {
      const CallerIdSettings saved = CallerIdSettings(
        enabled: true,
        showIncoming: false,
        autoDismissSeconds: 30,
      );

      await store.write(saved);

      final CallerIdSettings restored = await store.read();

      expect(restored.enabled, isTrue);
      expect(restored.showIncoming, isFalse);
      expect(restored.autoDismissSeconds, 30);
    });
  });
}
