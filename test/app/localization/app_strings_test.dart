import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';

/// The Arabic-first half of the product's copy.
///
/// Arabic is the default locale, so a key with no Arabic is not a minor gap —
/// it is the string most people using the app will see in the wrong language.
void main() {
  test('every key has both languages, and neither is blank', () {
    for (final MapEntry<String, Map<String, String>> entry
        in AppStrings.table.entries) {
      for (final String code in <String>['en', 'ar']) {
        final String? value = entry.value[code];
        expect(value, isNotNull, reason: '${entry.key} has no $code');
        expect(
          value!.trim(),
          isNotEmpty,
          reason: '${entry.key} $code is blank',
        );
      }
    }
  });

  test('the Arabic column is actually Arabic', () {
    // "Not blank" passes an English string pasted into the Arabic column,
    // which is how an untranslated label ships. The two allowed exceptions are
    // legitimately Latin in both languages, and each says why in the table.
    const Set<String> latinByDesign = <String>{'identifierHint'};
    final RegExp arabic = RegExp(r'[؀-ۿ]');

    for (final MapEntry<String, Map<String, String>> entry
        in AppStrings.table.entries) {
      if (latinByDesign.contains(entry.key)) {
        continue;
      }
      expect(
        entry.value['ar'],
        matches(arabic),
        reason: '${entry.key} has no Arabic script in its Arabic entry',
      );
    }
  });

  test('resolves by locale', () {
    expect(const AppStrings(AppLocale.arabic).signIn, 'تسجيل الدخول');
    expect(const AppStrings(AppLocale.english).signIn, 'Sign in');
  });

  test('an unknown key falls back to the key rather than a blank', () {
    expect(const AppStrings(AppLocale.arabic)('no.such.key'), 'no.such.key');
  });

  test('does not repeat the copy the design system owns', () {
    // Two tables that both own "Retry" disagree within a release.
    for (final String key in <String>[
      'retry',
      'discard',
      'sending',
      'notSent',
      'waitingToSend',
    ]) {
      expect(AppStrings.table.containsKey(key), isFalse, reason: key);
    }
  });

  test('each language names itself in its own script', () {
    expect(AppLocale.arabic.nativeName, 'العربية');
    expect(AppLocale.english.nativeName, 'English');

    /*
      The flag is a product decision, not something the language tag implies:
      Arabic is spoken across the region and carries Saudi Arabia's because
      that is this product's market. Asserted so it cannot drift silently.
    */
    expect(AppLocale.arabic.flag, '🇸🇦');
    expect(AppLocale.english.flag, '🇬🇧');
    expect(AppLocale.arabic.flaggedName, '🇸🇦  العربية');
  });
}
