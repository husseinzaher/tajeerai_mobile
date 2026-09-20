import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';

const _user = AuthenticatedUser(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@demo.test',
  role: 'member',
  locale: 'ar',
);

const _workspace = Workspace(
  id: 't1',
  name: 'Demo',
  slug: 'demo',
  locale: 'ar',
);

void main() {
  group('AuthenticatedUser', () {
    test('two users with the same fields are equal', () {
      const other = AuthenticatedUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
      );

      // Value equality keeps Riverpod and the router from rebuilding on every
      // emission of an unchanged session.
      expect(_user, other);
      expect(_user.hashCode, other.hashCode);
    });

    test('users differing in any field are not equal', () {
      expect(
        _user,
        isNot(
          const AuthenticatedUser(
            id: 'u2',
            name: 'Ada Lovelace',
            email: 'ada@demo.test',
            role: 'member',
            locale: 'ar',
          ),
        ),
      );

      expect(
        _user,
        isNot(
          const AuthenticatedUser(
            id: 'u1',
            name: 'Grace Hopper',
            email: 'ada@demo.test',
            role: 'member',
            locale: 'ar',
          ),
        ),
      );
    });

    test('a permission granted or withdrawn makes a different user', () {
      const granted = AuthenticatedUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
        permissions: <String>{'read:Customer'},
      );

      // Permissions were once left out of equality, so a session re-read with
      // a new grant compared equal to the old one and never reached a screen.
      expect(_user, isNot(granted));
    });

    test('a denial added or lifted makes a different user', () {
      const withheld = AuthenticatedUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
        denied: <String>{'read:Customer'},
      );

      expect(_user, isNot(withheld));
      expect(_user.hashCode, isNot(withheld.hashCode));
    });

    test('the order permissions arrive in does not matter', () {
      const first = AuthenticatedUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
        permissions: <String>{'read:Customer', 'read:Order'},
      );
      const second = AuthenticatedUser(
        id: 'u1',
        name: 'Ada Lovelace',
        email: 'ada@demo.test',
        role: 'member',
        locale: 'ar',
        permissions: <String>{'read:Order', 'read:Customer'},
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('does not print anything identifying', () {
      // A user object interpolated into a log must not carry a name or email
      // into a third-party system.
      final printed = _user.toString();

      expect(printed, contains('u1'));
      expect(printed, isNot(contains('ada@demo.test')));
      expect(printed, isNot(contains('Ada')));
    });

    test('an unlisted permission is refused', () {
      expect(_user.can('conversation:read'), isFalse);
    });
  });

  group('Workspace', () {
    test('compares by value', () {
      expect(
        _workspace,
        const Workspace(id: 't1', name: 'Demo', slug: 'demo', locale: 'ar'),
      );
      expect(
        _workspace.hashCode,
        const Workspace(
          id: 't1',
          name: 'Demo',
          slug: 'demo',
          locale: 'ar',
        ).hashCode,
      );
    });

    test('differs when any field differs', () {
      expect(
        _workspace,
        isNot(
          const Workspace(id: 't2', name: 'Demo', slug: 'demo', locale: 'ar'),
        ),
      );
    });
  });

  group('Session', () {
    test('reports whether it has a workspace', () {
      expect(
        const Session(user: _user, workspace: _workspace).hasWorkspace,
        isTrue,
      );
      expect(const Session(user: _user).hasWorkspace, isFalse);
    });

    test('compares by value', () {
      expect(
        const Session(user: _user, workspace: _workspace),
        const Session(user: _user, workspace: _workspace),
      );
      expect(
        const Session(user: _user, workspace: _workspace).hashCode,
        const Session(user: _user, workspace: _workspace).hashCode,
      );
    });

    test('a session with a different workspace is different', () {
      expect(
        const Session(user: _user, workspace: _workspace),
        isNot(const Session(user: _user)),
      );
    });
  });
}
