import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/article.dart';
import '../controllers/blog_list_controller.dart';
import '../widgets/article_card.dart';
import '../widgets/blog_async_view.dart';

/// The blog index.
///
/// The first screen in this app a guest may open, which is why it is a
/// top-level route rather than a tab: the signed-in shell draws a profile and
/// permission-filtered navigation, and neither exists for a reader who has
/// never signed in. A member reaches the same screen from the drawer.
class BlogListScreen extends ConsumerStatefulWidget {
  const BlogListScreen({super.key});

  @override
  ConsumerState<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends ConsumerState<BlogListScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  /// How close to the end the reader has to be before the next page is asked
  /// for. Roughly two cards, so the list grows before they reach the bottom
  /// rather than after they have already seen it stop.
  static const double _loadMoreThreshold = 600;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;

    final ScrollPosition position = _scroll.position;

    if (position.maxScrollExtent - position.pixels <= _loadMoreThreshold) {
      /* The controller owns the "already fetching" guard; this may fire on
         every frame and must be cheap to refuse. */
      unawaited(ref.read(blogListProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final String language = ref.watch(localeProvider).code;
    final BlogQuery query = ref.watch(blogFilterProvider);
    final AsyncValue<ArticlePage> page = ref.watch(blogListProvider);

    return AppScaffold(
      /*
        `Navigator.canPop` rather than the router's: the question is whether
        there is a screen underneath this one, which is a Flutter question and
        has a Flutter answer. Asking the router would also make this screen
        untestable without one, for no gain.
      */
      toolbar: AppToolbar(
        title: strings.blog,
        showBack: Navigator.canPop(context),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(blogListProvider.notifier).refresh(),
        child: AppAsyncView<List<ArticleSummary>>(
          state: page.toViewState<List<ArticleSummary>>(
            (ArticlePage value) => value.articles,
            failure: strings.blogUnreadable,
            onRetry: () => ref.invalidate(blogListProvider),
          ),
          isEmpty: (List<ArticleSummary> articles) => articles.isEmpty,
          empty: (BuildContext context) => _Empty(
            narrowed: query.isNarrowed,
            strings: strings,
            header: _header(strings, language),
          ),
          data: (List<ArticleSummary> articles) => _List(
            articles: articles,
            language: language,
            readingTime: strings.readingTime,
            controller: _scroll,
            header: _header(strings, language),
            loadingMore: page.value?.hasMore ?? false,
            onOpen: _open,
          ),
        ),
      ),
    );
  }

  Widget _header(AppStrings strings, String language) {
    return _BlogHeader(
      strings: strings,
      searchController: _search,
      onSearch: (String term) =>
          ref.read(blogFilterProvider.notifier).search(term),
      selectedTag: ref.watch(blogFilterProvider).tag,
      tags: ref.watch(blogTagsProvider).value ?? const <String>[],
      onTag: (String tag) =>
          ref.read(blogFilterProvider.notifier).toggleTag(tag),
    );
  }

  void _open(ArticleSummary article, String language) {
    /*
      Pushed by its address rather than its id, so the route a reader is on is
      the one they could share - and an Arabic reader shares the Arabic one.
    */
    context.push(AppRoutes.blogArticlePath(article.addressFor(language)));
  }
}

/// The title block, the search field and the tag row.
class _BlogHeader extends StatelessWidget {
  const _BlogHeader({
    required this.strings,
    required this.searchController,
    required this.onSearch,
    required this.selectedTag,
    required this.tags,
    required this.onTag,
  });

  final AppStrings strings;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final String? selectedTag;
  final List<String> tags;
  final ValueChanged<String> onTag;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TajeerSpacing.md,
        TajeerSpacing.md,
        TajeerSpacing.md,
        TajeerSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: strings.blog,
            description: strings.blogTagline,
          ),
          const SizedBox(height: TajeerSpacing.md),
          AppSearchField(
            controller: searchController,
            hintText: strings.searchArticles,
            onChanged: onSearch,
          ),
          /*
            Hidden rather than drawn empty. A blog with no tags yet would
            otherwise show a row containing only "All", which looks like a
            filter that is broken rather than one that is unnecessary.
          */
          if (tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: TajeerSpacing.sm),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: tags.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TajeerSpacing.xs),
                itemBuilder: (BuildContext context, int index) {
                  final String tag = tags[index];

                  return AppChip(
                    label: tag,
                    selected: selectedTag == tag,
                    onTap: () => onTag(tag),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.articles,
    required this.language,
    required this.readingTime,
    required this.controller,
    required this.header,
    required this.loadingMore,
    required this.onOpen,
  });

  final List<ArticleSummary> articles;
  final String language;
  final String Function(int minutes) readingTime;
  final ScrollController controller;
  final Widget header;
  final bool loadingMore;
  final void Function(ArticleSummary article, String language) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      /* Always scrollable, so pull-to-refresh works on a short list too. */
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: TajeerSpacing.xl),
      itemCount: articles.length + (loadingMore ? 2 : 1),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) return header;

        final int position = index - 1;

        if (position >= articles.length) {
          return const Padding(
            padding: EdgeInsets.all(TajeerSpacing.lg),
            child: Center(child: AppSpinner()),
          );
        }

        final ArticleSummary article = articles[position];

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            TajeerSpacing.md,
            0,
            TajeerSpacing.md,
            TajeerSpacing.md,
          ),
          child: ArticleCard(
            article: article,
            language: language,
            readingTime: readingTime,
            /* The lead article is the one worth a large cover. */
            featured: position == 0,
            onTap: () => onOpen(article, language),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.narrowed,
    required this.strings,
    required this.header,
  });

  final bool narrowed;
  final AppStrings strings;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    /*
      The header stays: a reader who searched for something with no matches
      needs the field they typed into in order to try again, and an empty
      screen with no way back is a dead end.
    */
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: <Widget>[
        header,
        Padding(
          padding: const EdgeInsets.all(TajeerSpacing.md),
          child: AppEmptyState(
            title: narrowed ? strings.blogNoMatches : strings.blogEmpty,
            description: narrowed
                ? strings.blogNoMatchesDescription
                : strings.blogEmptyDescription,
            icon: LucideIcons.newspaper,
          ),
        ),
      ],
    );
  }
}
