// The fixtures below are Dart source containing single-quoted import
// directives, so they are written with double quotes.
// ignore_for_file: prefer_single_quotes

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/architecture/import_analyzer.dart';

void main() {
  late Directory root;
  late ImportAnalyzer analyzer;

  setUp(() {
    root = Directory.systemTemp.createTempSync('arch_analyzer_test');

    analyzer = ImportAnalyzer(
      packageRoot: root.path,
      packageName: 'tajeerai_mobile',
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  /// Writes [source] to `lib/features/auth/domain/subject.dart` and analyses it.
  List<ResolvedImport> analyze(String source) {
    final file = File('${root.path}/lib/features/auth/domain/subject.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);

    return analyzer.analyze(file);
  }

  group('resolution', () {
    test('classifies a third-party package import', () {
      final imports = analyze("import 'package:dio/dio.dart';\n");

      expect(imports.single.packageName, 'dio');
      expect(imports.single.isExternalPackage, isTrue);
      expect(imports.single.isProjectFile, isFalse);
    });

    test('resolves this project\'s own package imports to project paths', () {
      // Rule 29: a boundary must not be evadable by switching import style.
      final imports = analyze(
        "import 'package:tajeerai_mobile/features/auth/data/x.dart';\n",
      );

      expect(imports.single.packageName, isNull);
      expect(imports.single.projectPath, 'lib/features/auth/data/x.dart');
    });

    test('resolves a relative import against the importing file', () {
      final imports = analyze("import '../data/repositories/impl.dart';\n");

      expect(
        imports.single.projectPath,
        'lib/features/auth/data/repositories/impl.dart',
      );
    });

    test('resolves a deeply relative import', () {
      // The fixture lives at lib/features/auth/domain/, so three levels reach
      // lib/ -- the same shape as a real domain file reaching the failure
      // taxonomy.
      final imports = analyze(
        "import '../../../infrastructure/logging/logger.dart';\n",
      );

      expect(
        imports.single.projectPath,
        'lib/infrastructure/logging/logger.dart',
      );
    });

    test('recognises dart: libraries', () {
      final imports = analyze("import 'dart:async';\n");

      expect(imports.single.isDartSdk, isTrue);
      expect(imports.single.isProjectFile, isFalse);
    });

    test('reads exports as well as imports', () {
      final imports = analyze("export 'package:dio/dio.dart';\n");

      expect(imports.single.packageName, 'dio');
    });

    test('records line numbers so a report is navigable', () {
      final imports = analyze(
        "import 'dart:async';\n"
        "\n"
        "import 'package:dio/dio.dart';\n",
      );

      expect(imports[0].line, 1);
      expect(imports[1].line, 3);
    });
  });

  group('parsing robustness', () {
    test('ignores an import inside a line comment', () {
      final imports = analyze(
        "// import 'package:dio/dio.dart';\n"
        "import 'dart:async';\n",
      );

      expect(imports, hasLength(1));
      expect(imports.single.raw, 'dart:async');
    });

    test('ignores imports inside a block comment', () {
      final imports = analyze(
        "/*\n"
        "import 'package:dio/dio.dart';\n"
        "*/\n"
        "import 'dart:async';\n",
      );

      expect(imports, hasLength(1));
      expect(imports.single.raw, 'dart:async');
    });

    test('handles a single-line block comment', () {
      final imports = analyze("/* a note */ import 'dart:async';\n");

      expect(imports, hasLength(1));
    });

    test('ignores the word import inside code', () {
      // Naive substring matching would report this as a dependency.
      final imports = analyze(
        "import 'dart:async';\n"
        "\n"
        "class Thing {\n"
        "  final String note = \"import 'package:dio/dio.dart';\";\n"
        "}\n",
      );

      expect(imports, hasLength(1));
      expect(imports.single.raw, 'dart:async');
    });

    test('stops at the first declaration', () {
      final imports = analyze(
        "import 'dart:async';\n"
        "\n"
        "class Thing {}\n"
        "\n"
        "// a stray directive below real code is not a directive\n"
        "import 'package:dio/dio.dart';\n",
      );

      expect(imports, hasLength(1));
    });

    test('reads directives past a part statement', () {
      // `part` may sit among directives; it must not end the scan.
      final imports = analyze(
        "import 'dart:async';\n"
        "\n"
        "part 'subject.g.dart';\n"
        "\n"
        "import 'package:dio/dio.dart';\n",
      );

      expect(imports, hasLength(2));
    });

    test('handles double-quoted URIs', () {
      final imports = analyze('import "dart:async";\n');

      expect(imports.single.raw, 'dart:async');
    });

    test('handles an import with a show clause', () {
      final imports = analyze(
        "import 'package:drift/drift.dart' show Value;\n",
      );

      expect(imports.single.packageName, 'drift');
    });

    test('handles an aliased import', () {
      final imports = analyze("import 'package:path/path.dart' as p;\n");

      expect(imports.single.packageName, 'path');
    });

    test('returns nothing for a file with no imports', () {
      expect(analyze('class Thing {}\n'), isEmpty);
    });

    test('handles an empty file', () {
      expect(analyze(''), isEmpty);
    });

    test('skips a licence header before the directives', () {
      final imports = analyze(
        '// Copyright notice.\n'
        '//\n'
        '// More notice.\n'
        "\n"
        "import 'dart:async';\n",
      );

      expect(imports, hasLength(1));
    });

    test('handles a package import with no path segment', () {
      final imports = analyze("import 'package:collection';\n");

      expect(imports.single.packageName, 'collection');
    });
  });
}
