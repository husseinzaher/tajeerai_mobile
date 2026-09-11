import '../architecture_rule.dart';
import '../import_analyzer.dart';

/// The one HTTP client.
const String _httpClient = 'lib/infrastructure/network/http_client.dart';

/// The HTTP stack's own packages. A file that names one of these has built a
/// transport of its own.
const Set<String> _httpPackages = <String>{
  'dio',
  'dio_cookie_manager',
  'cookie_jar',
};

final RegExp _remoteDataSource = RegExp(r'^lib/features/[^/]+/data/remote/');

/// RULE 36 — HTTP is reached only from where its policy can be reviewed.
///
/// The socket carries this application's business data. HTTP exists for the
/// sign-in exchange, files, and the workspace data the socket does not expose
/// (`ARCHITECTURE.md` §11). A decision like that needs a place where it cannot
/// be widened by accident. So:
///
/// - `HttpClient` is imported only by a feature's `data/remote/` sources,
///   where every call is a named endpoint a reviewer can hold against §11, by
///   the network layer itself, and by the composition root that builds it;
/// - nothing outside `infrastructure/network/` names Dio or a cookie jar.
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
      'HTTP is reached only from a feature data/remote/ source, the network '
      'layer and the composition root.';

  @override
  List<Violation> check(ArchitectureContext context) {
    final String path = context.file.path;

    if (path.startsWith('lib/infrastructure/network/')) {
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
                'Only the network layer knows which HTTP library this app '
                'uses. A file that builds its own Dio, or reads a cookie jar, '
                'is a second transport nobody reviews.',
            allowedAlternative:
                'Call HttpClient from a data/remote/ source; if it lacks '
                'something, add it to lib/infrastructure/network/.',
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
                'made outside a data/remote/ source is one the review of that '
                'policy never sees.',
            allowedAlternative:
                "Put the call in the feature's data/remote/ data source, "
                'behind its repository.',
          ),
        );
      }
    }

    return violations;
  }
}
