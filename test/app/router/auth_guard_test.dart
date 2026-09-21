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
  _blogGroups();

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

    /*
      To login, and carrying where they were going: signing in now returns the
      member to the screen that sent them there rather than to the inbox.
    */
    test('sends a protected route to login, remembering it', () {
      final redirect = AuthGuard.redirect(
        state: state,
        location: AppRoutes.conversations,
      );

      expect(redirect, startsWith(AppRoutes.login));
      expect(
        Uri.parse(redirect!).queryParameters['from'],
        AppRoutes.conversations,
      );
    });

    test(
      'sends a deep link into a thread to login, remembering the thread',
      () {
        final redirect = AuthGuard.redirect(
          state: state,
          location: AppRoutes.conversationDetailPath('c1'),
        );

        expect(redirect, startsWith(AppRoutes.login));
        expect(
          Uri.parse(redirect!).queryParameters['from'],
          AppRoutes.conversationDetailPath('c1'),
        );
      },
    );

    test('sends the splash route to login once resolved', () {
      expect(
        AuthGuard.redirect(state: state, location: AppRoutes.splash),
        startsWith(AppRoutes.login),
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

/// The blog is the first product screen in this app a guest may open, and the
/// first public *subtree* - an article carries its slug, which the exact-set
/// test the guard grew up with cannot express at all.
void _blogGroups() {
  group('the blog, which anyone may read', () {
    test('lets a guest open the index', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.unauthenticated(),
          location: AppRoutes.blog,
        ),
        isNull,
      );
    });

    test('lets a guest open an article, whatever its slug', () {
      for (final slug in <String>[
        'how-to-connect-whatsapp',
        'ربط-المتجر-بواتساب',
        'a-very-long-slug-with-many-hyphens-2026',
      ]) {
        expect(
          AuthGuard.redirect(
            state: const AuthState.unauthenticated(),
            location: AppRoutes.blogArticlePath(slug),
          ),
          isNull,
          reason: slug,
        );
      }
    });

    /* A member tapping a shared link must land on the article, not the inbox. */
    test('does not bounce a signed-in member off an article', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.authenticated(_session),
          location: AppRoutes.blogArticlePath('how-to-connect-whatsapp'),
        ),
        isNull,
      );
    });

    test('still sends a signed-in member away from login', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.authenticated(_session),
          location: AppRoutes.login,
        ),
        AppRoutes.conversations,
      );
    });

    /* `/blogging` is not inside `/blog`, and a prefix test that said it was
       would open a private route by accident. */
    test('does not treat a route that merely starts with the same letters as public', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.unauthenticated(),
          location: '/blogging',
        ),
        startsWith(AppRoutes.login),
      );
    });
  });

  group('returning to where you were going', () {
    test('remembers the destination when it sends a guest to sign in', () {
      final redirect = AuthGuard.redirect(
        state: const AuthState.unauthenticated(),
        location: AppRoutes.customers,
      );

      expect(redirect, contains(AppRoutes.login));
      expect(Uri.parse(redirect!).queryParameters['from'], AppRoutes.customers);
    });

    test('returns the member to it once they have signed in', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.authenticated(_session),
          location: AppRoutes.login,
          queryParameters: <String, String>{'from': AppRoutes.customers},
        ),
        AppRoutes.customers,
      );
    });

    test('falls back to home when nothing was remembered', () {
      expect(
        AuthGuard.redirect(
          state: const AuthState.authenticated(_session),
          location: AppRoutes.login,
        ),
        AppRoutes.conversations,
      );
    });

    /*
      A destination is a path in this app. Anything else is a redirect this app
      would be performing on a stranger's behalf, and that it can only be set
      from inside today is not a reason to allow it tomorrow.
    */
    test('refuses a destination that is not a plain in-app path', () {
      for (final hostile in <String>[
        'https://evil.example',
        '//evil.example',
        'javascript:alert(1)',
        AppRoutes.login,
        '',
      ]) {
        expect(
          AuthGuard.redirect(
            state: const AuthState.authenticated(_session),
            location: AppRoutes.login,
            queryParameters: <String, String>{'from': hostile},
          ),
          AppRoutes.conversations,
          reason: hostile,
        );
      }
    });

    test('survives a destination that was never encoded', () {
      expect(AuthGuard.intendedDestination(const <String, String>{}), isNull);
    });
  });
}
