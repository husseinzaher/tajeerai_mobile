import 'dart:async';

import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/login_identifier.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/password.dart';

/// An in-memory [AuthRepository].
class FakeAuthRepository implements AuthRepository {
  Session? nextSession;
  Session? cached;
  Session? nextRestored;
  String? token = 'token-1';
  String? refreshedToken = 'token-2';

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
  Future<String?> refreshAccessToken() async {
    refreshCalls += 1;
    token = refreshedToken;

    return refreshedToken;
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
