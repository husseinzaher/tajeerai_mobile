import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/dependencies.dart';
import '../../infrastructure/storage/preferences_storage.dart';

/// The locales the app ships.
///
/// Arabic first, and it is the default -- the design system's own rule is that
/// Arabic is a first-class locale, not a translation of an English original.
/// Every layout in this app uses logical directions (`start`/`end`,
/// `EdgeInsetsDirectional`) so the same widgets mirror without a second build.
enum AppLocale {
  arabic('ar', TextDirection.rtl, 'العربية'),
  english('en', TextDirection.ltr, 'English');

  const AppLocale(this.code, this.direction, this.nativeName);

  final String code;
  final TextDirection direction;

  /// The language's name in that language: `العربية`, `English`.
  ///
  /// A property of the locale, not a translation. A language switcher lists
  /// each option in its own script so that somebody who cannot read the
  /// current one can still find theirs — which is the entire point of the
  /// control.
  final String nativeName;

  Locale get locale => Locale(code);

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (locale) => locale.code == code,
      orElse: () => AppLocale.arabic,
    );
  }

  static List<Locale> get supported =>
      AppLocale.values.map((value) => value.locale).toList(growable: false);
}

/// The active locale.
///
/// Persisted in preferences rather than the database: it is a device setting,
/// not workspace data, and it has to be readable before the database opens so
/// the first frame is drawn in the right direction.
final NotifierProvider<LocaleManager, AppLocale> localeProvider =
    NotifierProvider<LocaleManager, AppLocale>(LocaleManager.new);

class LocaleManager extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    final stored = ref
        .watch(preferencesStorageProvider)
        .readString(PreferencesStorage.localeKey);

    return AppLocale.fromCode(stored);
  }

  Future<void> select(AppLocale locale) async {
    if (state == locale) return;

    await ref
        .read(preferencesStorageProvider)
        .writeString(PreferencesStorage.localeKey, locale.code);

    state = locale;
  }

  /// Adopts the locale the server says the user prefers.
  ///
  /// Only on first sign-in, and only when the user has not chosen for
  /// themselves -- overriding a deliberate choice with a server default every
  /// time the app starts would be a bug, not a feature.
  Future<void> adoptFromSession(String serverLocale) async {
    final stored = ref
        .read(preferencesStorageProvider)
        .readString(PreferencesStorage.localeKey);

    if (stored != null) return;

    await select(AppLocale.fromCode(serverLocale));
  }
}
