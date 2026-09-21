import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../../app/theme/theme.dart';

/// Formatted prose, as an article was written.
///
/// The backend stores article bodies twice: as plain paragraphs, and as HTML
/// carrying the writer's structure - a sub-heading where a section turns, a
/// list where it enumerates, `<strong>` on the sentence that carries the
/// point, and links to other articles. Rendering only the paragraphs threw all
/// of that away and made every article a wall of text.
///
/// ## What it is allowed to contain
///
/// Exactly what the backend's sanitiser permits, and nothing else - the HTML
/// stored in the database has already been through an allowlist on the way in,
/// so this renders a known, small vocabulary rather than the web:
///
/// ```text
/// p br strong em u s code pre blockquote ul ol li h2 h3 h4 a hr
/// table thead tbody tr th td
/// ```
///
/// ## Why links are a callback
///
/// A design-system component may not import a router (RULE 33), and this one
/// has no idea whether `/blog/x` is a screen in this app or a page on a
/// website. So it reports a tap and lets the caller decide, which is the same
/// arrangement every other component here uses for anything it cannot answer
/// itself.
class AppRichTextView extends StatelessWidget {
  const AppRichTextView({required this.html, this.onLinkTap, super.key});

  /// Sanitised HTML. Empty renders nothing at all, not an empty box.
  final String html;

  /// A link was tapped. The `href` exactly as the document carried it, which
  /// for an internal one is a path like `/blog/how-to-sell`.
  final void Function(String href)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) return const SizedBox.shrink();

    final TajeerColors colors = context.colors;

    return HtmlWidget(
      html,
      textStyle: context.text.bodyMedium,
      onTapUrl: (String url) {
        final void Function(String href)? handler = onLinkTap;

        if (handler == null) return false;

        handler(url);

        /* True means "handled": the package must not try to open it itself. */
        return true;
      },
      /*
        Styling by tag rather than by a stylesheet, because every value has to
        come from a token (RULE 34) and a CSS string would smuggle raw numbers
        and colours past that. Only the tags the sanitiser allows appear here;
        anything else cannot reach this widget.
      */
      customStylesBuilder: (element) => switch (element.localName) {
        'h2' => <String, String>{
          'font-size': '${context.text.titleLarge?.fontSize ?? 20}px',
          'font-weight': '700',
          'margin': '16px 0 8px 0',
        },
        'h3' => <String, String>{
          'font-size': '${context.text.titleMedium?.fontSize ?? 18}px',
          'font-weight': '700',
          'margin': '12px 0 6px 0',
        },
        'h4' => <String, String>{
          'font-size': '${context.text.titleSmall?.fontSize ?? 16}px',
          'font-weight': '600',
          'margin': '12px 0 4px 0',
        },
        'a' => <String, String>{
          'color': _hex(colors.primary),
          'text-decoration': 'underline',
        },
        /* A quotation reads as one when it is set apart, not when it is
           italicised - Arabic has no italic form worth the name. */
        'blockquote' => <String, String>{
          'margin': '12px 0',
          'padding': '8px 12px',
          'color': _hex(colors.textMuted),
        },
        'code' || 'pre' => <String, String>{
          'font-family': 'monospace',
          'color': _hex(colors.textPrimary),
        },
        'p' => <String, String>{'margin': '0 0 12px 0'},
        'ul' || 'ol' => <String, String>{'margin': '0 0 12px 0'},
        'table' => <String, String>{'margin': '0 0 12px 0'},
        'th' => <String, String>{
          'font-weight': '700',
          'text-align': 'start',
          'padding': '6px 8px',
        },
        'td' => <String, String>{'padding': '6px 8px'},
        _ => null,
      },
      /*
        Direction is inherited from the screen, and the document overrides it
        per element where it says so: the backend keeps `dir` on paragraphs and
        headings precisely so an English quote inside an Arabic article reads
        correctly.
      */
      renderMode: RenderMode.column,
    );
  }

  /// A colour as CSS sees it. The values are tokens; only the notation is CSS.
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
