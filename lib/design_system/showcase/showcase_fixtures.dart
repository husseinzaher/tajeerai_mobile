/// The story the showcase tells, in one place.
///
/// One store, a few of its customers, the channels they write from, and one
/// order they write about. Every section draws from it, so a reviewer turning
/// pages meets the same people, and changing the story is one edit rather than
/// a search.
///
/// Flat `const` values and nothing else: no builders, no widgets, no logic.
/// And values, not copy — a label that the design system or a screen owns is
/// not a fixture, however often the showcase happens to repeat it.
abstract final class ShowcaseFixtures {
  // The people.
  static const String customer = 'سارة أحمد';
  static const String secondCustomer = 'محمد علي';

  /// A customer who writes in English, for the mixed-direction cases.
  static const String latinCustomer = 'Lina Hassan';

  /// The number she calls from, for the Caller Card.
  static const String customerPhone = '+966501234567';

  // The store.
  static const String store = 'متجر النخبة';

  // Where they write from.
  static const String whatsapp = 'واتساب';
  static const String sms = 'رسائل SMS';
  static const String email = 'البريد الإلكتروني';

  // The order.
  static const String question = 'هل الطلب جاهز للاستلام اليوم؟';
  static const String answer = 'نعم، يصلك خلال ساعتين.';
  static const String orderNumber = 'رقم الطلب #1042';
  static const String photoCaption = 'هذا اللون';
}
