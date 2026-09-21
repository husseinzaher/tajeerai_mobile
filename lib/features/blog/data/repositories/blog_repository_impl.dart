import '../../../../failures/app_failure.dart';
import '../../../../infrastructure/network/http_exception.dart';
import '../../domain/entities/article.dart';
import '../../domain/repositories/blog_repository.dart';
import '../remote/blog_remote_data_source.dart';

/// The blog, over HTTP, with the failures this app speaks.
///
/// Thinner than the other repositories in this app because there is no local
/// database underneath it (ARCHITECTURE.md §11): its whole job is to call the
/// remote source and translate what goes wrong. `_guard` is the same
/// translation `CustomerRepositoryImpl` does, for the same reason - an
/// `HttpException` is an infrastructure type and RULE 27 keeps it out of the
/// layers above.
class BlogRepositoryImpl implements BlogRepository {
  const BlogRepositoryImpl({required BlogRemoteDataSource remote})
    : _remote = remote;

  final BlogRemoteDataSource _remote;

  @override
  Future<ArticlePage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? tag,
    String? search,
  }) {
    return _guard(
      () => _remote.fetchPage(
        page: page,
        perPage: perPage,
        tag: tag,
        search: search,
      ),
    );
  }

  @override
  Future<Article> fetchArticle(String slug) {
    return _guard(() => _remote.fetchArticle(slug));
  }

  @override
  Future<List<String>> fetchTags() {
    return _guard(() => _remote.fetchTags());
  }

  /// Turns transport and shape problems into the application's own failures.
  ///
  /// A `FormatException` becomes `UnknownFailure` rather than surfacing the
  /// parser's words: "Unexpected character at offset 12" tells a reader
  /// nothing they can act on, and tells an attacker something about the
  /// response.
  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on HttpException catch (error) {
      throw error.toFailure();
    } on FormatException catch (error) {
      throw UnknownFailure(
        message0: 'The blog sent an unexpected response.',
        cause: error,
      );
    }
  }
}
