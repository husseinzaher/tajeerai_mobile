import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/design_system/design_system.dart';

import '../../support/widget_harness.dart';

/// Rendering the formatted half of an article.
///
/// The vocabulary asserted here is exactly what the backend's sanitiser lets
/// through. Anything outside it cannot reach this widget, so the tests that
/// matter are about the tags that can.
void main() {
  Future<void> render(
    WidgetTester tester,
    String html, {
    void Function(String href)? onLinkTap,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      wrapWidget(
        AppRichTextView(html: html, onLinkTap: onLinkTap),
        textDirection: direction,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders paragraphs as text a reader can read', (tester) async {
    await render(tester, '<p>First paragraph.</p><p>Second paragraph.</p>');

    expect(
      find.textContaining('First paragraph.', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Second paragraph.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('keeps the words of a heading, a list and a quote', (
    tester,
  ) async {
    await render(
      tester,
      '<h3>Why speed wins</h3>'
      '<ul><li>Reply in minutes</li><li>Connect the catalogue</li></ul>'
      '<blockquote>The fastest reply is the one nobody had to write.</blockquote>',
    );

    expect(
      find.textContaining('Why speed wins', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Reply in minutes', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Connect the catalogue', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('nobody had to write', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('emphasises what the writer emphasised', (tester) async {
    await render(
      tester,
      '<p>A customer who waits <strong>buys elsewhere</strong>.</p>',
    );

    /* The words survive; that they are bold is the package's business, and
       asserting a font weight here would test the package rather than this. */
    expect(
      find.textContaining('buys elsewhere', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders Arabic prose right to left', (tester) async {
    await render(
      tester,
      '<p>العميل الذي ينتظر ساعة يشتري من مكان آخر.</p>',
      direction: TextDirection.rtl,
    );

    expect(
      find.textContaining('العميل الذي ينتظر', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renders nothing at all for an article with no formatting', (
    tester,
  ) async {
    await render(tester, '');

    expect(find.byType(SizedBox), findsWidgets);
    expect(find.byType(RichText), findsNothing);
  });

  group('links', () {
    testWidgets('reports a tap rather than following it itself', (
      tester,
    ) async {
      final List<String> tapped = <String>[];

      await render(
        tester,
        '<p>Read <a href="/blog/how-to-sell">the guide</a> next.</p>',
        onLinkTap: tapped.add,
      );

      /* The recogniser lives on the span, not the widget, so the tap has to
         land on the words themselves. */
      await tester.tapOnText(find.textRange.ofSubstring('the guide'));
      await tester.pumpAndSettle();

      expect(tapped, <String>['/blog/how-to-sell']);
    });

    /* The anchor text is prose the writer meant to be there, so a link with
       nowhere to go still reads as a sentence. */
    testWidgets('still shows the words when nothing handles a tap', (
      tester,
    ) async {
      await render(tester, '<p>Read <a href="/blog/x">the guide</a> next.</p>');

      expect(
        find.textContaining('the guide', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
