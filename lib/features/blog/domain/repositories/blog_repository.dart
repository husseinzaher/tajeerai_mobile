import '../entities/article.dart';

/// Reading the blog.
///
/// Unlike every other repository in this app, this one does **not** read a
/// local database, and that is deliberate rather than missing.
/// `AppDatabase.clearWorkspaceData()` empties every table on sign-out, and a
/// guest has no session to outlive - so blog content in that database would be
/// wiped the moment somebody signed out, and would be workspace-scoped data
/// belonging to no workspace. See ARCHITECTURE.md §11.
///
/// So these methods reach the network, and say so in their names: nothing here
/// pretends to be a local read that happens to be slow.
abstract interface class BlogRepository {
  /// One page of the index, newest first.
  ///
  /// [tag] and [search] narrow it where the backend supports narrowing; both
  /// are passed straight through, and an unknown tag is an empty page rather
  /// than an error.
  Future<ArticlePage> fetchPage({
    int page,
    int perPage,
    String? tag,
    String? search,
  });

  /// One article by the address it was reached at, Latin or Arabic.
  ///
  /// Raises `NotFoundFailure` when no published post has that address, which
  /// is what a stale shared link looks like.
  Future<Article> fetchArticle(String slug);

  /// The tags the blog actually uses, for the filter row.
  ///
  /// An empty list means the blog has no tags yet, and the filter is hidden
  /// rather than drawn empty.
  Future<List<String>> fetchTags();
}
