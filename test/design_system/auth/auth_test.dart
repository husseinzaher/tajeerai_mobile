import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/design_system/auth/auth_header.dart';
import 'package:tajeerai_mobile/design_system/auth/auth_layout.dart';
import 'package:tajeerai_mobile/design_system/auth/brand_logo.dart';
import 'package:tajeerai_mobile/design_system/auth/social_button.dart';

import '../../support/widget_harness.dart';

void main() {
  group('AppBrandLogo', () {
    testWidgets('the full lockup shows the name; the mark alone does not', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(wrapWidget(const Center(child: AppBrandLogo())));
      expect(find.text('Tajeer AI'), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(
          const Center(child: AppBrandLogo(variant: AppBrandLogoVariant.mark)),
        ),
      );
      expect(find.text('Tajeer AI'), findsNothing);
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

    testWidgets('the lockup does not mirror in Arabic', (
      WidgetTester tester,
    ) async {
      // A logo is a fixed graphic. Mirroring would put the name before the
      // mark — a lockup the brand does not have.
      for (final TextDirection direction in TextDirection.values) {
        await tester.pumpWidget(
          wrapWidget(
            KeyedSubtree(
              key: ValueKey<TextDirection>(direction),
              child: const Center(child: AppBrandLogo()),
            ),
            textDirection: direction,
          ),
        );

        final double mark = tester
            .getCenter(find.byIcon(LucideIcons.shoppingBag))
            .dx;
        final double name = tester.getCenter(find.text('Tajeer AI')).dx;
        expect(mark, lessThan(name), reason: direction.name);
      }
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
