import 'package:flutter_test/flutter_test.dart';

import '../../tool/architecture/source_text.dart';

List<int> _newlines(String text) => <int>[
  for (int i = 0; i < text.length; i++)
    if (text[i] == '\n') i,
];

void main() {
  group('SourceText.codeOnly', () {
    test('keeps the length and every newline, so lines still line up', () {
      const String source =
          "final a = 'Card(';\n"
          '// Colors.red\n'
          '/* Divider(\n */\n'
          'final b = 1;\n';

      final String code = SourceText.codeOnly(source);

      expect(code.length, source.length);
      expect(_newlines(code), _newlines(source));
      expect(code, contains('final b = 1;'));
    });

    test('blanks line comments and doc comments', () {
      final String code = SourceText.codeOnly(
        '/// Never build a Card( here.\n'
        'final x = 1; // Colors.red\n',
      );

      expect(code, isNot(contains('Card')));
      expect(code, isNot(contains('Colors')));
      expect(code, contains('final x = 1;'));
    });

    test('blanks a nested block comment to its real end', () {
      final String code = SourceText.codeOnly(
        '/* outer /* inner */ Card( */ Divider();',
      );

      expect(code, isNot(contains('Card')));
      expect(code, contains('Divider();'));
    });

    test('blanks what a string says, in every quoting style', () {
      final String code = SourceText.codeOnly(
        <String>[
          r"a('Colors.red');",
          r'b("Card(");',
          "c('''\nTextField(\n''');",
          r"d(r'Color(0x\');",
          r"e('it\'s a Switch(');",
        ].join('\n'),
      );

      for (final String word in <String>[
        'Colors',
        'Card',
        'TextField',
        'Color',
        'Switch',
      ]) {
        expect(code, isNot(contains(word)), reason: word);
      }
      for (final String call in <String>['a(', 'b(', 'c(', 'd(', 'e(']) {
        expect(code, contains(call), reason: call);
      }
    });

    test('keeps the code inside an interpolation', () {
      final String code = SourceText.codeOnly(
        r"x('Card ${Colors.red} Chip(');",
      );

      expect(code, contains('Colors.red'));
      expect(code, isNot(contains('Card')));
      expect(code, isNot(contains('Chip')));
    });

    test('an interpolation holding braces and a string of its own closes', () {
      final String code = SourceText.codeOnly(
        r"x('${{'a': 1}['a']} Card('); Divider();",
      );

      expect(code, isNot(contains('Card')));
      expect(code, contains('Divider();'));
    });
  });

  test('lineOf counts from one', () {
    const String text = 'a\nb\nc';

    expect(SourceText.lineOf(text, 0), 1);
    expect(SourceText.lineOf(text, 2), 2);
    expect(SourceText.lineOf(text, 4), 3);
  });

  test('argumentsAt reads to the parenthesis that closes', () {
    const String code = 'EdgeInsets.only(top: max(a, b), bottom: 8) + x';

    expect(
      SourceText.argumentsAt(code, code.indexOf('(')),
      'top: max(a, b), bottom: 8',
    );
  });
}
