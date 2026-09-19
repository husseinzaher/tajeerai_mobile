import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/login_phone_reader.dart';

void main() {
  group('readDialledNumber', () {
    test('adopts the country the digits name', () {
      expect(
        LoginPhoneReader.readDialledNumber('201008755187'),
        const DialledNumber(country: 'EG', number: '+201008755187'),
      );
    });

    test(
      'leaves a number that is already local to the selected country alone',
      () {
        expect(LoginPhoneReader.readDialledNumber('501234567'), isNull);
        expect(LoginPhoneReader.readDialledNumber('0501234567'), isNull);
      },
    );

    test('strips a calling code that repeats the selected country', () {
      expect(
        LoginPhoneReader.readDialledNumber('966501234567')?.number,
        '+966501234567',
      );
    });

    test(
      'reads a stated calling code even where the local number would be valid',
      () {
        expect(
          LoginPhoneReader.readDialledNumber('+201008755187')?.country,
          'EG',
        );
        expect(
          LoginPhoneReader.readDialledNumber('00201008755187')?.country,
          'EG',
        );
      },
    );

    test('says nothing until the digits are a whole number', () {
      for (final String partial in <String>[
        '',
        '2',
        '20',
        '2010',
        '20100875',
        '+966',
      ]) {
        expect(LoginPhoneReader.readDialledNumber(partial), isNull);
      }
    });

    test('ignores punctuation, which is how a pasted number arrives', () {
      expect(
        LoginPhoneReader.readDialledNumber('+20 100 875 5187')?.number,
        '+201008755187',
      );
      expect(
        LoginPhoneReader.readDialledNumber('1 (212) 555-1234')?.number,
        '+12125551234',
      );
    });
  });

  group('readPhoneNumber', () {
    test('falls back to reading the digits as a local number', () {
      expect(
        LoginPhoneReader.readPhoneNumber('0501234567'),
        const DialledNumber(country: 'SA', number: '+966501234567'),
      );
    });

    test('still prefers a calling code the digits carry themselves', () {
      expect(
        LoginPhoneReader.readPhoneNumber('201008755187'),
        const DialledNumber(country: 'EG', number: '+201008755187'),
      );
    });

    test('answers nothing for something that is not a phone number', () {
      expect(LoginPhoneReader.readPhoneNumber('ada@demo.test'), isNull);
      expect(LoginPhoneReader.readPhoneNumber('05012'), isNull);
    });
  });

  group('resolveForSubmit', () {
    test('posts a phone identifier in E.164', () {
      expect(
        LoginPhoneReader.resolveForSubmit('201008755187'),
        '+201008755187',
      );
      expect(
        LoginPhoneReader.resolveForSubmit('+201008755187'),
        '+201008755187',
      );
    });

    test('leaves email identifiers untouched', () {
      expect(
        LoginPhoneReader.resolveForSubmit('ada@demo.test'),
        'ada@demo.test',
      );
    });
  });

  group('isPhoneShaped', () {
    test('recognises digits and phone punctuation only', () {
      expect(LoginPhoneReader.isPhoneShaped('201008755187'), isTrue);
      expect(LoginPhoneReader.isPhoneShaped('+20 100-875-5187'), isTrue);
      expect(LoginPhoneReader.isPhoneShaped('ada@demo.test'), isFalse);
      expect(LoginPhoneReader.isPhoneShaped(''), isFalse);
    });
  });
}
