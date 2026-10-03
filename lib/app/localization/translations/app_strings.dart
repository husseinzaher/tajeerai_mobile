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
    // -- blocking a contact -------------------------------------------------
    'customerBlock': <String, String>{
      'en': 'Block customer',
      'ar': 'حظر العميل',
    },
    'customerUnblock': <String, String>{'en': 'Unblock', 'ar': 'إلغاء الحظر'},
    // The dialog's confirm: the act in one word, beside the system's Cancel.
    'customerBlockConfirm': <String, String>{'en': 'Block', 'ar': 'حظر'},
    'customerBlockConfirmTitle': <String, String>{
      'en': 'Block this customer?',
      'ar': 'حظر هذا العميل؟',
    },
    'customerBlockConfirmBody': <String, String>{
      'en': 'Their messages won’t reach the inbox and nothing will be sent to them on any channel — campaigns included — until you unblock them.',
      'ar': 'لن تصل رسائله إلى صندوق الوارد ولن يُرسَل إليه شيء على أي قناة — والحملات ضمنها — حتى تلغي الحظر.',
    },
    'customerUnblockConfirmTitle': <String, String>{
      'en': 'Unblock this customer?',
      'ar': 'إلغاء حظر هذا العميل؟',
    },
    'customerUnblockConfirmBody': <String, String>{
      'en': 'Their messages will reach the inbox again and you can message them. What they sent while blocked was not kept.',
      'ar': 'ستصل رسائله إلى صندوق الوارد من جديد ويمكنك مراسلته. ما أرسله أثناء الحظر لم يُحفظ.',
    },
    'customerBlocked': <String, String>{'en': 'Blocked', 'ar': 'محظور'},
    'customerBlockedBanner': <String, String>{
      'en': 'Blocked — their messages are dropped and nothing is sent to them.',
      'ar': 'محظور — تُتجاهَل رسائله ولا يُرسَل إليه شيء.',
    },
    'customerBlockReason': <String, String>{
      'en': 'Block reason',
      'ar': 'سبب الحظر',
    },
    'customerBlockDone': <String, String>{
      'en': 'Customer blocked',
      'ar': 'تم حظر العميل',
    },
    'customerUnblockDone': <String, String>{
      'en': 'Customer unblocked',
      'ar': 'تم إلغاء حظر العميل',
    },
    'customerActionNeedsConnection': <String, String>{
      'en': 'This needs a connection. Nothing was changed.',
      'ar': 'هذا الإجراء يحتاج اتصالًا بالإنترنت. لم يتغيّر شيء.',
    },
    'customerActionNotAllowed': <String, String>{
      'en': 'You don’t have permission to do this.',
      'ar': 'ليست لديك صلاحية لهذا الإجراء.',
    },
    'customerActionFailed': <String, String>{
      'en': 'That didn’t go through. Try again.',
      'ar': 'لم يتم الإجراء. حاول مرة أخرى.',
    },
    'customerAliases': <String, String>{
      'en': 'Also known as',
      'ar': 'أسماء أخرى',
    },

    // -- changes the AI employee proposed -----------------------------------
    'customerProposals': <String, String>{
      'en': 'Proposed changes ({count})',
      'ar': 'تعديلات مقترحة ({count})',
    },
    'customerProposalsHint': <String, String>{
      'en': 'The AI employee read these in a conversation. The card keeps its current value until you approve.',
      'ar': 'قرأها الموظف الآلي في محادثة. تبقى القيمة الحالية في البطاقة حتى تعتمدها.',
    },
    'customerProposalApprove': <String, String>{
      'en': 'Approve',
      'ar': 'اعتماد',
    },
    'customerProposalReject': <String, String>{'en': 'Reject', 'ar': 'رفض'},
    'customerProposalApproved': <String, String>{
      'en': 'Change approved',
      'ar': 'تم اعتماد التعديل',
    },
    'customerProposalRejected': <String, String>{
      'en': 'Change rejected',
      'ar': 'تم رفض التعديل',
    },
    'customerProposalAlreadyDecided': <String, String>{
      'en': 'Someone already decided on this change.',
      'ar': 'سبق أن اتُّخذ قرار بشأن هذا التعديل.',
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
    // The colour identity, which is a different choice from light/dark: the
    // web dashboard offers the same three under the same names.
    'colourIdentity': <String, String>{'en': 'Colours', 'ar': 'الألوان'},
    'presetTajeer': <String, String>{'en': 'Tajeer', 'ar': 'تاجر'},
    'presetTeal': <String, String>{'en': 'Teal', 'ar': 'فيروزي'},
    'presetAurora': <String, String>{'en': 'Aurora', 'ar': 'أورورا'},
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

    // -- wallet -------------------------------------------------------------
    'walletTitle': <String, String>{
      'en': 'AI wallet',
      'ar': 'محفظة الذكاء الاصطناعي',
    },
    'walletSubtitle': <String, String>{
      'en': 'Balance, top-ups and history',
      'ar': 'الرصيد والشحن والسجل',
    },
    'walletAvailable': <String, String>{
      'en': 'Available balance',
      'ar': 'الرصيد المتاح',
    },
    'walletReserved': <String, String>{
      'en': '{amount} held for requests in progress',
      'ar': '{amount} محجوز لطلبات قيد التنفيذ',
    },
    'walletFrozen': <String, String>{
      'en': 'This wallet is frozen. Contact support to unfreeze it.',
      'ar': 'هذه المحفظة مجمّدة. تواصل مع الدعم لإلغاء التجميد.',
    },
    'walletLoadFailed': <String, String>{
      'en': 'Could not load the wallet. Check your connection and try again.',
      'ar': 'تعذّر تحميل المحفظة. تحقّق من الاتصال وحاول مرة أخرى.',
    },
    'walletTopUp': <String, String>{'en': 'Top up', 'ar': 'شحن الرصيد'},
    'walletOfferTitle': <String, String>{
      'en': '{amount} to your wallet',
      'ar': '{amount} إلى محفظتك',
    },
    'walletOfferBreakdown': <String, String>{
      'en': 'Payment fee {fee} · Total to pay {total}',
      'ar': 'رسوم الدفع {fee} · الإجمالي {total}',
    },
    'walletOfferStorePrice': <String, String>{
      'en': 'Google Play charges {price}',
      'ar': 'سعر Google Play: {price}',
    },
    'walletFeeOnTop': <String, String>{
      'en': 'The payment fee is added on top - your wallet receives the full amount.',
      'ar': 'رسوم الدفع تُضاف فوق المبلغ - محفظتك تستلم المبلغ كاملًا.',
    },
    'walletBuy': <String, String>{'en': 'Buy', 'ar': 'شراء'},
    'walletTopUpCredited': <String, String>{
      'en': '{amount} added to your wallet.',
      'ar': 'تمت إضافة {amount} إلى محفظتك.',
    },
    'walletTopUpPending': <String, String>{
      'en': 'Payment pending. Your wallet is credited as soon as Google Play confirms it.',
      'ar': 'الدفع قيد المعالجة. ستُشحن محفظتك فور تأكيد Google Play.',
    },
    'walletTopUpFailed': <String, String>{
      'en': 'The top-up did not go through. You were not charged twice - try again in a moment.',
      'ar': 'لم يكتمل الشحن. لن تُحاسب مرتين - حاول مرة أخرى بعد قليل.',
    },
    'walletPurchases': <String, String>{'en': 'Purchases', 'ar': 'المشتريات'},
    'walletNoPurchases': <String, String>{
      'en': 'No top-ups yet',
      'ar': 'لا توجد عمليات شحن بعد',
    },
    'walletPaymentFee': <String, String>{
      'en': 'fee {amount}',
      'ar': 'رسوم {amount}',
    },
    'walletStatement': <String, String>{'en': 'Statement', 'ar': 'كشف الحساب'},
    'walletNoEntries': <String, String>{
      'en': 'No activity yet',
      'ar': 'لا توجد حركات بعد',
    },
    'walletBalanceAfter': <String, String>{
      'en': 'Balance after: {amount}',
      'ar': 'الرصيد بعدها: {amount}',
    },
    'walletStatePaid': <String, String>{'en': 'Paid', 'ar': 'مدفوع'},
    'walletStatePending': <String, String>{
      'en': 'Pending',
      'ar': 'قيد الانتظار',
    },
    'walletStateFailed': <String, String>{'en': 'Failed', 'ar': 'فشل'},
    'walletStateCancelled': <String, String>{'en': 'Cancelled', 'ar': 'ملغى'},
    'walletEntryTopUp': <String, String>{'en': 'Top-up', 'ar': 'شحن'},
    'walletEntryAiUsage': <String, String>{
      'en': 'AI usage',
      'ar': 'استخدام الذكاء الاصطناعي',
    },
    'walletEntryRefund': <String, String>{'en': 'Refund', 'ar': 'استرداد'},
    'walletEntryOther': <String, String>{
      'en': 'Wallet activity',
      'ar': 'حركة على المحفظة',
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
    'callerIdStatusReady': <String, String>{'en': 'Ready', 'ar': 'جاهز'},
    'callerIdStatusSetup': <String, String>{
      'en': 'Needs setup',
      'ar': 'يحتاج إعداد',
    },
    'callerIdStatusOff': <String, String>{'en': 'Off', 'ar': 'متوقف'},
    'callerIdReadyDescription': <String, String>{
      'en': 'The card will appear on your next call.',
      'ar': 'ستظهر البطاقة في مكالمتك القادمة.',
    },
    'callerIdSetupDescription': <String, String>{
      'en': 'Finish the steps below so the card can appear.',
      'ar': 'أكمل الخطوات بالأسفل حتى تظهر البطاقة.',
    },
    'callerIdOffDescription': <String, String>{
      'en': 'Turn it on to recognise callers from your customer list.',
      'ar': 'فعّله ليتعرّف على المتصلين من قائمة عملائك.',
    },
    'callerIdPreview': <String, String>{
      'en': 'Live preview',
      'ar': 'معاينة مباشرة',
    },
    'callerIdPreviewNote': <String, String>{
      'en': 'Wants a callback on Sunday',
      'ar': 'تريد اتصالًا يوم الأحد',
    },
    'callerIdSetupSteps': <String, String>{
      'en': 'Setup steps',
      'ar': 'خطوات الإعداد',
    },
    'callerIdScreeningDescription': <String, String>{
      'en': 'Lets Android hand incoming calls to the app to identify them.',
      'ar': 'يسمح لأندرويد بتمرير المكالمات إلى التطبيق للتعرّف على المتصل.',
    },
    'callerIdOverlayDescription': <String, String>{
      'en': 'Needed to draw the card above the call screen.',
      'ar': 'مطلوب لرسم البطاقة فوق شاشة المكالمة.',
    },
    'callerIdGrant': <String, String>{'en': 'Allow', 'ar': 'السماح'},
    'callerIdGranted': <String, String>{'en': 'Granted', 'ar': 'ممنوحة'},
    'callerIdCalls': <String, String>{'en': 'Calls', 'ar': 'المكالمات'},
    'callerIdShowIncomingDescription': <String, String>{
      'en': 'Identify who is calling you.',
      'ar': 'التعرّف على من يتصل بك.',
    },
    'callerIdShowOutgoingDescription': <String, String>{
      'en': 'Show the card when you call a customer.',
      'ar': 'عرض البطاقة عندما تتصل بعميل.',
    },
    'callerIdUnknownOnlyDescription': <String, String>{
      'en': 'Hide the card for customers the phone already recognises.',
      'ar': 'إخفاء البطاقة للعملاء الذين يتعرّف عليهم الهاتف بالفعل.',
    },
    'callerIdShowContactsDescription': <String, String>{
      'en': 'Also show it for customers you already know.',
      'ar': 'عرضها أيضًا للعملاء الذين تعرفهم.',
    },
    'callerIdCardPosition': <String, String>{
      'en': 'Card position',
      'ar': 'موضع البطاقة',
    },
    'callerIdPositionTop': <String, String>{'en': 'Top', 'ar': 'أعلى'},
    'callerIdPositionCenter': <String, String>{'en': 'Centre', 'ar': 'الوسط'},
    'callerIdPositionBottom': <String, String>{'en': 'Bottom', 'ar': 'أسفل'},
    'callerIdCardSize': <String, String>{
      'en': 'Card size',
      'ar': 'حجم البطاقة',
    },
    'callerIdSizeCompact': <String, String>{'en': 'Compact', 'ar': 'مضغوطة'},
    'callerIdSizeFull': <String, String>{'en': 'Detailed', 'ar': 'مفصّلة'},
    'callerIdShowPhoneNumber': <String, String>{
      'en': 'Show phone number',
      'ar': 'عرض رقم الهاتف',
    },
    'callerIdShowBusinessInfo': <String, String>{
      'en': 'Show customer type',
      'ar': 'عرض نوع العميل',
    },
    'callerIdShowTags': <String, String>{'en': 'Show tags', 'ar': 'عرض الوسوم'},
    'callerIdAutoDismissDescription': <String, String>{
      'en': 'How long the card stays on screen.',
      'ar': 'مدة بقاء البطاقة على الشاشة.',
    },
    'callerIdDismissOnTapDescription': <String, String>{
      'en': 'Tap the card to hide it.',
      'ar': 'انقر البطاقة لإخفائها.',
    },
    'callerIdLocalLookupDescription': <String, String>{
      'en': 'Match the number against customers saved on this phone. Fastest.',
      'ar': 'مطابقة الرقم مع العملاء المحفوظين على هذا الهاتف، وهو الأسرع.',
    },
    'callerIdServerLookupDescription': <String, String>{
      'en': 'Ask the workspace when this phone does not know the number.',
      'ar': 'سؤال مساحة العمل عندما لا يعرف الهاتف الرقم.',
    },
    'callerIdUseCacheDescription': <String, String>{
      'en': 'Remember results for a week so repeat callers appear instantly.',
      'ar': 'حفظ النتائج لأسبوع لتظهر الأرقام المتكررة فورًا.',
    },
    'callerIdSecondsUnit': <String, String>{'en': 's', 'ar': 'ث'},
    'callerIdContacts': <String, String>{
      'en': 'Contacts access',
      'ar': 'الوصول لجهات الاتصال',
    },
    'callerIdContactsDescription': <String, String>{
      'en': 'Lets the card appear for callers saved in your phone, not only for unknown numbers.',
      'ar': 'يسمح بظهور البطاقة للمتصلين المحفوظين في هاتفك، لا للأرقام غير المعروفة فقط.',
    },
    'callerIdPhoneState': <String, String>{
      'en': 'Call status',
      'ar': 'حالة المكالمة',
    },
    'callerIdPhoneStateDescription': <String, String>{
      'en': 'Keeps the card up for the whole call and shows a summary when it ends.',
      'ar': 'يُبقي البطاقة طوال المكالمة ويعرض ملخصًا عند انتهائها.',
    },
    'callerIdNeverDismiss': <String, String>{'en': 'Never', 'ar': 'لا يختفي'},
    'callerIdLogCalls': <String, String>{
      'en': 'Log calls to the customer record',
      'ar': 'تسجيل المكالمات في سجل العميل',
    },
    'callerIdLogCallsDescription': <String, String>{
      'en': 'After each call, a note is added to the customer on the server: incoming or outgoing, answered and for how long, or missed.',
      'ar': 'بعد كل مكالمة تُضاف ملاحظة لسجل العميل على السيرفر: واردة أو صادرة، تم الرد ومدتها، أو فائتة.',
    },
    'callerIdPreviewDuring': <String, String>{
      'en': 'During the call',
      'ar': 'أثناء المكالمة',
    },
    'callerIdPreviewAfter': <String, String>{
      'en': 'After the call',
      'ar': 'بعد المكالمة',
    },
    'callerIdBrand': <String, String>{'en': 'TajeerAi', 'ar': 'تاجر'},
    'callerIdLastNote': <String, String>{'en': 'Last note', 'ar': 'آخر ملاحظة'},
    'callerIdLastOrder': <String, String>{'en': 'Last order', 'ar': 'آخر طلب'},
    'callerIdAddress': <String, String>{'en': 'Address', 'ar': 'العنوان'},
    'callerIdPreviewOrder': <String, String>{
      'en': '#1042 · Delivered · 450.00 SAR',
      'ar': '#1042 · تم التوصيل · 450.00 SAR',
    },
    'callerIdPreviewAddress': <String, String>{
      'en': 'King Fahd Rd, Al Olaya, Riyadh',
      'ar': 'طريق الملك فهد، العليا، الرياض',
    },
    'callerIdMissedCall': <String, String>{
      'en': 'Missed call',
      'ar': 'مكالمة فائتة',
    },
    'callerIdCallBack': <String, String>{
      'en': 'Call back',
      'ar': 'اتصل مرة أخرى',
    },
    'callerIdMessage': <String, String>{'en': 'Message', 'ar': 'رسالة'},
    'callerIdOpenCustomer': <String, String>{
      'en': 'Open customer',
      'ar': 'فتح العميل',
    },
    // -- the conversation's customer panel ---------------------------------
    'customerPanelTitle': <String, String>{
      'en': 'Customer details',
      'ar': 'تفاصيل العميل',
    },
    'customerPanelRegistered': <String, String>{
      'en': 'Registered customer',
      'ar': 'عميل مسجّل',
    },
    'customerPanelUnregistered': <String, String>{
      'en': 'Not a customer yet',
      'ar': 'غير مسجّل بعد',
    },
    'customerPanelFirstContact': <String, String>{
      'en': 'First contact {date}',
      'ar': 'أول تواصل {date}',
    },
    'customerPanelCall': <String, String>{'en': 'Call', 'ar': 'اتصال'},
    'customerPanelReminder': <String, String>{'en': 'Reminder', 'ar': 'تذكير'},
    'customerPanelOpen': <String, String>{'en': 'Open', 'ar': 'فتح'},
    'customerPanelTabData': <String, String>{'en': 'Details', 'ar': 'البيانات'},
    'customerPanelTabOrders': <String, String>{'en': 'Orders', 'ar': 'الطلبات'},
    'customerPanelTabFollowUps': <String, String>{
      'en': 'Follow-ups',
      'ar': 'المتابعات',
    },
    'customerPanelFields': <String, String>{
      'en': 'Contact fields',
      'ar': 'حقول البيانات',
    },
    'customerPanelName': <String, String>{'en': 'Name', 'ar': 'الاسم'},
    'customerPanelNotSet': <String, String>{'en': 'Not set', 'ar': 'غير محدد'},
    'customerPanelWhatsAppUsername': <String, String>{
      'en': 'WhatsApp username',
      'ar': 'اسم مستخدم واتساب',
    },
    'customerPanelWhatsAppUserId': <String, String>{
      'en': 'WhatsApp user id',
      'ar': 'معرّف مستخدم واتساب',
    },
    'customerPanelLanguage': <String, String>{'en': 'Language', 'ar': 'اللغة'},
    'customerPanelTags': <String, String>{'en': 'Tags', 'ar': 'العلامات'},
    'customerPanelNoTags': <String, String>{
      'en': 'No tags yet',
      'ar': 'لا توجد علامات بعد',
    },
    'customerPanelConversation': <String, String>{
      'en': 'Conversation',
      'ar': 'المحادثة',
    },
    'customerPanelStatus': <String, String>{'en': 'Status', 'ar': 'الحالة'},
    'customerPanelAssignee': <String, String>{
      'en': 'Assigned to',
      'ar': 'مُسندة إلى',
    },
    'customerPanelAssigned': <String, String>{
      'en': 'A team member',
      'ar': 'أحد أعضاء الفريق',
    },
    'customerPanelUnassigned': <String, String>{
      'en': 'Unassigned',
      'ar': 'غير مُسندة',
    },
    'customerPanelStarted': <String, String>{'en': 'Started', 'ar': 'بدأت'},
    'conversationStateOpen': <String, String>{'en': 'Open', 'ar': 'مفتوحة'},
    'conversationStatePending': <String, String>{
      'en': 'Pending',
      'ar': 'معلّقة',
    },
    'conversationStateClosed': <String, String>{'en': 'Closed', 'ar': 'مغلقة'},
    'conversationStateArchived': <String, String>{
      'en': 'Archived',
      'ar': 'مؤرشفة',
    },
    // -- the thread's record: log lines, notes, the summary -----------------
    'logClosed': <String, String>{
      'en': 'Conversation closed by {name}',
      'ar': 'تم إغلاق المحادثة بواسطة {name}',
    },
    'logClosedWithReason': <String, String>{
      'en': 'Conversation closed by {name} — {reason}',
      'ar': 'تم إغلاق المحادثة بواسطة {name} — {reason}',
    },
    'logReopened': <String, String>{
      'en': 'Conversation reopened by {name}',
      'ar': 'تمت إعادة فتح المحادثة بواسطة {name}',
    },
    'logSummarized': <String, String>{
      'en': 'This conversation was summarised by {name}',
      'ar': 'تم تلخيص هذه المحادثة بواسطة {name}',
    },
    'logSystem': <String, String>{'en': 'System', 'ar': 'النظام'},
    'closeReasonResolved': <String, String>{'en': 'Resolved', 'ar': 'تم الحل'},
    'closeReasonNoResponse': <String, String>{
      'en': 'No response',
      'ar': 'لا يوجد رد',
    },
    'closeReasonSpam': <String, String>{'en': 'Spam', 'ar': 'رسائل مزعجة'},
    'closeReasonDuplicate': <String, String>{'en': 'Duplicate', 'ar': 'مكررة'},
    'closeReasonOther': <String, String>{'en': 'Other', 'ar': 'أخرى'},
    'noteSaved': <String, String>{
      'en': 'Note added',
      'ar': 'تمت إضافة الملاحظة',
    },
    'summaryDone': <String, String>{
      'en': 'The summary was added to the conversation',
      'ar': 'تمت إضافة الملخص إلى المحادثة',
    },
    'summaryFailed': <String, String>{
      'en': 'This conversation could not be summarised.',
      'ar': 'تعذّر تلخيص هذه المحادثة.',
    },
    'summaryEmptyThread': <String, String>{
      'en': 'There is nothing to summarise yet.',
      'ar': 'لا يوجد ما يُلخَّص بعد.',
    },
    'customerPanelLastActivity': <String, String>{
      'en': 'Last activity',
      'ar': 'آخر نشاط',
    },
    'customerPanelNoOrders': <String, String>{
      'en': 'No orders yet',
      'ar': 'لا توجد طلبات بعد',
    },
    'customerPanelNoOrdersDescription': <String, String>{
      'en': 'Orders this customer places will appear here.',
      'ar': 'ستظهر هنا الطلبات التي يقدّمها هذا العميل.',
    },
    'customerPanelNoFollowUps': <String, String>{
      'en': 'Nothing to follow up',
      'ar': 'لا توجد متابعات',
    },
    'customerPanelNoFollowUpsDescription': <String, String>{
      'en': 'Reminders set on this customer’s notes will appear here.',
      'ar': 'ستظهر هنا التذكيرات المضبوطة على ملاحظات هذا العميل.',
    },
    'customerPanelOverdue': <String, String>{'en': 'Overdue', 'ar': 'متأخرة'},
    'customerPanelNoCustomer': <String, String>{
      'en': 'This conversation has no customer attached yet.',
      'ar': 'لا يوجد عميل مرتبط بهذه المحادثة بعد.',
    },
    'orderStateDraft': <String, String>{'en': 'Draft', 'ar': 'مسودة'},
    'orderStatePending': <String, String>{
      'en': 'Pending',
      'ar': 'قيد الانتظار',
    },
    'orderStatePaid': <String, String>{'en': 'Paid', 'ar': 'مدفوع'},
    'orderStateProcessing': <String, String>{
      'en': 'Processing',
      'ar': 'قيد التجهيز',
    },
    'orderStateShipped': <String, String>{'en': 'Shipped', 'ar': 'تم الشحن'},
    'orderStateDelivered': <String, String>{
      'en': 'Delivered',
      'ar': 'تم التوصيل',
    },
    'orderStateCancelled': <String, String>{'en': 'Cancelled', 'ar': 'ملغي'},
    'orderStateRefunded': <String, String>{'en': 'Refunded', 'ar': 'مسترد'},
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
  String get customerBlock => call('customerBlock');
  String get customerUnblock => call('customerUnblock');
  String get customerBlockConfirm => call('customerBlockConfirm');
  String get customerBlockConfirmTitle => call('customerBlockConfirmTitle');
  String get customerBlockConfirmBody => call('customerBlockConfirmBody');
  String get customerUnblockConfirmTitle => call('customerUnblockConfirmTitle');
  String get customerUnblockConfirmBody => call('customerUnblockConfirmBody');
  String get customerBlocked => call('customerBlocked');
  String get customerBlockedBanner => call('customerBlockedBanner');
  String get customerBlockReason => call('customerBlockReason');
  String get customerBlockDone => call('customerBlockDone');
  String get customerUnblockDone => call('customerUnblockDone');
  String get customerActionNeedsConnection =>
      call('customerActionNeedsConnection');
  String get customerActionNotAllowed => call('customerActionNotAllowed');
  String get customerActionFailed => call('customerActionFailed');
  String get customerAliases => call('customerAliases');
  String get customerProposals => call('customerProposals');
  String get customerProposalsHint => call('customerProposalsHint');
  String get customerProposalApprove => call('customerProposalApprove');
  String get customerProposalReject => call('customerProposalReject');
  String get customerProposalApproved => call('customerProposalApproved');
  String get customerProposalRejected => call('customerProposalRejected');
  String get customerProposalAlreadyDecided =>
      call('customerProposalAlreadyDecided');
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
  String get colourIdentity => call('colourIdentity');
  String get presetTajeer => call('presetTajeer');
  String get presetTeal => call('presetTeal');
  String get presetAurora => call('presetAurora');
  String get about => call('about');
  String get appVersion => call('appVersion');
  String get signOutConfirmTitle => call('signOutConfirmTitle');
  String get signOutConfirmMessage => call('signOutConfirmMessage');

  String get walletTitle => call('walletTitle');
  String get walletSubtitle => call('walletSubtitle');
  String get walletAvailable => call('walletAvailable');
  String walletReserved(String amount) =>
      call('walletReserved').replaceAll('{amount}', amount);
  String get walletFrozen => call('walletFrozen');
  String get walletLoadFailed => call('walletLoadFailed');
  String get walletTopUp => call('walletTopUp');
  String walletOfferTitle(String amount) =>
      call('walletOfferTitle').replaceAll('{amount}', amount);
  String walletOfferBreakdown(String fee, String total) =>
      call('walletOfferBreakdown')
          .replaceAll('{fee}', fee)
          .replaceAll('{total}', total);
  String walletOfferStorePrice(String price) =>
      call('walletOfferStorePrice').replaceAll('{price}', price);
  String get walletFeeOnTop => call('walletFeeOnTop');
  String get walletBuy => call('walletBuy');
  String walletTopUpCredited(String amount) =>
      call('walletTopUpCredited').replaceAll('{amount}', amount);
  String get walletTopUpPending => call('walletTopUpPending');
  String get walletTopUpFailed => call('walletTopUpFailed');
  String get walletPurchases => call('walletPurchases');
  String get walletNoPurchases => call('walletNoPurchases');
  String walletPaymentFee(String amount) =>
      call('walletPaymentFee').replaceAll('{amount}', amount);
  String get walletStatement => call('walletStatement');
  String get walletNoEntries => call('walletNoEntries');
  String walletBalanceAfter(String amount) =>
      call('walletBalanceAfter').replaceAll('{amount}', amount);

  /// The server's payment state, in the reader's words. An unknown state
  /// reads as pending rather than as a raw key.
  String walletPaymentState(String state) => switch (state) {
    'paid' => call('walletStatePaid'),
    'failed' => call('walletStateFailed'),
    'cancelled' => call('walletStateCancelled'),
    _ => call('walletStatePending'),
  };

  /// A statement line with no description of its own.
  String walletEntryType(String type) => switch (type) {
    'topup_credit' || 'payment_credit' => call('walletEntryTopUp'),
    'ai_usage' => call('walletEntryAiUsage'),
    'refund' || 'payment_reversal' => call('walletEntryRefund'),
    _ => call('walletEntryOther'),
  };

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
  String get callerIdStatusReady => call('callerIdStatusReady');
  String get callerIdStatusSetup => call('callerIdStatusSetup');
  String get callerIdStatusOff => call('callerIdStatusOff');
  String get callerIdReadyDescription => call('callerIdReadyDescription');
  String get callerIdSetupDescription => call('callerIdSetupDescription');
  String get callerIdOffDescription => call('callerIdOffDescription');
  String get callerIdPreview => call('callerIdPreview');
  String get callerIdPreviewNote => call('callerIdPreviewNote');
  String get callerIdSetupSteps => call('callerIdSetupSteps');
  String get callerIdScreeningDescription =>
      call('callerIdScreeningDescription');
  String get callerIdOverlayDescription => call('callerIdOverlayDescription');
  String get callerIdGrant => call('callerIdGrant');
  String get callerIdGranted => call('callerIdGranted');
  String get callerIdCalls => call('callerIdCalls');
  String get callerIdShowIncomingDescription =>
      call('callerIdShowIncomingDescription');
  String get callerIdShowOutgoingDescription =>
      call('callerIdShowOutgoingDescription');
  String get callerIdUnknownOnlyDescription =>
      call('callerIdUnknownOnlyDescription');
  String get callerIdShowContactsDescription =>
      call('callerIdShowContactsDescription');
  String get callerIdCardPosition => call('callerIdCardPosition');
  String get callerIdPositionTop => call('callerIdPositionTop');
  String get callerIdPositionCenter => call('callerIdPositionCenter');
  String get callerIdPositionBottom => call('callerIdPositionBottom');
  String get callerIdCardSize => call('callerIdCardSize');
  String get callerIdSizeCompact => call('callerIdSizeCompact');
  String get callerIdSizeFull => call('callerIdSizeFull');
  String get callerIdShowPhoneNumber => call('callerIdShowPhoneNumber');
  String get callerIdShowBusinessInfo => call('callerIdShowBusinessInfo');
  String get callerIdShowTags => call('callerIdShowTags');
  String get callerIdAutoDismissDescription =>
      call('callerIdAutoDismissDescription');
  String get callerIdDismissOnTapDescription =>
      call('callerIdDismissOnTapDescription');
  String get callerIdLocalLookupDescription =>
      call('callerIdLocalLookupDescription');
  String get callerIdServerLookupDescription =>
      call('callerIdServerLookupDescription');
  String get callerIdUseCacheDescription => call('callerIdUseCacheDescription');
  String get callerIdSecondsUnit => call('callerIdSecondsUnit');
  String get callerIdContacts => call('callerIdContacts');
  String get callerIdContactsDescription => call('callerIdContactsDescription');
  String get callerIdPhoneState => call('callerIdPhoneState');
  String get callerIdPhoneStateDescription =>
      call('callerIdPhoneStateDescription');
  String get callerIdNeverDismiss => call('callerIdNeverDismiss');
  String get callerIdLogCalls => call('callerIdLogCalls');
  String get callerIdLogCallsDescription => call('callerIdLogCallsDescription');
  String get callerIdPreviewDuring => call('callerIdPreviewDuring');
  String get callerIdPreviewAfter => call('callerIdPreviewAfter');
  String get callerIdBrand => call('callerIdBrand');
  String get callerIdLastNote => call('callerIdLastNote');
  String get callerIdLastOrder => call('callerIdLastOrder');
  String get callerIdAddress => call('callerIdAddress');
  String get callerIdPreviewOrder => call('callerIdPreviewOrder');
  String get callerIdPreviewAddress => call('callerIdPreviewAddress');
  String get callerIdMissedCall => call('callerIdMissedCall');
  String get callerIdCallBack => call('callerIdCallBack');
  String get callerIdMessage => call('callerIdMessage');
  String get callerIdOpenCustomer => call('callerIdOpenCustomer');
  String get customerPanelTitle => call('customerPanelTitle');
  String get customerPanelRegistered => call('customerPanelRegistered');
  String get customerPanelUnregistered => call('customerPanelUnregistered');
  String get customerPanelFirstContact => call('customerPanelFirstContact');
  String get customerPanelCall => call('customerPanelCall');
  String get customerPanelReminder => call('customerPanelReminder');
  String get customerPanelOpen => call('customerPanelOpen');
  String get customerPanelTabData => call('customerPanelTabData');
  String get customerPanelTabOrders => call('customerPanelTabOrders');
  String get customerPanelTabFollowUps => call('customerPanelTabFollowUps');
  String get customerPanelFields => call('customerPanelFields');
  String get customerPanelName => call('customerPanelName');
  String get customerPanelNotSet => call('customerPanelNotSet');
  String get customerPanelWhatsAppUsername =>
      call('customerPanelWhatsAppUsername');
  String get customerPanelWhatsAppUserId => call('customerPanelWhatsAppUserId');
  String get customerPanelLanguage => call('customerPanelLanguage');
  String get customerPanelTags => call('customerPanelTags');
  String get customerPanelNoTags => call('customerPanelNoTags');
  String get customerPanelConversation => call('customerPanelConversation');
  String get customerPanelStatus => call('customerPanelStatus');
  String get customerPanelAssignee => call('customerPanelAssignee');
  String get customerPanelAssigned => call('customerPanelAssigned');
  String get customerPanelUnassigned => call('customerPanelUnassigned');
  String get customerPanelStarted => call('customerPanelStarted');
  String get customerPanelLastActivity => call('customerPanelLastActivity');
  String get customerPanelNoOrders => call('customerPanelNoOrders');
  String get customerPanelNoOrdersDescription =>
      call('customerPanelNoOrdersDescription');
  String get customerPanelNoFollowUps => call('customerPanelNoFollowUps');
  String get customerPanelNoFollowUpsDescription =>
      call('customerPanelNoFollowUpsDescription');
  String get customerPanelOverdue => call('customerPanelOverdue');
  String get customerPanelNoCustomer => call('customerPanelNoCustomer');
  String get conversationStateOpen => call('conversationStateOpen');
  String get conversationStatePending => call('conversationStatePending');
  String get conversationStateClosed => call('conversationStateClosed');
  String get conversationStateArchived => call('conversationStateArchived');
  String get logClosed => call('logClosed');
  String get logClosedWithReason => call('logClosedWithReason');
  String get logReopened => call('logReopened');
  String get logSummarized => call('logSummarized');
  String get logSystem => call('logSystem');
  String get closeReasonResolved => call('closeReasonResolved');
  String get closeReasonNoResponse => call('closeReasonNoResponse');
  String get closeReasonSpam => call('closeReasonSpam');
  String get closeReasonDuplicate => call('closeReasonDuplicate');
  String get closeReasonOther => call('closeReasonOther');
  String get noteSaved => call('noteSaved');
  String get summaryDone => call('summaryDone');
  String get summaryFailed => call('summaryFailed');
  String get summaryEmptyThread => call('summaryEmptyThread');

  /// A closing reason as the server spells it, in the reader's language.
  String closeReasonName(String reason) => switch (reason) {
    'resolved' => call('closeReasonResolved'),
    'no_response' => call('closeReasonNoResponse'),
    'spam' => call('closeReasonSpam'),
    'duplicate' => call('closeReasonDuplicate'),
    'other' => call('closeReasonOther'),
    _ => reason,
  };

  /// An order state as the server spells it, in the reader's language. A
  /// state this build does not know is shown as the server named it.
  String orderStateName(String state) => switch (state) {
    'draft' => call('orderStateDraft'),
    'pending' => call('orderStatePending'),
    'paid' => call('orderStatePaid'),
    'processing' => call('orderStateProcessing'),
    'shipped' => call('orderStateShipped'),
    'delivered' => call('orderStateDelivered'),
    'cancelled' => call('orderStateCancelled'),
    'refunded' => call('orderStateRefunded'),
    _ => state,
  };

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
