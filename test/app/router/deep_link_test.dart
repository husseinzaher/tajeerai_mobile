import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/router/deep_link.dart';
import 'package:TajeerAi/app/router/routes.dart';

/// What an address from outside the app is allowed to open.
///
/// The interesting half of this is everything it refuses. A deep link is an
/// instruction from a stranger, and the app answers only for its own domain
/// and only for the one thing a stranger is entitled to reach without signing
/// in.
void main() {
  String? resolve(String url) => DeepLink.resolve(Uri.parse(url));

  group('the blog, which anyone may read', () {
    test('opens the index', () {
      expect(resolve('https://tajeerai.com/blog'), AppRoutes.blog);
      expect(resolve('tajeerai://blog'), AppRoutes.blog);
    });

    test('opens an article shared from the website', () {
      expect(
        resolve('https://tajeerai.com/en/blog/how-to-sell-more'),
        AppRoutes.blogArticlePath('how-to-sell-more'),
      );
    });

    /* The site is translated per locale; this app is not translated per link. */
    test('reads past the website locale rather than honouring it', () {
      expect(
        resolve('https://tajeerai.com/ar/blog/how-to-sell-more'),
        resolve('https://tajeerai.com/en/blog/how-to-sell-more'),
      );
    });

    test('opens an Arabic article, decoded', () {
      final String? route = resolve(
        'https://tajeerai.com/ar/blog/${Uri.encodeComponent('ربط-المتجر-بواتساب')}',
      );

      expect(route, AppRoutes.blogArticlePath('ربط-المتجر-بواتساب'));
    });

    /* A custom-scheme URL puts its first segment in the host, which is the one
       genuinely confusing thing about custom schemes. */
    test('opens an article over the app’s own scheme', () {
      expect(
        resolve('tajeerai://blog/how-to-sell-more'),
        AppRoutes.blogArticlePath('how-to-sell-more'),
      );
    });

    test('accepts the www host as the same site', () {
      expect(resolve('https://www.tajeerai.com/blog'), AppRoutes.blog);
    });

    test('treats a trailing slash as the index', () {
      expect(resolve('https://tajeerai.com/blog/'), AppRoutes.blog);
    });
  });

  group('what it refuses', () {
    /* The one that matters: otherwise any page anywhere could send a reader
       wherever it liked inside this app. */
    test('an address on somebody else’s domain', () {
      expect(resolve('https://evil.example/blog/anything'), isNull);
      expect(resolve('https://tajeerai.com.evil.example/blog/x'), isNull);
    });

    test('an unencrypted link, even to our own site', () {
      expect(resolve('http://tajeerai.com/blog/x'), isNull);
    });

    /* Everything else in this app is behind a session, and the guard would
       bounce it anyway - so it opens nothing rather than flashing a screen. */
    test('anywhere in the app that is not the blog', () {
      expect(resolve('https://tajeerai.com/dashboard'), isNull);
      expect(resolve('tajeerai://conversations/thread/c1'), isNull);
      expect(resolve('https://tajeerai.com/ar/pricing'), isNull);
    });

    test('the social sign-in callback, which is not a route at all', () {
      expect(resolve('tajeerai://auth/callback?code=abc'), isNull);
    });

    test('a scheme this app has never heard of', () {
      expect(resolve('javascript:alert(1)'), isNull);
      expect(resolve('file:///etc/passwd'), isNull);
    });

    test('an empty or malformed address', () {
      expect(resolve(''), isNull);
      expect(resolve('https://tajeerai.com'), isNull);
      expect(resolve('tajeerai://'), isNull);
    });
  });
}
