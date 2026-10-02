import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/domain/value_objects/whatsapp_contact.dart';

/// The two keys the WhatsApp channel writes, read back the way the web reads
/// them - and nothing invented when they are missing.
void main() {
  test('reads the username and user id from metadata', () {
    final WhatsAppContact contact = WhatsAppContact.fromMetadata(
      <String, Object?>{
        'whatsappUsername': 'sara',
        'whatsappUserId': '1234@lid',
      },
    );

    expect(contact.username, 'sara');
    expect(contact.handle, '@sara');
    expect(contact.userId, '1234@lid');
    expect(contact.isEmpty, isFalse);
  });

  test('is empty for a contact typed in by hand', () {
    final WhatsAppContact contact = WhatsAppContact.fromMetadata(
      const <String, Object?>{},
    );

    expect(contact.isEmpty, isTrue);
    expect(contact.handle, isNull);
  });

  /* A blank or non-string value is not an identity. */
  test('ignores blanks and values of the wrong type', () {
    final WhatsAppContact contact = WhatsAppContact.fromMetadata(
      <String, Object?>{'whatsappUsername': '  ', 'whatsappUserId': 42},
    );

    expect(contact.isEmpty, isTrue);
  });
}
