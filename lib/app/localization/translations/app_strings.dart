import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../locale_manager.dart';

/// The application's copy, in the reader's language.
///
/// A widget reads `ref.watch(appStringsProvider)`, so a change of language
/// redraws every screen that shows text without anybody threading a locale
/// through.
final Provider<AppStrings> appStringsProvider = Provider<AppStrings>(
  (Ref ref) => AppStrings(ref.watch(localeProvider)),
);

/// The application's user-facing copy.
///
/// A plain lookup rather than ARB and `flutter gen-l10n`, because the string
/// set is still small and the generated pipeline is a build step that buys
/// nothing until there is enough copy to justify it. The shape here is
/// deliberately the one `gen-l10n` produces -- a class of named getters
/// resolved from a locale -- so moving to it later is a mechanical change to
/// this file and nothing else.
///
/// **What does not live here.** The design system renders some copy on its own
/// behalf — "Retry", "Sending", "Not sent" — and owns it in `AppMessages`. Those
/// keys were in this table too, and were removed rather than kept in step: two
/// tables that both own "Retry" disagree within a release.
///
/// Copy never lives in the domain layer. Services emit stable keys
/// (`identifier.tooShort`); presentation resolves them here.
class AppStrings {
  const AppStrings(this.locale);

  final AppLocale locale;

  static const Map<String, Map<String, String>>
  _values = <String, Map<String, String>>{
    // -- sign-in ------------------------------------------------------------
    'signInTitle': <String, String>{
      'en': 'Welcome back',
      'ar': 'مرحباً بعودتك',
    },
    'signInSubtitle': <String, String>{
      'en': 'Sign in to your account to keep up with your business.',
      'ar': 'سجّل الدخول إلى حسابك لمتابعة أعمالك',
    },
    'signIn': <String, String>{'en': 'Sign in', 'ar': 'تسجيل الدخول'},
    'signOut': <String, String>{'en': 'Sign out', 'ar': 'تسجيل الخروج'},
    'identifierLabel': <String, String>{
      'en': 'Email or phone',
      'ar': 'البريد الإلكتروني أو الهاتف',
    },
    // An example address, identical in both languages on purpose: it shows
    // the *shape* of what to type, and that shape is Latin either way.
    'identifierHint': <String, String>{
      'en': 'name@yourstore.com',
      'ar': 'name@yourstore.com',
    },
    'passwordLabel': <String, String>{'en': 'Password', 'ar': 'كلمة المرور'},
    'rememberMe': <String, String>{'en': 'Keep me signed in', 'ar': 'تذكرني'},
    'language': <String, String>{'en': 'Language', 'ar': 'اللغة'},
    // Only what is verifiably true. Sign-in travels over HTTPS — the committed
    // environment files are tested to require it for every non-local host —
    // so "encrypted" is a fact. "Always safe", which the reference says, is a
    // promise nobody here can check.
    'securityNotice': <String, String>{
      'en': 'Your connection is encrypted.',
      'ar': 'اتصالك مشفّر.',
    },

    // -- sign-in failures ---------------------------------------------------
    'authNotRecognised': <String, String>{
      'en': 'Those details were not recognised. Check them and try again.',
      'ar': 'لم نتعرّف على هذه البيانات. تحقّق منها وحاول مرة أخرى.',
    },
    'authCheckDetails': <String, String>{
      'en': 'Check the details you entered.',
      'ar': 'تحقّق من البيانات التي أدخلتها.',
    },
    'authOffline': <String, String>{
      'en': 'No connection. Check your network and try again.',
      'ar': 'لا يوجد اتصال. تحقّق من الشبكة وحاول مرة أخرى.',
    },
    'authUnreachable': <String, String>{
      'en': 'The server could not be reached. Try again.',
      'ar': 'تعذّر الوصول إلى الخادم. حاول مرة أخرى.',
    },
    'authForbidden': <String, String>{
      'en': 'This account cannot sign in here.',
      'ar': 'لا يمكن لهذا الحساب تسجيل الدخول هنا.',
    },
    'authGeneric': <String, String>{
      'en': 'Something went wrong. Please try again.',
      'ar': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
    },
    'identifierRequired': <String, String>{
      'en': 'Enter your email or phone number.',
      'ar': 'أدخل بريدك الإلكتروني أو رقم هاتفك.',
    },
    'identifierTooShort': <String, String>{
      'en': 'That is too short to be an email or phone number.',
      'ar': 'هذا أقصر من أن يكون بريداً إلكترونياً أو رقم هاتف.',
    },
    'identifierTooLong': <String, String>{
      'en': 'That is too long.',
      'ar': 'هذا طويل جداً.',
    },
    'passwordRequired': <String, String>{
      'en': 'Enter your password.',
      'ar': 'أدخل كلمة المرور.',
    },
    'passwordTooLong': <String, String>{
      'en': 'That password is too long.',
      'ar': 'كلمة المرور هذه طويلة جداً.',
    },

    // -- conversations ------------------------------------------------------
    'inbox': <String, String>{'en': 'Inbox', 'ar': 'صندوق الوارد'},
    'searchConversations': <String, String>{
      'en': 'Search conversations',
      'ar': 'ابحث في المحادثات',
    },
    'writeMessage': <String, String>{
      'en': 'Write a message',
      'ar': 'اكتب رسالة',
    },
    'noConversations': <String, String>{
      'en': 'No conversations yet',
      'ar': 'لا توجد محادثات بعد',
    },
    'noConversationsDescription': <String, String>{
      'en': 'New conversations appear here as customers get in touch.',
      'ar': 'تظهر هنا المحادثات الجديدة عندما يتواصل معك العملاء.',
    },
    'noSearchMatches': <String, String>{
      'en': 'Nothing on this device matches that search.',
      'ar': 'لا شيء على هذا الجهاز يطابق هذا البحث.',
    },
    'conversationsUnreadable': <String, String>{
      'en': 'The conversation list could not be read.',
      'ar': 'تعذّرت قراءة قائمة المحادثات.',
    },
    'noMessages': <String, String>{
      'en': 'No messages yet',
      'ar': 'لا توجد رسائل بعد',
    },
    // A row's name when the customer has none and the thread has no subject.
    // The domain keeps an English fallback of its own, for logs; a row read in
    // Arabic must not show it.
    'unknownCustomer': <String, String>{
      'en': 'Unknown customer',
      'ar': 'عميل غير معروف',
    },
    'archivedReadOnly': <String, String>{
      'en': 'This conversation is archived and cannot receive new messages.',
      'ar': 'هذه المحادثة مؤرشفة ولا يمكنها استقبال رسائل جديدة.',
    },
  };

