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
    'threadUnreadable': <String, String>{
      'en': 'This conversation could not be read.',
      'ar': 'تعذّرت قراءة هذه المحادثة.',
    },
    'sendFirstMessage': <String, String>{
      'en': 'Send the first message in this conversation.',
      'ar': 'أرسل أول رسالة في هذه المحادثة.',
    },
    // A row's name when the customer has none and the thread has no subject.
    // The domain keeps an English fallback of its own, for logs; a row read in
    // Arabic must not show it.
    'unknownCustomer': <String, String>{
      'en': 'Unknown customer',
      'ar': 'عميل غير معروف',
    },
    // Why a send did not go through. The controller reports a reason; these
    // are the words for it.
    'sendRefused': <String, String>{
      'en': 'That message could not be sent.',
      'ar': 'تعذّر إرسال هذه الرسالة.',
    },
    'sendOffline': <String, String>{
      'en': 'You are offline. The message will send when you reconnect.',
      'ar': 'أنت غير متصل. ستُرسل الرسالة عند عودة الاتصال.',
    },
    'sendNotSaved': <String, String>{
      'en': 'The message could not be saved on this device.',
      'ar': 'تعذّر حفظ الرسالة على هذا الجهاز.',
    },
    'sendFailed': <String, String>{
      'en': 'Something went wrong. Please try again.',
      'ar': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
    },
    'archivedReadOnly': <String, String>{
      'en': 'This conversation is archived and cannot receive new messages.',
      'ar': 'هذه المحادثة مؤرشفة ولا يمكنها استقبال رسائل جديدة.',
    },

    // -- signing in with a provider -----------------------------------------
    'continueWith': <String, String>{
      'en': 'Or continue with',
      'ar': 'أو تابع باستخدام',
    },
    'continueWithGoogle': <String, String>{
      'en': 'Continue with Google',
      'ar': 'المتابعة باستخدام Google',
    },
    'continueWithFacebook': <String, String>{
      'en': 'Continue with Facebook',
      'ar': 'المتابعة باستخدام Facebook',
    },
    'socialEmailRequired': <String, String>{
      'en': 'That account gave us no confirmed email address, so we cannot match it to a workspace.',
      'ar': 'لم يعطنا هذا الحساب بريدًا إلكترونيًا مؤكدًا، فتعذّر ربطه بمساحة عمل.',
    },
    'socialAccountInactive': <String, String>{
      'en': 'That account is not active. Ask an owner to re-enable it.',
      'ar': 'هذا الحساب غير نشط. اطلب من المالك إعادة تفعيله.',
    },
    'socialWorkspaceSuspended': <String, String>{
      'en': 'That workspace is suspended.',
      'ar': 'مساحة العمل موقوفة.',
    },
    'socialFailed': <String, String>{
      'en': 'That sign-in could not be completed. Try again, or use your password.',
      'ar': 'تعذّر إكمال تسجيل الدخول. حاول مرة أخرى أو استخدم كلمة المرور.',
    },

    // -- customers ----------------------------------------------------------
    // -- WhatsApp's 24-hour window -----------------------------------------
    // The same sentences the web Inbox uses, on purpose: two phrasings for one
    // problem read as two problems.
    'sessionActive': <String, String>{
      'en': 'WhatsApp session active',
      'ar': 'جلسة واتساب مفتوحة',
    },
    'sessionExpiresIn': <String, String>{
      'en': 'Expires in {time}',
      'ar': 'تنتهي خلال {time}',
    },
    'sessionRemainingHours': <String, String>{
      'en': '{hours}h {minutes}m',
      'ar': '{hours} س {minutes} د',
    },
    'sessionRemainingMinutes': <String, String>{
      'en': '{minutes}m',
      'ar': '{minutes} د',
    },
    'sessionExpired': <String, String>{
      'en': 'WhatsApp session expired',
      'ar': 'انتهت جلسة واتساب',
    },
    'sessionExpiredHint': <String, String>{
      'en': 'The customer must send a new message before a free-form message can be sent.',
      'ar': 'يجب أن يرسل العميل رسالة جديدة قبل إرسال رسالة حرة.',
    },

    // -- Blog -------------------------------------------------------------
    'blog': <String, String>{'en': 'Blog', 'ar': 'المدونة'},
    'blogTagline': <String, String>{
      'en': 'Guides and advice for growing your store',
      'ar': 'مقالات وأدلة ونصائح لمساعدتك في نمو متجرك',
    },
    'searchArticles': <String, String>{
      'en': 'Search articles…',
      'ar': 'ابحث في المقالات…',
    },
    'blogEmpty': <String, String>{
      'en': 'No articles yet',
      'ar': 'لا توجد مقالات بعد',
    },
    'blogEmptyDescription': <String, String>{
      'en': 'New guides are published here regularly.',
      'ar': 'تُنشر هنا أدلة جديدة بانتظام.',
    },
    'blogNoMatches': <String, String>{
      'en': 'No article matches that',
      'ar': 'لا يوجد مقال يطابق ذلك',
    },
    'blogNoMatchesDescription': <String, String>{
      'en': 'Try a different word, or clear the filter.',
      'ar': 'جرّب كلمة أخرى، أو امسح عامل التصفية.',
    },
    'blogUnreadable': <String, String>{
      'en': 'The blog could not be loaded.',
      'ar': 'تعذّر تحميل المدونة.',
    },
    'articleUnreadable': <String, String>{
      'en': 'This article could not be loaded.',
      'ar': 'تعذّر تحميل هذا المقال.',
    },
    'articleMissing': <String, String>{
      'en': 'This article is no longer available.',
      'ar': 'لم يعد هذا المقال متاحًا.',
    },
    'allArticles': <String, String>{'en': 'All', 'ar': 'الكل'},
    'readingMinutes': <String, String>{
      'en': '{count} min read',
      'ar': '{count} دقائق قراءة',
    },
    'relatedArticles': <String, String>{
      'en': 'Related articles',
      'ar': 'مقالات ذات صلة',
    },
    'commonQuestions': <String, String>{
      'en': 'Common questions',
      'ar': 'أسئلة شائعة',
    },

    'customers': <String, String>{'en': 'Contacts', 'ar': 'جهات الاتصال'},
    'searchCustomers': <String, String>{
      'en': 'Search contacts…',
      'ar': 'ابحث في جهات الاتصال…',
    },
    'noCustomers': <String, String>{
      'en': 'No contacts yet',
      'ar': 'لا توجد جهات اتصال بعد',
    },
    'noCustomersDescription': <String, String>{
      'en': 'Contacts sync from the workspace. Pull down to fetch them.',
      'ar': 'تُزامَن جهات الاتصال من مساحة العمل. اسحب للأسفل لجلبها.',
    },
    'customersUnreadable': <String, String>{
      'en': 'Contacts could not be read',
      'ar': 'تعذّرت قراءة جهات الاتصال',
    },
    'allTags': <String, String>{'en': 'All', 'ar': 'الكل'},
    'searchOnline': <String, String>{
      'en': 'Search the workspace',
      'ar': 'ابحث في مساحة العمل',
    },
    'searchOnlineHint': <String, String>{
      'en': 'Not on this device? Search everyone.',
      'ar': 'غير موجود على هذا الجهاز؟ ابحث في الكل.',
    },
    'searchOnlineOffline': <String, String>{
      'en': 'Searching the workspace needs a connection.',
      'ar': 'البحث في مساحة العمل يحتاج اتصالًا بالإنترنت.',
    },
    'newCustomer': <String, String>{
      'en': 'New contact',
      'ar': 'جهة اتصال جديدة',
    },
    'customerName': <String, String>{'en': 'Name', 'ar': 'الاسم'},
    'customerTags': <String, String>{'en': 'Tags', 'ar': 'الوسوم'},
    'customerType': <String, String>{'en': 'Type', 'ar': 'النوع'},
    'customerSource': <String, String>{'en': 'Added via', 'ar': 'أُضيف عبر'},
    'customerStandingNote': <String, String>{'en': 'About', 'ar': 'نبذة'},
    'customerNotes': <String, String>{'en': 'Notes', 'ar': 'الملاحظات'},
    'customerNotesDescription': <String, String>{
      'en': 'What the team has written down, newest first.',
      'ar': 'ما دوّنه الفريق، من الأحدث إلى الأقدم.',
    },
    'addNote': <String, String>{'en': 'Add note', 'ar': 'إضافة ملاحظة'},
    'noteBody': <String, String>{'en': 'Note', 'ar': 'الملاحظة'},
    'noteHint': <String, String>{
      'en': 'What happened, in your own words',
      'ar': 'ما الذي حدث، بكلماتك',
    },
    'noNotes': <String, String>{
      'en': 'Nothing written down yet',
      'ar': 'لا توجد ملاحظات بعد',
    },
    'noNotesDescription': <String, String>{
      'en': 'Notes added here and on the web appear together.',
      'ar': 'الملاحظات المضافة من هنا ومن الويب تظهر معًا.',
    },
    'noteAuthorUnknown': <String, String>{
      'en': 'Author no longer on the team',
      'ar': 'الكاتب لم يعد ضمن الفريق',
    },
    'noteNeedsConnection': <String, String>{
      'en': 'Writing a note needs a connection. Your draft is kept.',
      'ar': 'كتابة ملاحظة تحتاج اتصالًا. مسوّدتك محفوظة.',
    },
    'noteSaveFailed': <String, String>{
      'en': 'The note was not saved',
      'ar': 'لم تُحفظ الملاحظة',
    },
    'customerNeedsConnection': <String, String>{
      'en': 'Adding a contact needs a connection.',
      'ar': 'إضافة جهة اتصال تحتاج اتصالًا بالإنترنت.',
    },
    'phoneNeedsCountryCode': <String, String>{
      'en': 'Start with the country code, like +966501234567.',
      'ar': 'ابدأ برمز الدولة، مثل ‎+966501234567.',
    },
    'customerSaveFailed': <String, String>{
      'en': 'The contact was not saved',
      'ar': 'لم تُحفظ جهة الاتصال',
    },
    'customerExists': <String, String>{
      'en': 'This number already belongs to a contact',
      'ar': 'هذا الرقم يخص جهة اتصال موجودة',
    },
    'customerGone': <String, String>{
      'en': 'This contact was removed from the workspace',
      'ar': 'أُزيلت جهة الاتصال من مساحة العمل',
    },
    'save': <String, String>{'en': 'Save', 'ar': 'حفظ'},

    // -- settings -----------------------------------------------------------
    'settings': <String, String>{'en': 'Settings', 'ar': 'الإعدادات'},
    'account': <String, String>{'en': 'Account', 'ar': 'الحساب'},
    'email': <String, String>{'en': 'Email', 'ar': 'البريد الإلكتروني'},
    'phone': <String, String>{'en': 'Phone', 'ar': 'الهاتف'},
    'workspace': <String, String>{'en': 'Store', 'ar': 'المتجر'},
    // The roles as the web dashboard names them, so a member reads the same
    // word for themselves on both.
    'roleOwner': <String, String>{'en': 'Owner', 'ar': 'المالك'},
    'roleAdmin': <String, String>{'en': 'Administrator', 'ar': 'مدير'},
    'roleAgent': <String, String>{'en': 'Agent', 'ar': 'موظف'},
    'roleViewer': <String, String>{'en': 'Viewer', 'ar': 'مشاهد'},
    'appearance': <String, String>{'en': 'Appearance', 'ar': 'المظهر'},
    // The web dashboard's words for the same choice.
    'themeSystem': <String, String>{'en': 'System', 'ar': 'النظام'},
    'themeLight': <String, String>{'en': 'Light', 'ar': 'فاتح'},
    'themeDark': <String, String>{'en': 'Dark', 'ar': 'داكن'},
    'about': <String, String>{'en': 'About', 'ar': 'حول التطبيق'},
    'appVersion': <String, String>{'en': 'Version', 'ar': 'الإصدار'},
    'signOutConfirmTitle': <String, String>{
      'en': 'Sign out?',
      'ar': 'تسجيل الخروج؟',
    },
    // Only what is true: signing out empties this device, outbox included, and
    // nothing on the account itself.
    'signOutConfirmMessage': <String, String>{
      'en':
          'Messages that have not been sent yet will be lost. Your '
          'conversations stay safe on your account.',
      'ar': 'ستفقد الرسائل التي لم تُرسل بعد. تبقى محادثاتك محفوظة في حسابك.',
    },

    // -- caller id ----------------------------------------------------------
    'callerIdTitle': <String, String>{'en': 'Caller ID', 'ar': 'معرف المتصل'},
    'callerIdSubtitle': <String, String>{
      'en': 'Show a card for incoming and outgoing calls',
      'ar': 'اعرض بطاقة للمكالمات الواردة والصادرة',
    },
    'callerIdRequirements': <String, String>{
      'en': 'Requirements',
      'ar': 'المتطلبات',
    },
    'callerIdEnabled': <String, String>{
      'en': 'Caller ID enabled',
      'ar': 'معرف المتصل مفعّل',
    },
    'callerIdCallScreening': <String, String>{
      'en': 'Call screening role',
      'ar': 'دور فحص المكالمات',
    },
    'callerIdOverlay': <String, String>{
      'en': 'Display over other apps',
      'ar': 'العرض فوق التطبيقات الأخرى',
    },
    'callerIdEnable': <String, String>{
      'en': 'Enable Caller ID',
      'ar': 'تفعيل معرف المتصل',
    },
    'callerIdEnableScreening': <String, String>{
      'en': 'Enable call screening',
      'ar': 'تفعيل فحص المكالمات',
    },
    'callerIdOpenOverlaySettings': <String, String>{
      'en': 'Open overlay settings',
      'ar': 'فتح إعدادات العرض فوق التطبيقات',
    },
    'callerIdGeneral': <String, String>{'en': 'General', 'ar': 'عام'},
    'callerIdShowIncoming': <String, String>{
      'en': 'Show for incoming calls',
      'ar': 'عرض للمكالمات الواردة',
    },
    'callerIdShowOutgoing': <String, String>{
      'en': 'Show for outgoing calls',
      'ar': 'عرض للمكالمات الصادرة',
    },
    'callerIdUnknownOnly': <String, String>{
      'en': 'Unknown numbers only',
      'ar': 'الأرقام غير المعروفة فقط',
    },
    'callerIdShowContacts': <String, String>{
      'en': 'Show for saved contacts',
      'ar': 'عرض لجهات الاتصال المحفوظة',
    },
    'callerIdAppearance': <String, String>{'en': 'Appearance', 'ar': 'المظهر'},
    'callerIdIncomingPreview': <String, String>{
      'en': 'Incoming call',
      'ar': 'مكالمة واردة',
    },
    'callerIdPreviewName': <String, String>{
      'en': 'Sara Al-Qahtani',
      'ar': 'سارة القحطاني',
    },
    'callerIdPreviewBusiness': <String, String>{
      'en': 'Returning customer',
      'ar': 'عميلة عائدة',
    },
    'callerIdPreviewTag': <String, String>{'en': 'VIP', 'ar': 'عميلة مميزة'},
    'callerIdShowAvatar': <String, String>{
      'en': 'Show avatar',
      'ar': 'عرض الصورة',
    },
    'callerIdAnimation': <String, String>{'en': 'Animation', 'ar': 'الحركة'},
    'callerIdBehavior': <String, String>{'en': 'Behavior', 'ar': 'السلوك'},
    'callerIdAutoDismiss': <String, String>{
      'en': 'Auto dismiss',
      'ar': 'إخفاء تلقائي',
    },
    'callerIdDismissOnTap': <String, String>{
      'en': 'Dismiss on tap',
      'ar': 'إخفاء عند النقر',
    },
    'callerIdData': <String, String>{'en': 'Data', 'ar': 'البيانات'},
    'callerIdLocalLookup': <String, String>{
      'en': 'Local lookup',
      'ar': 'بحث محلي',
    },
    'callerIdServerLookup': <String, String>{
      'en': 'Server lookup',
      'ar': 'بحث على الخادم',
    },
    'callerIdUseCache': <String, String>{
      'en': 'Use cached caller data',
      'ar': 'استخدام بيانات المتصل المخزّنة',
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
  String get threadUnreadable => call('threadUnreadable');
  String get sendFirstMessage => call('sendFirstMessage');
  String get unknownCustomer => call('unknownCustomer');
  String get writeMessage => call('writeMessage');
  String get archivedReadOnly => call('archivedReadOnly');
  String get sendRefused => call('sendRefused');
  String get sendOffline => call('sendOffline');
  String get sendNotSaved => call('sendNotSaved');
  String get sendFailed => call('sendFailed');

  String get continueWith => call('continueWith');

  /// The provider's own name, as the provider writes it. A provider this build
  /// does not know yet is shown as the server named it, not as nothing.
  String socialProviderName(String provider) => switch (provider) {
    'google' => call('continueWithGoogle'),
    'facebook' => call('continueWithFacebook'),
    _ => provider,
  };

  /// The API's own refusal codes, in the reader's language.
  String socialRefusal(String reason) => switch (reason) {
    'social_email_required' => call('socialEmailRequired'),
    'social_account_inactive' => call('socialAccountInactive'),
    'social_workspace_suspended' => call('socialWorkspaceSuspended'),
    _ => call('socialFailed'),
  };

  String get sessionActive => call('sessionActive');
  String get sessionExpired => call('sessionExpired');
  String get sessionExpiredHint => call('sessionExpiredHint');
  String sessionExpiresIn(String time) =>
      call('sessionExpiresIn').replaceAll('{time}', time);
  String sessionRemainingHours(int hours, int minutes) =>
      call('sessionRemainingHours')
          .replaceAll('{hours}', '$hours')
          .replaceAll('{minutes}', '$minutes');
  String sessionRemainingMinutes(int minutes) =>
      call('sessionRemainingMinutes').replaceAll('{minutes}', '$minutes');
  String get blog => call('blog');
  String get blogTagline => call('blogTagline');
  String get searchArticles => call('searchArticles');
  String get blogEmpty => call('blogEmpty');
  String get blogEmptyDescription => call('blogEmptyDescription');
  String get blogNoMatches => call('blogNoMatches');
  String get blogNoMatchesDescription => call('blogNoMatchesDescription');
  String get blogUnreadable => call('blogUnreadable');
  String get articleUnreadable => call('articleUnreadable');
  String get articleMissing => call('articleMissing');
  String get allArticles => call('allArticles');
  String get relatedArticles => call('relatedArticles');
  String get commonQuestions => call('commonQuestions');

  /// "5 min read". A count rather than a sentence, because the number is the
  /// information and every language puts it somewhere different.
  String readingTime(int minutes) =>
      call('readingMinutes').replaceAll('{count}', '$minutes');

  String get customers => call('customers');
  String get searchCustomers => call('searchCustomers');
  String get noCustomers => call('noCustomers');
  String get noCustomersDescription => call('noCustomersDescription');
  String get customersUnreadable => call('customersUnreadable');
  String get allTags => call('allTags');
  String get searchOnline => call('searchOnline');
  String get searchOnlineHint => call('searchOnlineHint');
  String get searchOnlineOffline => call('searchOnlineOffline');
  String get newCustomer => call('newCustomer');
  String get customerName => call('customerName');
  String get customerTags => call('customerTags');
  String get customerType => call('customerType');
  String get customerSource => call('customerSource');
  String get customerStandingNote => call('customerStandingNote');
  String get customerNotes => call('customerNotes');
  String get customerNotesDescription => call('customerNotesDescription');
  String get addNote => call('addNote');
  String get noteBody => call('noteBody');
  String get noteHint => call('noteHint');
  String get noNotes => call('noNotes');
  String get noNotesDescription => call('noNotesDescription');
  String get noteAuthorUnknown => call('noteAuthorUnknown');
  String get noteNeedsConnection => call('noteNeedsConnection');
  String get noteSaveFailed => call('noteSaveFailed');
  String get customerNeedsConnection => call('customerNeedsConnection');
  String get phoneNeedsCountryCode => call('phoneNeedsCountryCode');
  String get customerSaveFailed => call('customerSaveFailed');
  String get customerExists => call('customerExists');
  String get customerGone => call('customerGone');
  String get save => call('save');

  String get settings => call('settings');
  String get account => call('account');
  String get email => call('email');
  String get phone => call('phone');
  String get workspace => call('workspace');
  String get appearance => call('appearance');
  String get themeSystem => call('themeSystem');
  String get themeLight => call('themeLight');
  String get themeDark => call('themeDark');
  String get about => call('about');
  String get appVersion => call('appVersion');
  String get signOutConfirmTitle => call('signOutConfirmTitle');
  String get signOutConfirmMessage => call('signOutConfirmMessage');

  String get callerIdTitle => call('callerIdTitle');
  String get callerIdSubtitle => call('callerIdSubtitle');
  String get callerIdRequirements => call('callerIdRequirements');
  String get callerIdEnabled => call('callerIdEnabled');
  String get callerIdCallScreening => call('callerIdCallScreening');
  String get callerIdOverlay => call('callerIdOverlay');
  String get callerIdEnable => call('callerIdEnable');
  String get callerIdEnableScreening => call('callerIdEnableScreening');
  String get callerIdOpenOverlaySettings => call('callerIdOpenOverlaySettings');
  String get callerIdGeneral => call('callerIdGeneral');
  String get callerIdShowIncoming => call('callerIdShowIncoming');
  String get callerIdShowOutgoing => call('callerIdShowOutgoing');
  String get callerIdUnknownOnly => call('callerIdUnknownOnly');
  String get callerIdShowContacts => call('callerIdShowContacts');
  String get callerIdAppearance => call('callerIdAppearance');
  String get callerIdIncomingPreview => call('callerIdIncomingPreview');
  String get callerIdPreviewName => call('callerIdPreviewName');
  String get callerIdPreviewBusiness => call('callerIdPreviewBusiness');
  String get callerIdPreviewTag => call('callerIdPreviewTag');
  String get callerIdShowAvatar => call('callerIdShowAvatar');
  String get callerIdAnimation => call('callerIdAnimation');
  String get callerIdBehavior => call('callerIdBehavior');
  String get callerIdAutoDismiss => call('callerIdAutoDismiss');
  String get callerIdDismissOnTap => call('callerIdDismissOnTap');
  String get callerIdData => call('callerIdData');
  String get callerIdLocalLookup => call('callerIdLocalLookup');
  String get callerIdServerLookup => call('callerIdServerLookup');
  String get callerIdUseCache => call('callerIdUseCache');

  /// A member's role, named the way the web dashboard names it. A role this
  /// build does not know yet is shown as the server wrote it, not as nothing.
  String roleName(String role) => switch (role) {
    'owner' => call('roleOwner'),
    'admin' => call('roleAdmin'),
    'agent' => call('roleAgent'),
    'viewer' => call('roleViewer'),
    _ => role,
  };
}
