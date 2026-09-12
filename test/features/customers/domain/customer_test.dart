import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/features/customers/domain/entities/customer.dart';

import '../../../support/fixed_clock.dart';

Customer _customer({String name = 'Ada Lovelace', String? phone}) {
  return Customer(id: 'c1', name: name, phone: phone, createdAt: testEpoch);
}

void main() {
  group('displayName', () {
    test('is the name, trimmed', () {
      expect(_customer(name: '  Ada Lovelace ').displayName, 'Ada Lovelace');
    });

    /*
      Never stored. A placeholder written into the column would become
      somebody's actual name the next time the row was saved.
    */
    test('falls back to the number when there is no name', () {
      expect(
        _customer(name: '   ', phone: '+966501234567').displayName,
        '+966501234567',
      );
    });

    test('is empty when there is neither, rather than a made-up label', () {
      expect(_customer(name: '').displayName, '');
    });
  });

  group('initials', () {
    test('takes the first letter of the first two words', () {
      expect(_customer().initials, 'AL');
    });

    test('takes two letters from a single name', () {
      expect(_customer(name: 'Ada').initials, 'AD');
    });

    /* Arabic names are the common case, and a rune is not a byte. */
    test('does not split an Arabic letter in half', () {
      expect(_customer(name: 'أحمد المطيري').initials, 'أا');
    });

    test('is empty when there is nothing to draw', () {
      expect(_customer(name: '').initials, '');
    });
  });

  group('answersTo', () {
    test('recognises its own number however the caller dialled it', () {
      final Customer ada = _customer(phone: '+966 50 123 4567');

      expect(ada.answersTo('0501234567'), isTrue);
      expect(ada.answersTo('00966501234567'), isTrue);
    });

    test('does not answer for somebody else', () {
      expect(
        _customer(phone: '+966501234567').answersTo('+966509999999'),
        isFalse,
      );
    });

    /*
      A contact with no number must not answer for every withheld call, which
      is what a naive empty-matches-empty comparison would do.
    */
    test('does not answer when it has no number', () {
      expect(_customer().answersTo('0501234567'), isFalse);
    });
  });
}
