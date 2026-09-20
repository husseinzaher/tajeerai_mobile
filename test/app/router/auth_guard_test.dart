import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/router/guards/auth_guard.dart';
import 'package:TajeerAi/app/router/routes.dart';
import 'package:TajeerAi/features/auth/application/state/auth_state.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';

const _session = Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
    permissions: <String>{'read:Conversation'},
  ),
  workspace: Workspace(id: 't1', name: 'Demo', slug: 'demo', locale: 'ar'),
);

void main() {
  group('while the session is still unknown', () {
    const state = AuthState.unknown();

    test('holds on the splash route', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.splash),
        isNull,
      );
    });

    test('sends anything else to the splash route', () {
      // Deciding anything else here flashes the login screen at an
      // already-signed-in user on every cold start.
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.conversations),
        AppRoutes.splash,
      );
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.login),
        AppRoutes.splash,
      );
    });
  });

  group('when signed out', () {
    const state = AuthState.unauthenticated();

    test('allows the login route', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.login),
        isNull,
      );
    });

    test('sends a protected route to login', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.conversations),
        AppRoutes.login,
      );
    });

    test('sends a deep link into a thread to login', () {
      expect(
        AuthGuard.redirect(
          state: state,
          location: AppRoutes.conversationDetailPath('c1'),
        ),
        AppRoutes.login,
      );
    });

    test('sends the splash route to login once resolved', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.splash),
        AppRoutes.login,
      );
    });
  });

  group('when signed in', () {
    const state = AuthState.authenticated(_session);

    test('allows a protected route', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.conversations),
        isNull,
      );
    });

    test('allows a deep link into a thread', () {
      expect(
        AuthGuard.redirect(
          state: state,
          location: AppRoutes.conversationDetailPath('c1'),
        ),
        isNull,
      );
    });

    test('sends login to the Inbox', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.login),
        AppRoutes.conversations,
      );
    });

    test('sends the splash route to the Inbox', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.splash),
        AppRoutes.conversations,
      );
    });
  });

  group('when signed in with nothing on offer', () {
    // A role granted none of the permissions the shell's destinations need.
    const state = AuthState.authenticated(
      Session(
        user: AuthenticatedUser(
          id: 'u2',
          name: 'Grace',
          email: 'grace@demo.test',
          role: 'member',
          locale: 'ar',
        ),
        workspace: Workspace(
          id: 't1',
          name: 'Demo',
          slug: 'demo',
          locale: 'ar',
        ),
      ),
    );

    test('lands on Settings, which needs no permission', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.login),
        AppRoutes.settings,
      );
    });

    test('is moved off a destination they may not open', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.conversations),
        AppRoutes.settings,
      );
      expect(
        AuthGuard.redirect(
          state: state,
          location: AppRoutes.conversationDetailPath('c1'),
        ),
        AppRoutes.settings,
      );
    });

    test('and is left where they landed, which would otherwise loop', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.settings),
        isNull,
      );
    });
  });

  group('affectsRouting', () {
    const signedIn = AuthState.authenticated(_session);

    test('the first state the router sees does', () {
      expect(AuthGuard.affectsRouting(null, signedIn), isTrue);
    });

    test('signing in or out does', () {
      expect(
        AuthGuard.affectsRouting(const AuthState.unknown(), signedIn),
        isTrue,
      );
      expect(
        AuthGuard.affectsRouting(signedIn, const AuthState.unauthenticated()),
        isTrue,
      );
    });

    test('the same session read again does not', () {
      expect(
        AuthGuard.affectsRouting(
          signedIn,
          const AuthState.authenticated(_session),
        ),
        isFalse,
      );
    });

    test('a permission withdrawn does, though nobody signed out', () {
      const withdrawn = AuthState.authenticated(
        Session(
          user: AuthenticatedUser(
            id: 'u1',
            name: 'Ada',
            email: 'ada@demo.test',
            role: 'member',
            locale: 'ar',
          ),
          workspace: Workspace(
            id: 't1',
            name: 'Demo',
            slug: 'demo',
            locale: 'ar',
          ),
        ),
      );

      expect(AuthGuard.affectsRouting(signedIn, withdrawn), isTrue);
    });
  });

  group('route paths', () {
    test('builds a thread path from a conversation id', () {
      expect(
        AppRoutes.conversationDetailPath('abc-123'),
        '/conversations/thread/abc-123',
      );
    });
  });
}
