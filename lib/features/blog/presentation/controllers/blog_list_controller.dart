import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/article.dart';

part 'blog_list_controller.g.dart';

/// How many articles one request asks for.
///
/// Twenty fills more than a screen, so the reader is scrolling before the next
/// request is needed, and is well under the endpoint's cap of fifty.
const int blogPageSize = 20;

/// How long to wait after a keystroke before asking the server.
///
/// Long enough that typing a word is one request rather than five, short
/// enough that it does not feel like the field is ignoring you.
const Duration blogSearchDebounce = Duration(milliseconds: 350);

/// What the index is currently narrowed to.
///
/// Its own notifier rather than fields on the list, because changing a filter
/// has to *restart* the list - page one, nothing kept - and expressing that as
/// "the list is watching what it is a list of" makes it one code path instead
/// of two that must agree.
@riverpod
class BlogFilter extends _$BlogFilter {
  @override
  BlogQuery build() => const BlogQuery();

  void search(String term) => state = state.copyWith(search: term.trim());

  /// Selecting the tag already selected clears it, which is what tapping a
  /// pressed chip looks like it should do.
  void toggleTag(String tag) => state = state.copyWith(
    tag: state.tag == tag ? null : tag,
    clearTag: state.tag == tag,
  );
}

/// What the reader has narrowed the index to.
class BlogQuery {
  const BlogQuery({this.search = '', this.tag});

  final String search;
  final String? tag;

  bool get isNarrowed => search.isNotEmpty || tag != null;

  BlogQuery copyWith({String? search, String? tag, bool clearTag = false}) =>
      BlogQuery(
        search: search ?? this.search,
        tag: clearTag ? null : (tag ?? this.tag),
      );

  @override
  bool operator ==(Object other) =>
      other is BlogQuery && other.search == search && other.tag == tag;

  @override
  int get hashCode => Object.hash(search, tag);
}

/// The tags the blog actually uses.
///
/// Null while loading and empty when the blog has none - the filter row is
/// hidden in both cases rather than drawn empty, because a row of no chips is
/// a row that looks broken.
@riverpod
Future<List<String>> blogTags(Ref ref) {
  return ref.watch(blogRepositoryProvider).fetchTags();
}

/// The index, as a list that grows.
///
/// Holds the articles rather than deriving them, because "load more" is
/// accumulation: the screen shows page one *and* page two, and a provider that
/// re-fetched on every read would show only the newest page.
@riverpod
class BlogList extends _$BlogList {
  Timer? _debounce;
  bool _loadingMore = false;

  @override
  Future<ArticlePage> build() async {
    final BlogQuery query = ref.watch(blogFilterProvider);

    /*
      Debounced here rather than in the field, so every caller gets it -
      including a test typing faster than a person can. The first query of a
      screen is not delayed, because there is nothing to coalesce yet.
    */
    if (query.search.isNotEmpty) {
      await _debounced();
    }

    ref.onDispose(() => _debounce?.cancel());

    return ref
        .watch(blogRepositoryProvider)
        .fetchPage(
          page: 1,
          perPage: blogPageSize,
          tag: query.tag,
          search: query.search,
        );
  }

  Future<void> _debounced() {
    _debounce?.cancel();

    final Completer<void> gate = Completer<void>();

    _debounce = Timer(blogSearchDebounce, () {
      if (!gate.isCompleted) gate.complete();
    });

    return gate.future;
  }

  /// Whether another page exists and nothing is already fetching it.
  bool get canLoadMore => !_loadingMore && (state.value?.hasMore ?? false);

  /// Appends the next page.
  ///
  /// A scroll listener fires on every frame near the bottom, so the guard is
  /// the point: without it a fast flick sends four identical requests and the
  /// same articles arrive four times.
  ///
  /// A failure here leaves what is already on screen alone. The reader has
  /// articles; losing them because page three timed out would be a worse
  /// outcome than not having page three.
  Future<void> loadMore() async {
    final ArticlePage? current = state.value;

    if (_loadingMore || current == null || !current.hasMore) return;

    _loadingMore = true;

    try {
      final BlogQuery query = ref.read(blogFilterProvider);
      final ArticlePage next = await ref
          .read(blogRepositoryProvider)
          .fetchPage(
            page: current.page + 1,
            perPage: blogPageSize,
            tag: query.tag,
            search: query.search,
          );

      state = AsyncData<ArticlePage>(
        ArticlePage(
          articles: <ArticleSummary>[...current.articles, ...next.articles],
          page: next.page,
          hasMore: next.hasMore,
        ),
      );
    } on AppFailure {
      /* Keep the pages already read; the reader can pull to try again. */
    } finally {
      _loadingMore = false;
    }
  }

  /// Pull to refresh: page one again, discarding what was accumulated.
  Future<void> refresh() async {
    _loadingMore = false;
    ref.invalidateSelf();

    await future;
  }
}

/// One article, by the address it was reached at.
///
/// Family-scoped by slug so two articles never share a request, and kept alive
/// by nothing - leaving an article drops it, which is the right lifetime for
/// content a reader has finished.
@riverpod
Future<Article> blogArticle(Ref ref, String slug) {
  return ref.watch(blogRepositoryProvider).fetchArticle(slug);
}
