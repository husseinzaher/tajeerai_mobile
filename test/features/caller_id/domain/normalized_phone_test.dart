import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/caller_id/domain/value_objects/normalized_phone.dart';

void main() {
  group('NormalizedPhone', () {
    test('parses a Saudi mobile number into e164 and suffix', () {
      final NormalizedPhone? phone = NormalizedPhone.parse('+966501234567');

      expect(phone, isNotNull);
      expect(phone!.digits, '501234567');
      expect(phone.suffix, '501234567');
      expect(phone.e164, contains('966'));
    });

    test('returns null for private or restricted callers', () {
      expect(NormalizedPhone.parse('private'), isNull);
      expect(NormalizedPhone.parse('restricted'), isNull);
    });
  });
}
