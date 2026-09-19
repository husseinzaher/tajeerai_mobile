// ignore_for_file: avoid_print
//
// Writes the iOS Google Sign-In keys Info.plist needs from TAJEER_GOOGLE_IOS_CLIENT_ID.
//
// Usage:
//   dart run tool/configure_google_sign_in.dart
//   dart run tool/configure_google_sign_in.dart --check
//
// Reads mobile/.env first, then .env.development. The value is the OAuth client
// id of type "iOS" from Google Cloud Console — not the web client id the API
// stores for backend verification.

import 'dart:io';

const String _envKey = 'TAJEER_GOOGLE_IOS_CLIENT_ID';
const String _infoPlistPath = 'ios/Runner/Info.plist';
const String _beginMarker = '<!-- GOOGLE_SIGN_IN_BEGIN -->';
const String _endMarker = '<!-- GOOGLE_SIGN_IN_END -->';

Future<void> main(List<String> args) async {
  final bool checkOnly = args.contains('--check');
  final String? clientId = _readClientId();

  if (clientId == null) {
    stderr.writeln(
      '$_envKey is not set. Add it to .env, then run make google-sign-in-setup.',
    );
    exit(1);
  }

  final File infoPlist = File(_infoPlistPath);

  if (!infoPlist.existsSync()) {
    stderr.writeln('Could not find $_infoPlistPath.');
    exit(1);
  }

  final String original = infoPlist.readAsStringSync();
  final String updated = _apply(original, clientId);

  if (original == updated) {
    if (checkOnly) {
      print('Google Sign-In iOS configuration is up to date.');
      return;
    }

    print('Google Sign-In iOS configuration is already current.');
    return;
  }

  if (checkOnly) {
    stderr.writeln(
      'Google Sign-In iOS configuration is stale. Run make google-sign-in-setup.',
    );
    exit(1);
  }

  infoPlist.writeAsStringSync(updated);
  print('Updated $_infoPlistPath for Google Sign-In.');
}

String? _readClientId() {
  for (final String path in <String>['.env', '.env.development']) {
    final File file = File(path);

    if (!file.existsSync()) {
      continue;
    }

    for (final String line in file.readAsLinesSync()) {
      final String trimmed = line.trim();

      if (trimmed.startsWith('#') || !trimmed.contains('=')) {
        continue;
      }

      final List<String> parts = trimmed.split('=');

      if (parts.first.trim() != _envKey) {
        continue;
      }

      final String value = parts.sublist(1).join('=').trim();

      if (value.isNotEmpty) {
        return value;
      }
    }
  }

  return null;
}

String _apply(String contents, String clientId) {
  final String? urlScheme = reversedClientId(clientId);

  if (urlScheme == null) {
    stderr.writeln(
      '$_envKey must end with .apps.googleusercontent.com — got "$clientId".',
    );
    exit(1);
  }

  var updated = _upsertClientId(contents, clientId);
  updated = _upsertUrlScheme(updated, urlScheme);

  return updated;
}

String _upsertClientId(String contents, String clientId) {
  final String block =
      '\t$_beginMarker\n\t<key>GIDClientID</key>\n\t<string>$clientId</string>\n\t$_endMarker';

  if (contents.contains(_beginMarker) && contents.contains(_endMarker)) {
    final int start = contents.indexOf(_beginMarker);
    final int end = contents.indexOf(_endMarker) + _endMarker.length;

    return contents.replaceRange(start, end, block);
  }

  const String anchor = '\t<key>NSMicrophoneUsageDescription</key>';

  if (!contents.contains(anchor)) {
    stderr.writeln('Could not find the Info.plist insertion point.');
    exit(1);
  }

  return contents.replaceFirst(anchor, '$block\n$anchor');
}

String _upsertUrlScheme(String contents, String urlScheme) {
  final String entry =
      '''
\t\t<dict>
\t\t\t<key>CFBundleTypeRole</key>
\t\t\t<string>Editor</string>
\t\t\t<key>CFBundleURLSchemes</key>
\t\t\t<array>
\t\t\t\t<string>$urlScheme</string>
\t\t\t</array>
\t\t</dict>''';

  final RegExp existing = RegExp(
    r'\t\t<dict>\s*\n'
    r'\t\t\t<key>CFBundleTypeRole</key>\s*\n'
    r'\t\t\t<string>Editor</string>\s*\n'
    r'\t\t\t<key>CFBundleURLSchemes</key>\s*\n'
    r'\t\t\t<array>\s*\n'
    r'\t\t\t\t<string>com\.googleusercontent\.apps\.[^<]+</string>\s*\n'
    r'\t\t\t</array>\s*\n'
    r'\t\t</dict>',
  );

  if (existing.hasMatch(contents)) {
    return contents.replaceFirst(existing, entry.trimRight());
  }

  const String anchor = '\t<key>CFBundleURLTypes</key>';

  if (!contents.contains(anchor)) {
    stderr.writeln(
      'Could not find CFBundleURLTypes in $_infoPlistPath. '
      'The social callback scheme must exist before Google Sign-In is configured.',
    );
    exit(1);
  }

  const String firstDictEnd = '\t\t</dict>\n';
  final int typesStart = contents.indexOf(anchor);
  final int dictClose = contents.indexOf(firstDictEnd, typesStart);

  if (dictClose < 0) {
    stderr.writeln('Could not find the end of CFBundleURLTypes.');
    exit(1);
  }

  final int insertAt = dictClose + firstDictEnd.length;

  return contents.replaceRange(insertAt, insertAt, '$entry\n');
}

/// The URL scheme Google expects for an iOS OAuth client id.
String? reversedClientId(String clientId) {
  const String suffix = '.apps.googleusercontent.com';

  if (!clientId.endsWith(suffix)) {
    return null;
  }

  final String prefix = clientId.substring(0, clientId.length - suffix.length);

  if (prefix.isEmpty) {
    return null;
  }

  return 'com.googleusercontent.apps.$prefix';
}
