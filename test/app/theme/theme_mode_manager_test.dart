import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/app/theme/theme_mode_manager.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

/// What the member chose, and what happens when that choice is unreadable.
///
/// The fallback behaviour is the part worth testing. A preference is device
/// state written by whatever build was installed last; it can name a preset
/// that no longer exists, or hold something a bug wrote. None of that may stop
/// the app opening, and none of it may leave the member on a blank screen.
void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final PreferencesStorage preferences = await PreferencesStorage.open();
    // Riverpod 3 does not export `Override`, so this list cannot be typed
    // and cannot be hoisted into a helper's parameter. Inline is the only
    // spelling that compiles.
    final ProviderContainer container = ProviderContainer(
      overrides: [preferencesStorageProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('start-up', () {
    test(
      'a fresh install gets the default preset, following the system',
      () async {
        final ProviderContainer container = await containerWith(
          <String, Object>{},
        );
        final AppThemeSelection selection = container.read(
          themeSelectionProvider,
        );

        expect(selection.preset, TajeerPreset.fallback);
        expect(selection.mode, AppThemeMode.system);
      },
    );

    test('a stored choice is honoured', () async {
      final ProviderContainer container = await containerWith(<String, Object>{
        PreferencesStorage.themePresetKey: 'aurora',
        PreferencesStorage.themeModeKey: 'dark',
      });
      final AppThemeSelection selection = container.read(
        themeSelectionProvider,
      );

      expect(selection.preset, TajeerPreset.aurora);
      expect(selection.mode, AppThemeMode.dark);
    });

    test('a preset this build has never heard of falls back', () async {
      final ProviderContainer container = await containerWith(<String, Object>{
        PreferencesStorage.themePresetKey: 'midnight-carnival',
        PreferencesStorage.themeModeKey: 'dark',
      });
      final AppThemeSelection selection = container.read(
        themeSelectionProvider,
      );

      expect(selection.preset, TajeerPreset.fallback);
      // The mode survives the preset falling back: they are two axes, and one
      // unreadable value must not discard the other.
      expect(selection.mode, AppThemeMode.dark);
    });

    test('an unreadable mode falls back without touching the preset', () async {
      final ProviderContainer container = await containerWith(<String, Object>{
        PreferencesStorage.themePresetKey: 'aurora',
        PreferencesStorage.themeModeKey: 'sepia',
      });
      final AppThemeSelection selection = container.read(
        themeSelectionProvider,
      );

      expect(selection.mode, AppThemeMode.system);
      expect(selection.preset, TajeerPreset.aurora);
    });
  });

  group('choosing', () {
    test(
      'a preset is stored and applied, and the mode is left alone',
      () async {
        final ProviderContainer container = await containerWith(
          <String, Object>{PreferencesStorage.themeModeKey: 'dark'},
        );
        await container
            .read(themeSelectionProvider.notifier)
            .selectPreset(TajeerPreset.aurora);

        expect(
          container.read(themeSelectionProvider).preset,
          TajeerPreset.aurora,
        );
        expect(container.read(themeSelectionProvider).mode, AppThemeMode.dark);
        expect(
          container
              .read(preferencesStorageProvider)
              .readString(PreferencesStorage.themePresetKey),
          'aurora',
        );
      },
    );

    test(
      'a mode is stored and applied, and the preset is left alone',
      () async {
        final ProviderContainer container = await containerWith(
          <String, Object>{PreferencesStorage.themePresetKey: 'aurora'},
        );
        await container
            .read(themeSelectionProvider.notifier)
            .selectMode(AppThemeMode.light);

        expect(container.read(themeSelectionProvider).mode, AppThemeMode.light);
        expect(
          container.read(themeSelectionProvider).preset,
          TajeerPreset.aurora,
        );
      },
    );

    test('choosing what is already chosen writes nothing', () async {
      final ProviderContainer container = await containerWith(
        <String, Object>{},
      );
      await container
          .read(themeSelectionProvider.notifier)
          .selectMode(AppThemeMode.system);

      expect(
        container
            .read(preferencesStorageProvider)
            .readString(PreferencesStorage.themeModeKey),
        isNull,
        reason:
            'a no-op selection persisted a value, so a member who never chose '
            'is now pinned to whatever the default happened to be that release',
      );
    });
  });

  group('the selection reaches Flutter', () {
    test('each mode maps to the ThemeMode Material understands', () {
      expect(AppThemeMode.system.mode, ThemeMode.system);
      expect(AppThemeMode.light.mode, ThemeMode.light);
      expect(AppThemeMode.dark.mode, ThemeMode.dark);
    });

    test('equality is by value, so a rebuild is not a change', () {
      const AppThemeSelection a = AppThemeSelection(
        preset: TajeerPreset.tajeer,
        mode: AppThemeMode.dark,
      );
      const AppThemeSelection b = AppThemeSelection(
        preset: TajeerPreset.tajeer,
        mode: AppThemeMode.dark,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(mode: AppThemeMode.light), isNot(b));
    });
  });
}
