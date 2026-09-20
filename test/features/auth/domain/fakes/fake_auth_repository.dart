import 'dart:async';

import 'package:TajeerAi/features/auth/domain/entities/social_auth_config.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/auth/domain/repositories/auth_repository.dart';
import 'package:TajeerAi/features/auth/domain/value_objects/login_identifier.dart';
import 'package:TajeerAi/features/auth/domain/value_objects/password.dart';
import 'package:TajeerAi/features/auth/domain/value_objects/session_renewal.dart';

/// An in-memory [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  Session? nextSession;
  Session? cached;
  Session? nextRestored;
  String? token = 'token-1';

  /// What the next [renewSession] answers. Null renews [renewedSession] -- or
  /// the cached one -- with [refreshedToken], and stores that token as current,
  /// the way the real repository captures the new cookie.
  SessionRenewal? nextRenewal;
  Session? renewedSession;
  String refreshedToken = 'token-2';

  /// Thrown by the next [renewSession], for the unexpected-error path.
  Object? renewalError;

  Object? failureToThrow;

  /// Holds `signIn` open so a test can observe the in-flight loading state.
  ///
  /// Without it the fake resolves within the same microtask and the spinner is
  /// gone before the first `pump`.
  Completer<void>? signInGate;

  int signInCalls = 0;
  int restoreCalls = 0;
  int signOutCalls = 0;
  int refreshCalls = 0;

  bool? lastRemember;
  String? lastIdentifier;

  @override
  Future<Session> signIn({
    required LoginIdentifier identifier,
    required Password password,
    bool remember = false,
  }) async {
    signInCalls += 1;
    lastRemember = remember;
    lastIdentifier = identifier.value;

    final gate = signInGate;

    if (gate != null) await gate.future;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    final session = nextSession;

    if (session == null) {
      throw StateError('FakeAuthRepository.nextSession was not set.');
    }

    cached = session;

    return session;
  }

  /// What the social flow is handed, for the tests that drive it.
  List<String> providers = const <String>['google'];
  String? googleWebClientId = '123.apps.googleusercontent.com';
  Session? socialSession;
  Object? socialFailure;
  final List<String> exchanged = <String>[];
  final List<String> googleTokens = <String>[];

  @override
  Future<SocialAuthConfig> socialAuthConfig() async => SocialAuthConfig(
    providers: providers,
    googleWebClientId: googleWebClientId,
  );

  @override
  Uri socialSignInUrl({
    required String provider,
    required String codeChallenge,
    required String locale,
  }) => Uri.parse(
    'https://api.test/v1/auth/social/$provider/start'
    '?client=mobile&codeChallenge=$codeChallenge&locale=$locale',
  );

  @override
  Future<Session> completeSocialSignIn({
    required String code,
    required String codeVerifier,
  }) async {
    exchanged.add('$code:$codeVerifier');

    final Object? failure = socialFailure;

    if (failure != null) throw failure;

    return socialSession ?? nextSession!;
  }

  @override
  Future<Session> completeNativeGoogleSignIn({
    required String idToken,
    required String locale,
  }) async {
    googleTokens.add('$idToken:$locale');

    final Object? failure = socialFailure;

    if (failure != null) throw failure;

    return socialSession ?? nextSession!;
  }

  @override
  Future<Session?> cachedSession() async => cached;

  @override
  Future<Session?> restoreSession() async {
    restoreCalls += 1;

    final failure = failureToThrow;

    if (failure != null) throw failure;

    return nextRestored;
  }

  @override
  Future<SessionRenewal> renewSession() async {
    refreshCalls += 1;

    final Object? error = renewalError;
    if (error != null) throw error;

    final SessionRenewal? scripted = nextRenewal;
    if (scripted != null) return scripted;

    final Session? session = renewedSession ?? cached ?? nextSession;

    if (session == null) {
      throw StateError('FakeAuthRepository has no session to renew.');
    }

    token = refreshedToken;

    return SessionRenewed(session: session, accessToken: refreshedToken);
  }

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    cached = null;
    token = null;
  }
}
