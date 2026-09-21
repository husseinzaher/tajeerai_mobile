import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/design_system/design_system.dart';

import '../../support/widget_harness.dart';

/// The three states a picture from the network is in.
///
/// Asserted here rather than photographed in the showcase: the golden harness
/// refuses any test that reaches the network, so "loaded" and "failed" can
/// only be reached in a test that expects the request to fail - which is
/// exactly what `flutter_test` makes every request do.
void main() {
  testWidgets('reserves the shape before anything has arrived', (tester) async {
    await tester.pumpWidget(
      wrapWidget(const AppNetworkImage(url: null, aspectRatio: 16 / 9)),
    );

    final AspectRatio box = tester.widget(find.byType(AspectRatio));

    expect(box.aspectRatio, 16 / 9);
    /* A shape with nothing in it yet is a skeleton, not a spinner: it stands
       in for the picture rather than announcing a wait. */
    expect(find.byType(AppSkeleton), findsOneWidget);
  });

  testWidgets('waits the same way for an address that is simply empty', (
    tester,
  ) async {
    await tester.pumpWidget(wrapWidget(const AppNetworkImage(url: '')));

    expect(find.byType(AppSkeleton), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  /*
    Every request fails under `flutter_test`, which is what makes this
    assertable at all: the frame that renders is the error frame.
  */
  testWidgets('shows a muted frame rather than a broken-image glyph', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWidget(
        const AppNetworkImage(
          url: 'https://example.invalid/missing.png',
          aspectRatio: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
  });

  testWidgets('sizes itself when it is given no ratio to keep', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const SizedBox(
          width: 120,
          height: 60,
          child: AppNetworkImage(url: null),
        ),
      ),
    );

    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('carries a description for a reader who cannot see it', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWidget(
        const AppNetworkImage(
          url: 'https://example.invalid/x.png',
          semanticLabel: 'A shop front',
          aspectRatio: 1,
        ),
      ),
    );

    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      'A shop front',
    );
  });
}
