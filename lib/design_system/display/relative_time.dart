import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../localization/ds_messages.dart';

/// Timestamps, in the shape a list of them wants.
///
/// Pure functions, deliberately: this is the logic a conversation row uses to
/// decide between "10:24", "أمس" and "12 مارس", and it was living inside a
/// feature widget where it could not be tested in Arabic without pumping a
/// screen.
///
/// Everything here reads with **Latin digits in both languages**, for the same
/// reason the web design system forces `nu-latn`: a figure that does not match
/// the invoice or the bank transfer it is being read against is worse than an
/// untranslated one.
///
/// The mechanism is not the same, though, and the difference matters. The web
/// appends a `-u-nu-latn` extension to the locale, which JavaScript's `Intl`
/// understands. Dart's `intl` does not — it validates locale names against a
/// fixed list and rejects the extension outright — so the digits are folded
/// after formatting instead. Dart's `intl` is also Gregorian-only, so the
/// Hijri half of the web's problem does not exist here.
abstract final class AppRelativeTime {
  static final Set<String> _ready = <String>{};

  /// `intl` throws unless a locale's symbols have been loaded, and these are
  /// plain synchronous functions a widget calls while building — there is
  /// nowhere to await.
  ///
  /// So the component owns its own precondition instead of depending on the
  /// application to have remembered. `initializeDateFormatting` completes
  /// synchronously for the bundled data, which is why ignoring the future here
  /// is safe rather than optimistic; the alternative was a formatter that
  /// throws in every test and in any entry point that forgot the call.
  static String _prepared(String locale) {
    if (_ready.add(locale)) {
      unawaited(initializeDateFormatting(locale));
    }
    return locale;
  }

  /// Folds Arabic-Indic numerals to ASCII.
  ///
  /// Covers both ranges: Arabic-Indic (٠-٩) and the Extended set (۰-۹) that
  /// Persian and Urdu locales use. Month *names* are left in the reader's
  /// language — it is the figures that have to line up with everything else in
  /// the product, not the words.
  static String _latinDigits(String value) {
    final StringBuffer out = StringBuffer();
    for (final int rune in value.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        out.writeCharCode(rune - 0x0660 + 0x30);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        out.writeCharCode(rune - 0x06F0 + 0x30);
      } else {
        out.writeCharCode(rune);
      }
    }
    return out.toString();
  }

  /// A clock time: `10:24`.
  static String clock(DateTime at, {required String locale}) =>
      _latinDigits(DateFormat.Hm(_prepared(locale)).format(at.toLocal()));

  /// What a conversation row shows at the end of its title line.
  ///
  /// Today collapses to a clock time, yesterday to a word, and anything older
  /// to a date — because "منذ ٣ أيام" is worse than "9 مارس" for a rail people
  /// scan for a specific conversation.
  static String forRow(
    DateTime at, {
    required String locale,
    required AppMessages messages,
    DateTime? now,
  }) {
    final DateTime local = at.toLocal();
    final DateTime today = _midnight(now?.toLocal() ?? DateTime.now());
    final DateTime day = _midnight(local);
    final int days = today.difference(day).inDays;

    // A future stamp is clock skew, not the future. Showing "in 3 hours" for a
    // message that has already arrived reads as a bug, which it is.
    if (days <= 0) {
      return clock(local, locale: locale);
    }
    if (days == 1) {
      return messages.yesterday;
    }
    if (local.year == today.year) {
      return _latinDigits(DateFormat.MMMd(_prepared(locale)).format(local));
    }
    return _latinDigits(DateFormat.yMMMd(_prepared(locale)).format(local));
  }

  /// The heading over a group of messages: `اليوم`, `أمس`, or a full date.
  static String forDay(
    DateTime at, {
    required String locale,
    required AppMessages messages,
    DateTime? now,
  }) {
    final DateTime local = at.toLocal();
    final DateTime today = _midnight(now?.toLocal() ?? DateTime.now());
    final int days = today.difference(_midnight(local)).inDays;

    if (days <= 0) {
      return messages.today;
    }
    if (days == 1) {
      return messages.yesterday;
    }
    if (local.year == today.year) {
      return _latinDigits(DateFormat.MMMMd(_prepared(locale)).format(local));
    }
    return _latinDigits(DateFormat.yMMMMd(_prepared(locale)).format(local));
  }

  /// Calendar days apart, not 24-hour periods: 23:59 and 00:01 are different
  /// days and one minute, and a reader means the first.
  static DateTime _midnight(DateTime at) => DateTime(at.year, at.month, at.day);
}
