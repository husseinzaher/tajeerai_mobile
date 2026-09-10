import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/design_system/display/relative_time.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_ar.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_en.dart';

/// Pure functions, so this pumps nothing.
///
/// It is also the only place Arabic date formatting is checked at all: the
/// logic used to live inside a conversation row, where testing it in Arabic
/// meant building a screen.
void main() {
  // Wednesday, mid-afternoon, so nothing here sits near a midnight boundary by
  // accident.
  final DateTime now = DateTime(2026, 3, 11, 15, 30);

  group('a conversation row', () {
    String row(DateTime at, {String locale = 'ar'}) => AppRelativeTime.forRow(
      at,
      locale: locale,
      messages: locale == 'ar' ? appMessagesAr : appMessagesEn,
      now: now,
    );

    test('today is a clock time', () {
      expect(row(DateTime(2026, 3, 11, 10, 24)), '10:24');
    });

    test('yesterday is a word, in the reader language', () {
      expect(row(DateTime(2026, 3, 10, 23, 0)), appMessagesAr.yesterday);
      expect(
        row(DateTime(2026, 3, 10, 23, 0), locale: 'en'),
        appMessagesEn.yesterday,
      );
    });

    test('one minute either side of midnight is two different days', () {
      // Calendar days, not 24-hour periods. 23:59 and 00:01 are one minute
      // apart and a reader means "yesterday" for the first.
      expect(row(DateTime(2026, 3, 11, 0, 1)), '00:01');
      expect(row(DateTime(2026, 3, 10, 23, 59)), appMessagesAr.yesterday);
    });

    test('older this year is a date without the year', () {
      final String formatted = row(DateTime(2026, 3, 2, 9, 0));
      expect(formatted, isNot(contains('2026')));
      expect(formatted, contains('2'));
    });

    test('a previous year carries the year', () {
      expect(row(DateTime(2025, 12, 24, 9, 0)), contains('2025'));
    });

    test('a stamp from the future is clock skew, not the future', () {
      // A message that has already arrived cannot be three hours away. Showing
      // that reads as a bug because it is one.
      expect(row(DateTime(2026, 3, 11, 18, 45)), '18:45');
      expect(row(DateTime(2026, 3, 12, 9, 0)), '09:00');
    });
  });

  group('a day heading', () {
    String day(DateTime at, {String locale = 'ar'}) => AppRelativeTime.forDay(
      at,
      locale: locale,
      messages: locale == 'ar' ? appMessagesAr : appMessagesEn,
      now: now,
    );

    test('today and yesterday are words', () {
      expect(day(DateTime(2026, 3, 11, 8, 0)), appMessagesAr.today);
      expect(day(DateTime(2026, 3, 10, 8, 0)), appMessagesAr.yesterday);
    });

    test('anything older is a full date', () {
      expect(day(DateTime(2026, 1, 5, 8, 0)), isNot(appMessagesAr.today));
      expect(day(DateTime(2026, 1, 5, 8, 0)).length, greaterThan(3));
    });
  });

  group('Arabic formatting is Gregorian, with Latin digits', () {
    test('the digits are the ones invoices are written in', () {
      // `ar` otherwise resolves to Arabic-Indic numerals, and a figure that
      // does not match the bank transfer it is read against is worse than an
      // untranslated one.
      final String clock = AppRelativeTime.clock(
        DateTime(2026, 3, 11, 14, 5),
        locale: 'ar',
      );

      expect(clock, matches(RegExp(r'^[0-9:\s]+$')), reason: clock);
      expect(clock, contains('14'));
    });

    test('the month name stays in the reader language', () {
      // The digits are folded; the words are not. A date that says "March" to
      // an Arabic reader is a different failure from one that says ٢.
      final String date = AppRelativeTime.forRow(
        DateTime(2026, 3, 2),
        locale: 'ar',
        messages: appMessagesAr,
        now: now,
      );

      expect(date, contains('2'));
      expect(date, matches(RegExp(r'[\u0600-\u06FF]')), reason: date);
      expect(date, isNot(contains('March')));
    });

    test('every digit it prints is one an invoice would use', () {
      for (final DateTime at in <DateTime>[
        DateTime(2026, 3, 11, 14, 5),
        DateTime(2026, 3, 2),
        DateTime(2025, 12, 24),
      ]) {
        final String formatted = AppRelativeTime.forRow(
          at,
          locale: 'ar',
          messages: appMessagesAr,
          now: now,
        );
        expect(
          formatted,
          isNot(matches(RegExp(r'[\u0660-\u0669\u06F0-\u06F9]'))),
          reason: formatted,
        );
      }
    });
  });
}
