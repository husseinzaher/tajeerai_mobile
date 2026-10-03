import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks the caller card's two colour files against each other.
///
/// The card drawn over a ringing call is native Android, so its colours are
/// resources rather than Dart: `values/` is the light appearance and
/// `values-night/` the dark one, and Android picks between them from the
/// system's own setting. Nothing in the Dart tree can catch a key that exists
/// in only one of them - and the symptom is a colour that silently resolves to
/// the wrong appearance's value on a phone switched the other way, which is the
/// kind of thing found by a person holding a phone and not by a test suite.
///
/// So this is the test: same keys, both files, every value a literal colour.
void main() {
  const String light = 'android/app/src/main/res/values/caller_id_colors.xml';
  const String night =
      'android/app/src/main/res/values-night/caller_id_colors.xml';

  /// `name -> value` for every `<color>` in [path].
  Map<String, String> colors(String path) {
    final File file = File(path);

    expect(file.existsSync(), isTrue, reason: '$path is missing');

    final RegExp entry = RegExp(r'<color\s+name="([^"]+)"\s*>([^<]+)</color>');

    return <String, String>{
      for (final RegExpMatch match in entry.allMatches(file.readAsStringSync()))
        match.group(1)!: match.group(2)!.trim(),
    };
  }

  test('both appearances declare exactly the same colours', () {
    final Map<String, String> day = colors(light);
    final Map<String, String> dark = colors(night);

    expect(day.keys.toSet(), isNotEmpty);
    expect(
      dark.keys.toSet(),
      day.keys.toSet(),
      reason:
          'A colour declared in one file and not the other resolves to the '
          'wrong appearance on a phone set the other way. Add it to both.',
    );
  });

  test('every value is a literal colour, not a reference to another', () {
    for (final String path in <String>[light, night]) {
      for (final MapEntry<String, String> entry in colors(path).entries) {
        expect(
          entry.value,
          matches(RegExp(r'^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$')),
          reason: '${entry.key} in $path',
        );
      }
    }
  });

  /*
    The one pair that must differ, and the reason there are two tokens for the
    brand at all: #FACC15 is 1.53:1 on white, so light mode colours brand text
    with the preset's `focus` instead. A refactor that collapses them back into
    one makes the "customer" badge on the card unreadable in daylight.
  */
  test('the brand reads as ink in both, which means two different values', () {
    expect(colors(light)['caller_id_primary_text'], '#A16207');
    expect(colors(night)['caller_id_primary_text'], '#FACC15');
    expect(
      colors(light)['caller_id_primary'],
      colors(night)['caller_id_primary'],
    );
  });

  /* A light card on a light background needs its text dark, and vice versa. */
  test('the card and its primary text are opposites in the two files', () {
    expect(colors(light)['caller_id_card'], '#FFFFFF');
    expect(colors(light)['caller_id_text_primary'], '#111827');
    expect(colors(night)['caller_id_card'], '#1F2937');
    expect(colors(night)['caller_id_text_primary'], '#F9FAFB');
  });
}
