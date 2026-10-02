import '../architecture_rule.dart';
import '../import_analyzer.dart';

/// The one HTTP client.
const String _httpClient = 'lib/infrastructure/api/http_client.dart';

/// The HTTP stack's own packages. A file that names one of these has built a
/// transport of its own.
const Set<String> _httpPackages = <String>{
  'dio',
  'dio_cookie_manager',
  'cookie_jar',
};

/// An adapter's remote data sources: the one place a feature's endpoints are
/// written down.
final RegExp _remoteDataSource = RegExp(
  r'^lib/infrastructure/adapters/[^/]+/remote/',
);

/// RULE 36 — HTTP is reached only from where its policy can be reviewed.
///
/// The socket carries this application's business data. HTTP exists for the
/// sign-in exchange, files, and the workspace data the socket does not expose
/// (`ARCHITECTURE.md` §11). A decision like that needs a place where it cannot
/// be widened by accident. So:
///
/// - `HttpClient` is imported only by an adapter's `remote/` sources, where
///   every call is a named endpoint a reviewer can hold against §11, by the
///   HTTP layer itself, and by the composition root that builds it;
/// - nothing outside `infrastructure/api/` names Dio or a cookie jar.
///
/// What it cannot see is *which* endpoint a data source calls. Whether a new
/// remote call is one §11 allows stays a review question; this rule makes sure
/// every such call sits where that review will look.
class HttpTransportRule implements ArchitectureRule {
  const HttpTransportRule();

  @override
  String get id => 'RULE 36';

  @override
  String get description =>
      'HTTP is reached only from an adapter remote/ source, the HTTP layer '
      'and the composition root.';

  @override
  List<Violation> check(ArchitectureContext context) {
    final String path = context.file.path;

    if (path.startsWith('lib/infrastructure/api/')) {
      return const <Violation>[];
    }

    final bool mayUseClient =
        path.startsWith('lib/app/bootstrap/') ||
        _remoteDataSource.hasMatch(path);

    final List<Violation> violations = <Violation>[];

    for (final ResolvedImport import in context.imports) {
      final String? package = import.packageName;

      if (package != null && _httpPackages.contains(package)) {
        violations.add(
          Violation(
            rule: '$id - $description',
            source: path,
            forbiddenDependency: import.raw,
            line: import.line,
            reason:
                'Only the HTTP layer knows which HTTP library this app uses. '
                'A file that builds its own Dio, or reads a cookie jar, is a '
                'second transport nobody reviews.',
            allowedAlternative:
                'Call HttpClient from an adapter remote/ source; if it lacks '
                'something, add it to lib/infrastructure/api/.',
          ),
        );

        continue;
      }

      if (import.projectPath == _httpClient && !mayUseClient) {
        violations.add(
          Violation(
            rule: '$id - $description',
            source: path,
            forbiddenDependency: import.raw,
            line: import.line,
            reason:
                'HTTP carries only what ARCHITECTURE.md §11 allows, and a call '
                'made outside an adapter remote/ source is one the review of '
                'that policy never sees.',
            allowedAlternative:
                "Put the call in the feature's adapter under "
                'infrastructure/adapters/<feature>/remote/, behind its '
                'repository.',
          ),
        );
      }
    }

    return violations;
  }
}
