import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE pair (RFC 7636): the secret this device keeps, and the hash it sends.
///
/// The [verifier] never leaves the app until the code is redeemed; the
/// [challenge] is what the sign-in starts with. That asymmetry is the whole
/// mechanism - a social sign-in comes back to `tajeerai://auth/callback`, any
/// app on the phone may claim that scheme, and an app that reads the code off
/// the redirect still cannot spend it.
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  final String verifier;
  final String challenge;
}

/// Makes PKCE pairs.
///
/// In infrastructure rather than the domain because it is cryptography and a
/// source of randomness, not a business rule - and because the domain here
/// imports nothing but Dart. Behind a class so a test can hand the flow a
/// pair it chose.
class PkceGenerator {
  const PkceGenerator({Random? random}) : _random = random;

  final Random? _random;

  /// Thirty-two random bytes, base64url without padding: 43 characters, which
  /// is the shortest verifier the RFC allows and the longest a SHA-256
  /// challenge can describe.
  PkcePair create() {
    final Random random = _random ?? Random.secure();
    final List<int> bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final String verifier = base64UrlEncode(bytes).replaceAll('=', '');

    return PkcePair(verifier: verifier, challenge: challengeFor(verifier));
  }

  /// `base64url(sha256(verifier))`, unpadded - the `S256` method, which is the
  /// only one worth using. `plain` would put the verifier in the URL, which is
  /// the thing this exists to keep out of it.
  static String challengeFor(String verifier) =>
      base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
}
