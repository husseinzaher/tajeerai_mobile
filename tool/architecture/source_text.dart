const int _newline = 0x0A;
const int _openParen = 0x28;
const int _closeParen = 0x29;

/// Source text with everything that is not code blanked out.
///
/// RULES 34 and 35 read what a file *does* rather than what it imports, and a
/// doc comment explaining why a screen must never build a raw `Checkbox(` must
/// not be the thing that trips them. So comments, and the contents of string
/// literals, are replaced with spaces. Newlines are kept, which leaves every
/// offset and every line number where it was: a match found in the blanked
/// text points at the right line of the real one.
///
/// Code inside an interpolation (`'${Colors.red}'`) is kept, because it is
/// code. The quotes themselves are kept too, so an empty string still reads as
/// one.
abstract final class SourceText {
  /// [source] with comments and string contents replaced by spaces.
  static String codeOnly(String source) {
    final StringBuffer out = StringBuffer();
    final List<_Frame> open = <_Frame>[];
    final int length = source.length;
    int i = 0;

    void keep(int count) {
      final int end = i + count > length ? length : i + count;
      out.write(source.substring(i, end));
      i = end;
    }

    void blank(int count) {
      final int end = i + count > length ? length : i + count;
      for (; i < end; i++) {
        out.write(source.codeUnitAt(i) == _newline ? '\n' : ' ');
      }
    }

    while (i < length) {
      final _Frame? frame = open.isEmpty ? null : open.last;

      if (frame is _StringFrame) {
        if (!frame.raw && source.startsWith(r'\', i)) {
          blank(2);
        } else if (source.startsWith(frame.closing, i)) {
          open.removeLast();
          keep(frame.closing.length);
        } else if (!frame.raw && source.startsWith(r'${', i)) {
          open.add(_InterpolationFrame());
          keep(2);
        } else {
          blank(1);
        }
        continue;
      }

      if (source.startsWith('//', i)) {
        while (i < length && source.codeUnitAt(i) != _newline) {
          blank(1);
        }
        continue;
      }

      if (source.startsWith('/*', i)) {
        // Block comments nest in Dart, so the first `*/` is not always the end.
        int depth = 0;
        while (i < length) {
          if (source.startsWith('/*', i)) {
            depth++;
            blank(2);
          } else if (source.startsWith('*/', i)) {
            depth--;
            blank(2);
            if (depth == 0) break;
          } else {
            blank(1);
          }
        }
        continue;
      }

      final String char = source[i];

      if (char == "'" || char == '"') {
        final String triple = char * 3;
        final String closing = source.startsWith(triple, i) ? triple : char;
        open.add(_StringFrame(closing: closing, raw: _isRawPrefix(source, i)));
        keep(closing.length);
        continue;
      }

      if (frame is _InterpolationFrame) {
        if (char == '{') {
          frame.depth++;
        } else if (char == '}') {
          if (frame.depth == 0) {
            open.removeLast();
          } else {
            frame.depth--;
          }
        }
      }

      keep(1);
    }

    return out.toString();
  }

  /// The 1-based line that [offset] falls on.
  static int lineOf(String source, int offset) {
    int line = 1;
    for (int i = 0; i < offset && i < source.length; i++) {
      if (source.codeUnitAt(i) == _newline) line++;
    }
    return line;
  }

  /// The text between the parenthesis at [open] and the one that closes it.
  ///
  /// Meant for [codeOnly] output, where a parenthesis inside a string or a
  /// comment has already been blanked and cannot unbalance the count.
  static String argumentsAt(String code, int open) {
    int depth = 0;
    for (int i = open; i < code.length; i++) {
      final int unit = code.codeUnitAt(i);
      if (unit == _openParen) {
        depth++;
      } else if (unit == _closeParen) {
        depth--;
        if (depth == 0) return code.substring(open + 1, i);
      }
    }
    return code.substring(open + 1);
  }

  /// Whether the quote at [quote] opens a raw string: `r'…'`, where the `r`
  /// is a prefix rather than the end of an identifier.
  static bool _isRawPrefix(String source, int quote) {
    if (quote == 0 || source[quote - 1] != 'r') return false;
    if (quote == 1) return true;
    return !RegExp(r'[\w$]').hasMatch(source[quote - 2]);
  }
}

sealed class _Frame {}

/// An open string literal, and what closes it.
final class _StringFrame extends _Frame {
  _StringFrame({required this.closing, required this.raw});

  final String closing;

  /// A raw string has no escapes and no interpolation.
  final bool raw;
}

/// Code inside `${…}`, counting its own braces so a map literal in an
/// interpolation does not close it early.
final class _InterpolationFrame extends _Frame {
  int depth = 0;
}
