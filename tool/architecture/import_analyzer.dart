import 'dart:io';

import 'package:path/path.dart' as p;

/// One import, resolved to something a rule can reason about.
class ResolvedImport {
  const ResolvedImport({
    required this.raw,
    required this.line,
    this.packageName,
    this.projectPath,
  });

  /// The URI exactly as written, for the violation report.
  final String raw;

  /// 1-indexed line number, so the report points at the offending line.
  final int line;

  /// For `package:` imports of a third party, the package name (`dio`).
  /// Null for imports inside this project.
  final String? packageName;

  /// For imports inside this project, the path relative to the package root
  /// (`lib/features/auth/data/...`).
  ///
  /// Relative and `package:TajeerAi/` imports both resolve here, so a
  /// rule cannot be evaded by switching import style -- which is rule 29.
  final String? projectPath;

  bool get isExternalPackage => packageName != null;

  bool get isProjectFile => projectPath != null;

  bool get isDartSdk => raw.startsWith('dart:');
}

/// Extracts and resolves the imports of a Dart file.
///
/// ## Why not the analyzer package
///
/// A full AST parse via `package:analyzer` was the first choice and is what
/// the brief asks for where practical. It is not used here for one concrete
/// reason: resolving a program requires the same analyzer version the project
/// pins, and this project's `riverpod_generator` and `drift_dev` already
/// disagree with `custom_lint` about that -- adding a third consumer would
/// make the guard unrunnable exactly when the dependency tree is in flux, and
/// a guard that cannot run is worse than no guard.
///
/// The compromise is a *directive* parser rather than naive substring
/// matching. Import directives are a small, strictly-specified grammar at the
/// top of a file, and this reads them properly: it strips block and line
/// comments, ignores anything inside string literals, stops at the first
/// non-directive declaration, and resolves relative URIs against the file's
/// own directory. That is enough structure to answer "what does this file
/// depend on" without a resolved element model.
class ImportAnalyzer {
  const ImportAnalyzer({required this.packageRoot, required this.packageName});

  /// Absolute path to the directory holding `pubspec.yaml`.
  final String packageRoot;

  /// This project's package name, so its own `package:` imports resolve to
  /// project paths rather than being treated as third-party.
  final String packageName;

  /// Every import in [file], resolved.
  List<ResolvedImport> analyze(File file) {
    final source = file.readAsStringSync();
    final directives = _extractDirectives(source);

    return directives
        .map((directive) => _resolve(directive, file))
        .toList(growable: false);
  }

  /// Reads `import`/`export` URIs with their line numbers.
  ///
  /// Stops at the first declaration that cannot be a directive, so a string
  /// containing the word `import` inside a function body is never mistaken for
  /// one.
  List<_Directive> _extractDirectives(String source) {
    final directives = <_Directive>[];
    final lines = source.split('\n');

    var inBlockComment = false;

    for (var index = 0; index < lines.length; index++) {
      var line = lines[index];

      if (inBlockComment) {
        final end = line.indexOf('*/');

        if (end == -1) continue;

        inBlockComment = false;
        line = line.substring(end + 2);
      }

      final blockStart = line.indexOf('/*');

      if (blockStart != -1 && !_isInsideString(line, blockStart)) {
        final blockEnd = line.indexOf('*/', blockStart);

        if (blockEnd == -1) {
          inBlockComment = true;
          line = line.substring(0, blockStart);
        } else {
          line = line.substring(0, blockStart) + line.substring(blockEnd + 2);
        }
      }

      final lineComment = line.indexOf('//');

      if (lineComment != -1 && !_isInsideString(line, lineComment)) {
        line = line.substring(0, lineComment);
      }

      final trimmed = line.trim();

      if (trimmed.isEmpty) continue;

      final match = _directivePattern.firstMatch(trimmed);

      if (match != null) {
        directives.add(_Directive(uri: match.group(2)!, line: index + 1));

        continue;
      }

      // Directives may only appear before the first declaration. Once real
      // code starts, nothing further can be an import.
      if (_declarationPattern.hasMatch(trimmed)) break;
    }

    return directives;
  }

  static final RegExp _directivePattern = RegExp(
    '''^(import|export)\\s+['"]([^'"]+)['"]''',
  );

  /// The first token of a declaration that ends the directive section.
  ///
  /// `part` and `part of` are deliberately absent: they may appear among
  /// directives, and a `part` file's imports belong to its parent library.
  static final RegExp _declarationPattern = RegExp(
    r'^(abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
    r'(class|enum|extension|typedef|void\s+main|@)',
  );

  /// Whether [index] falls inside a quoted string on [line].
  ///
  /// Counts unescaped quotes before the position. Enough for directive
  /// scanning, where the only strings present are the URIs themselves.
  static bool _isInsideString(String line, int index) {
    var single = 0;
    var double = 0;

    for (var i = 0; i < index; i++) {
      if (i > 0 && line[i - 1] == r'\') continue;
      if (line[i] == "'") single++;
      if (line[i] == '"') double++;
    }

    return single.isOdd || double.isOdd;
  }

  ResolvedImport _resolve(_Directive directive, File file) {
    final uri = directive.uri;

    if (uri.startsWith('dart:')) {
      return ResolvedImport(raw: uri, line: directive.line);
    }

    if (uri.startsWith('package:')) {
      final withoutScheme = uri.substring('package:'.length);
      final slash = withoutScheme.indexOf('/');

      if (slash == -1) {
        return ResolvedImport(
          raw: uri,
          line: directive.line,
          packageName: withoutScheme,
        );
      }

      final name = withoutScheme.substring(0, slash);

      // This project's own package: imports resolve to project paths, so
      // `package:TajeerAi/features/...` is checked exactly like the
      // equivalent relative import.
      if (name == packageName) {
        return ResolvedImport(
          raw: uri,
          line: directive.line,
          projectPath: 'lib/${withoutScheme.substring(slash + 1)}',
        );
      }

      return ResolvedImport(raw: uri, line: directive.line, packageName: name);
    }

    // Relative: resolve against the importing file's directory.
    final resolved = p.normalize(p.join(p.dirname(file.path), uri));
    final relative = p.relative(resolved, from: packageRoot);

    return ResolvedImport(
      raw: uri,
      line: directive.line,
      projectPath: relative.replaceAll(r'\', '/'),
    );
  }
}

class _Directive {
  const _Directive({required this.uri, required this.line});

  final String uri;
  final int line;
}
