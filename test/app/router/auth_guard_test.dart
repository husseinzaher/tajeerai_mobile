import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/router/guards/auth_guard.dart';
import 'package:tajeerai_mobile/app/router/routes.dart';
import 'package:tajeerai_mobile/features/auth/application/state/auth_state.dart';
import 'package:tajeerai_mobile/features/auth/domain/entities/user.dart';

const _session = Session(
  user: AuthenticatedUser(
    id: 'u1',
    name: 'Ada',
    email: 'ada@demo.test',
    role: 'member',
    locale: 'ar',
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

  group('route paths', () {
    test('builds a thread path from a conversation id', () {
      expect(
        AppRoutes.conversationDetailPath('abc-123'),
        '/conversations/thread/abc-123',
      );
    });
  });
}
