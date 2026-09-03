import '../locale_manager.dart';

/// The application's user-facing copy.
///
/// A plain lookup rather than ARB and `flutter gen-l10n`, because the string
/// set is still small and the generated pipeline is a build step that buys
/// nothing until there is enough copy to justify it. The shape here is
/// deliberately the one `gen-l10n` produces -- a class of named getters
/// resolved from a locale -- so moving to it later is a mechanical change to
/// this file and nothing else.
///
/// Copy never lives in the domain layer. Services emit stable keys
/// (`identifier.tooShort`); presentation resolves them here.
class AppStrings {
  const AppStrings(this.locale);

  final AppLocale locale;

  static const Map<String, Map<String, String>>
  _values = <String, Map<String, String>>{
    'signIn': <String, String>{'en': 'Sign in', 'ar': 'تسجيل الدخول'},
    'signOut': <String, String>{'en': 'Sign out', 'ar': 'تسجيل الخروج'},
    'signInSubtitle': <String, String>{
      'en': 'Use your Tajeer AI workspace account.',
      'ar': 'استخدم حساب مساحة العمل الخاصة بك.',
    },
    'identifierLabel': <String, String>{
      'en': 'Email or phone',
      'ar': 'البريد الإلكتروني أو الهاتف',
    },
    'passwordLabel': <String, String>{'en': 'Password', 'ar': 'كلمة المرور'},
    'rememberMe': <String, String>{
      'en': 'Keep me signed in',
      'ar': 'أبقني مسجلاً للدخول',
    },
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
    'noMessages': <String, String>{
      'en': 'No messages yet',
      'ar': 'لا توجد رسائل بعد',
    },
    'retry': <String, String>{'en': 'Retry', 'ar': 'إعادة المحاولة'},
    'discard': <String, String>{'en': 'Discard', 'ar': 'تجاهل'},
    'notSent': <String, String>{'en': 'Not sent', 'ar': 'لم تُرسل'},
    'sending': <String, String>{'en': 'Sending', 'ar': 'جارٍ الإرسال'},
    'waitingToSend': <String, String>{
      'en': 'Waiting to send',
      'ar': 'في انتظار الإرسال',
    },
    'archivedReadOnly': <String, String>{
      'en': 'This conversation is archived and cannot receive new messages.',
      'ar': 'هذه المحادثة مؤرشفة ولا يمكنها استقبال رسائل جديدة.',
    },
    'offlineShowingSaved': <String, String>{
      'en': 'Showing saved conversations. Reconnecting…',
      'ar': 'عرض المحادثات المحفوظة. جارٍ إعادة الاتصال…',
    },
  };

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

  String get signIn => call('signIn');
  String get signOut => call('signOut');
  String get inbox => call('inbox');
  String get writeMessage => call('writeMessage');
  String get retry => call('retry');
  String get discard => call('discard');
}