  /// The table itself, for the test that checks every entry is translated.
  @visibleForTesting
  static Map<String, Map<String, String>> get table => _values;

  /// The copy for [key], falling back to English and then to the key itself.
  ///
  /// A missing translation renders the English rather than an empty string or
  /// a crash: a screen with one untranslated label is usable, one with a blank
  /// button is not.
  String call(String key) {
    final entry = _values[key];

    if (entry == null) return key;

    return entry[locale.code] ?? entry['en'] ?? key;
  }

  String get signInTitle => call('signInTitle');
  String get signInSubtitle => call('signInSubtitle');
  String get signIn => call('signIn');
  String get signOut => call('signOut');
  String get identifierLabel => call('identifierLabel');
  String get identifierHint => call('identifierHint');
  String get passwordLabel => call('passwordLabel');
  String get rememberMe => call('rememberMe');
  String get language => call('language');
  String get securityNotice => call('securityNotice');

  String get authNotRecognised => call('authNotRecognised');
  String get authCheckDetails => call('authCheckDetails');
  String get authOffline => call('authOffline');
  String get authUnreachable => call('authUnreachable');
  String get authForbidden => call('authForbidden');
  String get authGeneric => call('authGeneric');

  String get inbox => call('inbox');
  String get searchConversations => call('searchConversations');
  String get noConversations => call('noConversations');
  String get noConversationsDescription => call('noConversationsDescription');
  String get noSearchMatches => call('noSearchMatches');
  String get conversationsUnreadable => call('conversationsUnreadable');
  String get noMessages => call('noMessages');
  String get unknownCustomer => call('unknownCustomer');
  String get writeMessage => call('writeMessage');
}
