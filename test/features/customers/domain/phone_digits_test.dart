import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/domain/value_objects/phone_digits.dart';

/// The cases are shared with the backend's `PhoneNumber.digits`, whose regex
/// is `/(?!^\+)[^\d]/g`. Where the two disagree, one of them is a bug.
void main() {
  group('PhoneDigits.of', () {
    test('keeps a leading plus and drops every other non-digit', () {
      expect(PhoneDigits.of('+966 50 123 4567'), '+966501234567');
      expect(PhoneDigits.of('(050) 123-4567'), '0501234567');
      expect(PhoneDigits.of(' +966-50-123-4567 '), '+966501234567');
    });

    test('drops a plus that is not first, as the backend regex does', () {
      expect(PhoneDigits.of('00966+501234567'), '00966501234567');
    });

    test('answers empty for something with no number in it', () {
      expect(PhoneDigits.of(''), '');
      expect(PhoneDigits.of('   '), '');
      expect(PhoneDigits.of('Ada'), '');
    });
  });

  group('PhoneDigits.bare', () {
    test('is the digits without the plus -- the lookup key', () {
      expect(PhoneDigits.bare('+966501234567'), '966501234567');
      expect(PhoneDigits.bare('0501234567'), '0501234567');
    });
  });

  group('PhoneDigits.suffix', () {
    test('is the last nine digits, which every spelling shares', () {
      expect(PhoneDigits.suffix('+966501234567'), '501234567');
      expect(PhoneDigits.suffix('00966501234567'), '501234567');
      expect(PhoneDigits.suffix('0501234567'), '501234567');
    });

    /*
      A short code is not a subscriber number: padding it out to nine would
      make two different services the same caller.
    */
    test('is the whole thing when it is shorter than nine digits', () {
      expect(PhoneDigits.suffix('9200'), '9200');
    });
  });

  group('PhoneDigits.isInternational', () {
    test('accepts a number written in full, however it was spaced', () {
      expect(PhoneDigits.isInternational('+966501234567'), isTrue);
      expect(PhoneDigits.isInternational('+966 50 123 4567'), isTrue);
      expect(PhoneDigits.isInternational('+20 100 875 5187'), isTrue);
    });

    /* The mistake this exists to catch. */
    test('refuses a national number with no country code', () {
      expect(PhoneDigits.isInternational('0501234567'), isFalse);
      expect(PhoneDigits.isInternational('501234567'), isFalse);
      expect(PhoneDigits.isInternational('00966501234567'), isFalse);
    });

    test('refuses something too short or too long to be a number', () {
      expect(PhoneDigits.isInternational('+1234567'), isFalse);
      expect(PhoneDigits.isInternational('+1234567890123456'), isFalse);
      expect(PhoneDigits.isInternational('+'), isFalse);
      expect(PhoneDigits.isInternational(''), isFalse);
    });
  });

  group('PhoneDigits.sameNumber', () {
    test('matches one person however each side was spelled', () {
      expect(PhoneDigits.sameNumber('+966 50 123 4567', '0501234567'), isTrue);
      expect(PhoneDigits.sameNumber('00966501234567', '+966501234567'), isTrue);
    });

    test('does not match two different people', () {
      expect(PhoneDigits.sameNumber('+966501234567', '+966501234568'), isFalse);
    });

    /*
      Nothing is not a match for nothing. A contact with no number must not
      answer for every call whose number is withheld.
    */
    test('never matches when either side has no digits', () {
      expect(PhoneDigits.sameNumber('', '0501234567'), isFalse);
      expect(PhoneDigits.sameNumber('unknown', ''), isFalse);
    });
  });
}
