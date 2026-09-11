import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/failures/app_failure.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';
import 'package:tajeerai_mobile/features/auth/domain/services/auth_service.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/login_identifier.dart';
import 'package:tajeerai_mobile/features/auth/domain/value_objects/password.dart';

import 'fakes/fake_auth_repository.dart';

Session _session({bool withWorkspace = true}) => Session(
  user: const AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
  ),
  workspace: withWorkspace
      ? const Workspace(id: 't1', name: 'Demo', slug: 'demo', locale: 'ar')
      : null,
);

void main() {
  late FakeAuthRepository repository;
  late AuthService service;

  setUp(() {
    repository = FakeAuthRepository();
    service = AuthService(repository);
  });

  group('LoginIdentifier', () {
    test('accepts an email address', () {
      final result = LoginIdentifier.parse('ada@demo.test');

      expect(result, isA<ValidLoginIdentifier>());
      expect(
        (result as ValidLoginIdentifier).identifier.value,
        'ada@demo.test',
      );
      expect(result.identifier.looksLikeEmail, isTrue);
    });

    test('accepts a phone number', () {
      final result = LoginIdentifier.parse('+966500000000');

      expect(result, isA<ValidLoginIdentifier>());

      // The server tells email and phone apart; the client validates shape
      // only, or it would block a login the server would have accepted.
      expect(
        (result as ValidLoginIdentifier).identifier.looksLikeEmail,
        isFalse,
      );
    });

    test('trims surrounding whitespace', () {
      final result =
          LoginIdentifier.parse('  ada@demo.test  ') as ValidLoginIdentifier;

      expect(result.identifier.value, 'ada@demo.test');
    });

    test('rejects an empty identifier', () {
      expect(
        (LoginIdentifier.parse('') as InvalidLoginIdentifier).error,
        LoginIdentifierError.empty,
      );
      expect(
        (LoginIdentifier.parse('   ') as InvalidLoginIdentifier).error,
        LoginIdentifierError.empty,
      );
    });

    test('rejects anything shorter than the server bound', () {
      expect(
        (LoginIdentifier.parse('ab') as InvalidLoginIdentifier).error,
        LoginIdentifierError.tooShort,
      );
    });

    test('rejects anything longer than the server bound', () {
      final long = 'a' * (LoginIdentifier.maxLength + 1);

      expect(
        (LoginIdentifier.parse(long) as InvalidLoginIdentifier).error,
        LoginIdentifierError.tooLong,
      );
    });
  });

  group('Password', () {
    test('accepts any non-empty value within the bound', () {
      expect(Password.parse('x'), isA<ValidPassword>());
    });

    test('does not trim -- a space is part of a password', () {
      final result = Password.parse(' secret ') as ValidPassword;

      // Silently stripping it locks the user out of their own account.
      expect(result.password.exposeSecret, ' secret ');
    });

    test('rejects an empty password', () {
      expect(
        (Password.parse('') as InvalidPassword).error,
        PasswordError.empty,
      );
    });

    test('rejects one over the server bound', () {
      final long = 'x' * (Password.maxLength + 1);

      expect(
        (Password.parse(long) as InvalidPassword).error,
        PasswordError.tooLong,
      );
    });

    test('never reveals the secret when interpolated', () {
      final password = (Password.parse('hunter2') as ValidPassword).password;

      // This is what stops a password reaching a crash report through a debug
      // string.
      expect('$password', isNot(contains('hunter2')));
      expect(password.toString(), 'Password(***)');
    });
  });

  group('validate', () {
    test('accepts a well-formed form', () {
      final result = service.validate(
        identifier: 'ada@demo.test',
        password: 'secret',
      );

      expect(result, isA<ValidCredentials>());
    });

    test('reports both field errors at once', () {
      final result = service.validate(identifier: '', password: '');

      final failure = (result as InvalidCredentials).failure;

      // Reporting one at a time makes the user submit twice to learn both.
      expect(failure.errorsFor('identifier'), <String>['identifier.required']);
      expect(failure.errorsFor('password'), <String>['password.required']);
    });

    test('emits stable keys rather than English copy', () {
      final result = service.validate(identifier: 'ab', password: 'x');

      // The domain carries no presentation copy; the controller resolves these.
      expect(
        (result as InvalidCredentials).failure.errorsFor('identifier'),
        <String>['identifier.tooShort'],
      );
    });
  });

  group('signIn', () {
    test('returns the session on valid credentials', () async {
      repository.nextSession = _session();

      final session = await service.signIn(
        identifier: 'ada@demo.test',
        password: 'secret',
      );

      expect(session.user.id, 'u1');
      expect(repository.signInCalls, 1);
    });

    test('passes the remember flag through to the repository', () async {
      repository.nextSession = _session();

      await service.signIn(
        identifier: 'ada@demo.test',
        password: 'secret',
        remember: true,
      );

      // It changes the refresh token's lifetime server-side, so it is not
      // cosmetic.
      expect(repository.lastRemember, isTrue);
    });

    test('rejects an invalid form without contacting the repository', () async {
      await expectLater(
        service.signIn(identifier: '', password: ''),
        throwsA(isA<ValidationFailure>()),
      );

      expect(repository.signInCalls, 0);
    });

    test('propagates a rejection from the server', () async {
      repository.failureToThrow = const AuthenticationFailure(
        message: 'Not recognised.',
      );

      await expectLater(
        service.signIn(identifier: 'ada@demo.test', password: 'wrong'),
        throwsA(isA<AuthenticationFailure>()),
      );
    });
  });

  group('restore', () {
    test('prefers the cached session', () async {
      repository.cached = _session();

      final session = await service.restore();

      // Offline-first applied to authentication: the app opens into its real
      // UI without waiting for -- or requiring -- a reachable server.
      expect(session, isNotNull);
      expect(repository.restoreCalls, 0);
    });

    test('falls back to the server when nothing is cached', () async {
      repository.cached = null;
      repository.nextRestored = _session();

      final session = await service.restore();

      expect(session, isNotNull);
      expect(repository.restoreCalls, 1);
    });

    test('returns null when there is no recoverable session', () async {
      repository.cached = null;
      repository.nextRestored = null;

      expect(await service.restore(), isNull);
    });
  });

  group('workspace access', () {
    test('a session with a workspace may use workspace features', () {
      expect(service.canAccessWorkspace(_session()), isTrue);
    });

    test('a session without a workspace may not', () {
      // Without one the socket joins no tenant room, so the Inbox would render
      // an empty list forever rather than saying why.
      expect(
        service.canAccessWorkspace(_session(withWorkspace: false)),
        isFalse,
      );
    });

    test('no session may not', () {
      expect(service.canAccessWorkspace(null), isFalse);
    });
  });

  group('permissions', () {
    AuthenticatedUser holding(
      Set<String> permissions, {
      Set<String> denied = const <String>{},
      bool isPlatformAdmin = false,
    }) {
      return AuthenticatedUser(
        id: 'u1',
        name: 'Ada',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
        isPlatformAdmin: isPlatformAdmin,
        permissions: permissions,
        denied: denied,
      );
    }

    test('an ordinary user holds only what was granted', () {
      final AuthenticatedUser user = holding(<String>{'read:Conversation'});

      expect(user.can('read:Conversation'), isTrue);
      expect(user.can('delete:Conversation'), isFalse);
      expect(user.can('read:Customer'), isFalse);
    });

    test('manage on a subject is every action on it', () {
      final AuthenticatedUser user = holding(<String>{'manage:Customer'});

      expect(user.can('read:Customer'), isTrue);
      expect(user.can('delete:Customer'), isTrue);
      expect(user.can('read:Order'), isFalse);
    });

    test('an action on all is that action on every subject', () {
      // How the support role is written: exactly `read:all`.
      final AuthenticatedUser user = holding(<String>{'read:all'});

      expect(user.can('read:Order'), isTrue);
      expect(user.can('update:Order'), isFalse);
    });

    test('manage on all is everything, which is what an owner holds', () {
      final AuthenticatedUser user = holding(<String>{'manage:all'});

      expect(user.can('read:Customer'), isTrue);
      expect(user.can('delete:Product'), isTrue);
    });

    test('a denial wins over any wildcard', () {
      // `permissions` cannot name what `manage:all` leaves out, so the backend
      // sends the exception on its own.
      final AuthenticatedUser user = holding(
        <String>{'manage:all'},
        denied: <String>{'read:Customer'},
      );

      expect(user.can('read:Customer'), isFalse);
      expect(user.can('read:Order'), isTrue);
    });

    test('being a platform admin grants nothing the rules do not', () {
      final AuthenticatedUser admin = holding(
        const <String>{},
        isPlatformAdmin: true,
      );

      expect(admin.can('read:Conversation'), isFalse);
    });
  });

  group('signOut', () {
    test('delegates to the repository', () async {
      await service.signOut();

      expect(repository.signOutCalls, 1);
    });
  });
}
