import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/storage/preferences_storage.dart';
import '../bootstrap/dependencies.dart';
import 'tokens.g.dart';

/// Light, dark, or whatever the platform is doing.
enum AppThemeMode {
  system('system', ThemeMode.system),
  light('light', ThemeMode.light),
  dark('dark', ThemeMode.dark);

  const AppThemeMode(this.code, this.mode);

  final String code;
  final ThemeMode mode;

  /// Falls back rather than throwing. A preference written by an older build,
  /// or corrupted, must not stop the app opening.
  static AppThemeMode fromCode(String? code) => AppThemeMode.values.firstWhere(
    (AppThemeMode mode) => mode.code == code,
    orElse: () => AppThemeMode.system,
  );
}

/// What the member has chosen to look at: a preset, and a mode within it.
///
/// Two independent axes. The preset decides the identity — Tajeer's yellow or
/// the original indigo — and the mode decides day or night within it, so a
/// member who prefers dark keeps that preference across a change of identity.
@immutable
class AppThemeSelection {
  const AppThemeSelection({required this.preset, required this.mode});

  final TajeerPreset preset;
  final AppThemeMode mode;

  AppThemeSelection copyWith({TajeerPreset? preset, AppThemeMode? mode}) =>
      AppThemeSelection(preset: preset ?? this.preset, mode: mode ?? this.mode);

  @override
  bool operator ==(Object other) =>
      other is AppThemeSelection &&
      other.preset == preset &&
      other.mode == mode;

  @override
  int get hashCode => Object.hash(preset, mode);
}

final NotifierProvider<ThemeModeManager, AppThemeSelection>
themeSelectionProvider = NotifierProvider<ThemeModeManager, AppThemeSelection>(
  ThemeModeManager.new,
);

/// Reads the stored choice at start-up and writes every change back.
///
/// Reading in [build] is safe because `PreferencesStorage.open()` is awaited in
/// `main()` before `runApp`, so the value is there for the first frame — the
/// same guarantee `LocaleManager` relies on, and the reason neither is a
/// `FutureProvider`. A theme resolved one frame late is a visible flash.
class ThemeModeManager extends Notifier<AppThemeSelection> {
  @override
  AppThemeSelection build() {
    final PreferencesStorage preferences = ref.watch(
      preferencesStorageProvider,
    );
    return AppThemeSelection(
      preset: TajeerPreset.fromName(
        preferences.readString(PreferencesStorage.themePresetKey),
      ),
      mode: AppThemeMode.fromCode(
        preferences.readString(PreferencesStorage.themeModeKey),
      ),
    );
  }

  Future<void> selectMode(AppThemeMode mode) async {
    if (state.mode == mode) {
      return;
    }
    await ref
        .read(preferencesStorageProvider)
        .writeString(PreferencesStorage.themeModeKey, mode.code);
    state = state.copyWith(mode: mode);
  }

  Future<void> selectPreset(TajeerPreset preset) async {
    if (state.preset == preset) {
      return;
    }
    await ref
        .read(preferencesStorageProvider)
        .writeString(PreferencesStorage.themePresetKey, preset.name);
    state = state.copyWith(preset: preset);
  }
}
