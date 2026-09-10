import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ds_messages.dart';
import 'ds_messages_ar.dart';
import 'ds_messages_en.dart';

const Map<String, AppMessages> appBuiltInMessages = <String, AppMessages>{
  'en': appMessagesEn,
  'ar': appMessagesAr,
};

/// Delivers [AppMessages] to the tree.
///
/// A `LocalizationsDelegate`, not a `ThemeExtension` and not a bespoke
/// `InheritedWidget`. Copy is not a theme — light and dark would carry
/// duplicate strings and a change of language would mean rebuilding
/// `ThemeData` — and reinventing `Localizations` when
/// `flutter_localizations` is already wired up is work for no gain.
///
/// The fallback is the load-bearing part. A tree with no delegate resolves to
/// the locale's built-in table, or to English: without that, every widget test
/// built by a bare harness would throw, and a component would be untestable
/// without ceremony that has nothing to do with what is being tested.
abstract final class AppDesignSystemLocalizations {
  static const LocalizationsDelegate<AppMessages> delegate = _Delegate();

  static AppMessages of(BuildContext context) =>
      Localizations.of<AppMessages>(context, AppMessages) ??
      forLocale(Localizations.maybeLocaleOf(context));

  static AppMessages forLocale(Locale? locale) =>
      appBuiltInMessages[locale?.languageCode] ?? appMessagesEn;
}

class _Delegate extends LocalizationsDelegate<AppMessages> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      appBuiltInMessages.containsKey(locale.languageCode);

  @override
  Future<AppMessages> load(Locale locale) => SynchronousFuture<AppMessages>(
    AppDesignSystemLocalizations.forLocale(locale),
  );

  @override
  bool shouldReload(_Delegate old) => false;
}

/// `context.strings.retry`, beside `context.colors` and `context.type`.
extension AppMessagesContext on BuildContext {
  AppMessages get strings => AppDesignSystemLocalizations.of(this);
}
