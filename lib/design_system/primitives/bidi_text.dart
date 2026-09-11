import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show Bidi;

/// The direction a piece of writing reads in, from its own words.
abstract final class AppBidi {
  static TextDirection directionOf(String text) =>
      Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;
}

/// Text somebody else wrote, read in its own direction.
///
/// A customer writes in whatever language they write in. Laid out in the app's
/// direction, an English question in an Arabic Inbox reads "?before it ships":
/// the punctuation takes the paragraph's side. This keeps the text's own
/// direction, found from its words.
///
/// Where it lines up is a separate choice. In a list row every line starts at
/// the row's start edge, whatever language it is in — [alignToAmbient]. In a
/// message bubble a line starts where its own language starts.
class AppBidiText extends StatelessWidget {
  const AppBidiText(
    this.text, {
    this.style,
    this.maxLines,
    this.overflow,
    this.alignToAmbient = false,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Line up with the surrounding layout's start edge rather than the text's.
  final bool alignToAmbient;

  /// Overrides both, for text that is centred.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final TextAlign align =
        textAlign ??
        (alignToAmbient
            ? (Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left)
            : TextAlign.start);

    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: AppBidi.directionOf(text),
      textAlign: align,
    );
  }
}
