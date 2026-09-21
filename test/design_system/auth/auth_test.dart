import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/design_system/auth/auth_header.dart';
import 'package:TajeerAi/design_system/auth/auth_layout.dart';
import 'package:TajeerAi/design_system/auth/brand_logo.dart';
import 'package:TajeerAi/design_system/auth/social_button.dart';
import 'package:TajeerAi/design_system/auth/social_provider_mark.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppBrandLogo', () {
    String? assetOf(Image image) {
      ImageProvider<Object> provider = image.image;
      if (provider is ResizeImage) {
        provider = provider.imageProvider;
      }
      return provider is AssetImage ? provider.assetName : null;
    }

    test('the vertical logo follows the language and the canvas', () {
      String vertical(Brightness brightness, String languageCode) =>
          AppBrandLogo.assetFor(
            AppBrandLogoVariant.vertical,
            brightness: brightness,
            languageCode: languageCode,
          );

      expect(vertical(Brightness.light, 'en'), AppBrandLogo.verticalEnLight);
      expect(vertical(Brightness.dark, 'en'), AppBrandLogo.verticalEnDark);
      expect(vertical(Brightness.light, 'ar'), AppBrandLogo.verticalArLight);
      expect(vertical(Brightness.dark, 'ar'), AppBrandLogo.verticalArDark);
      // A language the brand has no wordmark for reads the Latin one.
      expect(vertical(Brightness.dark, 'fr'), AppBrandLogo.verticalEnDark);
    });

    test('the mark and the horizontal logo read on either canvas', () {
      for (final Brightness brightness in Brightness.values) {
        for (final String languageCode in <String>['en', 'ar']) {
          expect(
            AppBrandLogo.assetFor(
              AppBrandLogoVariant.mark,
              brightness: brightness,
              languageCode: languageCode,
            ),
            AppBrandLogo.markAsset,
          );
          expect(
            AppBrandLogo.assetFor(
              AppBrandLogoVariant.horizontal,
              brightness: brightness,
              languageCode: languageCode,
            ),
            AppBrandLogo.horizontalAsset,
          );
        }
      }
    });

    test('every file it can choose exists', () {
      // A path that resolves in code and not on disk draws nothing, silently.
      for (final String path in AppBrandLogo.assets) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    testWidgets('draws the file for the screen it is on', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(child: AppBrandLogo()),
          brightness: Brightness.dark,
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );

      expect(
        assetOf(tester.widget<Image>(find.byType(Image))),
        AppBrandLogo.verticalArDark,
      );
    });

    testWidgets('is one image to a screen reader, named for the product', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const Center(child: AppBrandLogo())));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Tajeer AI')),
        isSemantics(label: 'Tajeer AI', isImage: true),
      );
    });

    testWidgets('never mirrors in Arabic', (WidgetTester tester) async {
      // A logo is a fixed graphic, not a sentence.
      await tester.pumpWidget(
        wrapWidget(
          const Center(child: AppBrandLogo()),
          locale: const Locale('ar'),
          textDirection: TextDirection.rtl,
        ),
      );
      expect(
        tester.widget<Image>(find.byType(Image)).matchTextDirection,
        isFalse,
      );
    });

    testWidgets('draws at the height it is given', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppBrandLogo(
              variant: AppBrandLogoVariant.horizontal,
              height: 40,
            ),
          ),
        ),
      );
      expect(tester.widget<Image>(find.byType(Image)).height, 40);
    });
  });

  group('AppAuthHeader', () {
    testWidgets('announces its title as a heading', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppAuthHeader(
            title: 'مرحباً بعودتك',
            description: 'سجّل الدخول',
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('مرحباً بعودتك')),
        isSemantics(isHeader: true),
      );
      expect(find.text('سجّل الدخول'), findsOneWidget);
    });

    testWidgets('the description is optional', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapWidget(const AppAuthHeader(title: 'مرحباً بعودتك')),
      );
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('AppAuthLayout', () {
    testWidgets('stacks logo, header, form and footer in that order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppAuthLayout(
            logo: Text('logo'),
            header: Text('header'),
            footer: Text('footer'),
            child: Text('form'),
          ),
        ),
      );

      final List<double> ys = <String>[
        'logo',
        'header',
        'form',
        'footer',
      ].map((String label) => tester.getCenter(find.text(label)).dy).toList();
      for (int i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]), reason: 'section $i');
      }
    });

    testWidgets('caps the form width on a wide screen', (
      WidgetTester tester,
    ) async {
      // A form the full width of a tablet is a strip of text nobody can use.
      const Key form = Key('form');
      await tester.pumpWidget(
        wrapWidget(const AppAuthLayout(child: SizedBox(key: form, height: 10))),
      );

      expect(tester.getSize(find.byKey(form)).width, 400);
    });

    testWidgets(
      'puts the corner control at the end, which is the left in Arabic',
      (WidgetTester tester) async {
        for (final TextDirection direction in TextDirection.values) {
          await tester.pumpWidget(
            wrapWidget(
              KeyedSubtree(
                key: ValueKey<TextDirection>(direction),
                child: const AppAuthLayout(
                  topEnd: Text('EN'),
                  child: SizedBox(),
                ),
              ),
              textDirection: direction,
            ),
          );

          final double x = tester.getCenter(find.text('EN')).dx;
          final double middle =
              tester.getSize(find.byType(AppAuthLayout)).width / 2;

          if (direction == TextDirection.ltr) {
            expect(x, greaterThan(middle), reason: 'ltr end = right');
          } else {
            expect(x, lessThan(middle), reason: 'rtl end = left');
          }
        }
      },
    );

    testWidgets('holds each corner control on its own side', (
      WidgetTester tester,
    ) async {
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<TextDirection>(direction),
              child: const AppAuthLayout(
                topStart: Text('ST'),
                topEnd: Text('EN'),
                child: SizedBox(),
              ),
            ),
            textDirection: direction,
          ),
        );

        final double start = tester.getCenter(find.text('ST')).dx;
        final double end = tester.getCenter(find.text('EN')).dx;

        // They share a row, and which side each takes follows the reading
        // direction rather than the order they were passed in.
        expect(
          tester.getCenter(find.text('ST')).dy,
          tester.getCenter(find.text('EN')).dy,
        );
        if (direction == TextDirection.ltr) {
          expect(start, lessThan(end), reason: 'ltr start = left');
        } else {
          expect(start, greaterThan(end), reason: 'rtl start = right');
        }
      }
    });

    testWidgets('keeps the end corner in place when the start one is absent', (
      WidgetTester tester,
    ) async {
      // A spacer holds the missing corner open. Without it the one control
      // present slides across to the other side, which is worse than a gap.
      await tester.pumpWidget(
        wrapWidget(const AppAuthLayout(topEnd: Text('EN'), child: SizedBox())),
      );

      expect(
        tester.getCenter(find.text('EN')).dx,
        greaterThan(tester.getSize(find.byType(AppAuthLayout)).width / 2),
      );
    });

    testWidgets('scrolls rather than overflows when there is no room', (
      WidgetTester tester,
    ) async {
      // A short phone with the keyboard up. The Sign in button has to stay
      // reachable, which means scrolling, not a RenderFlex overflow.
      tester.view
        ..physicalSize = const Size(390, 300)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrapWidget(
          const AppAuthLayout(
            logo: SizedBox(height: 120),
            header: SizedBox(height: 120),
            child: SizedBox(height: 400),
          ),
          size: const Size(390, 300),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });

  group('AppSocialProviderMark', () {
    testWidgets('draws the official marks for Google and Facebook', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Row(
            children: <Widget>[
              AppSocialProviderMark('google'),
              AppSocialProviderMark('facebook'),
            ],
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsNWidgets(2));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('falls back to an initial for an unknown provider', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const AppSocialProviderMark('apple')));

      expect(find.text('A'), findsOneWidget);
    });
  });

  group('AppSocialButton', () {
    Widget subject({VoidCallback? onPressed}) => wrapWidget(
      Center(
        child: SizedBox(
          width: 120,
          child: AppSocialButton(
            glyph: const Icon(LucideIcons.globe),
            label: 'Continue with Google',
            onPressed: onPressed,
          ),
        ),
      ),
    );

    testWidgets('is a named button, never an anonymous glyph', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject(onPressed: () {}));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Continue with Google')),
        isSemantics(isButton: true, isEnabled: true),
      );
    });

    testWidgets('reports a tap, and is a 52px target', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(subject(onPressed: () => taps++));

      await tester.tap(find.byType(AppSocialButton));
      expect(taps, 1);
      expect(
        tester.getSize(find.byType(AppSocialButton)).height,
        greaterThanOrEqualTo(52),
      );
    });

    testWidgets('without a handler it is disabled, and says so', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      expect(
        tester.getSemantics(find.bySemanticsLabel('Continue with Google')),
        isSemantics(isButton: true, isEnabled: false),
      );
    });
  });
}
