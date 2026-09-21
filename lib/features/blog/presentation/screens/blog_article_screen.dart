import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/article.dart';
import '../controllers/blog_list_controller.dart';
import '../widgets/article_card.dart';
import '../widgets/blog_async_view.dart';

/// One article, read without signing in.
///
/// Addressed by slug rather than id, so the route a reader is on is the one a
/// link would carry - and an Arabic article keeps its Arabic address, which
/// the backend accepts alongside the Latin one.
class BlogArticleScreen extends ConsumerWidget {
  const BlogArticleScreen({required this.slug, super.key});

  final String slug;

  /// Roughly what the hero occupies. Picks the variant, so a phone downloads a
  /// phone-sized copy of a picture the website serves at 1536.
  static const double _heroWidth = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final String language = ref.watch(localeProvider).code;
    final AsyncValue<Article> article = ref.watch(blogArticleProvider(slug));

    return AppScaffold(
      toolbar: AppToolbar(showBack: true, onBack: () => _back(context)),
      body: AppAsyncView<Article>(
        state: article.toViewState<Article>(
          (Article value) => value,
          /*
            A stale shared link is the common failure here, and it is not the
            same as the network being down. Saying "no longer available" for a
            404 and "could not be loaded" for anything else is the difference
            between a reader closing the app and a reader pulling to retry.
          */
          failure: article.error is NotFoundFailure
              ? strings.articleMissing
              : strings.articleUnreadable,
          onRetry: () => ref.invalidate(blogArticleProvider(slug)),
        ),
        data: (Article value) => _Article(
          article: value,
          language: language,
          strings: strings,
          onOpenRelated: (ArticleSummary related) => context.pushReplacement(
            AppRoutes.blogArticlePath(related.addressFor(language)),
          ),
        ),
      ),
    );
  }

  /*
    A reader who arrived from a shared link has nothing to go back to, so the
    back button takes them to the index rather than out of the app - which is
    also how they discover there is one.
  */
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();

      return;
    }

    context.go(AppRoutes.blog);
  }
}

class _Article extends StatelessWidget {
  const _Article({
    required this.article,
    required this.language,
    required this.strings,
    required this.onOpenRelated,
  });

  final Article article;
  final String language;
  final AppStrings strings;
  final ValueChanged<ArticleSummary> onOpenRelated;

  @override
  Widget build(BuildContext context) {
    final ArticleSummary summary = article.summary;

    return ListView(
      padding: const EdgeInsets.only(bottom: TajeerSpacing.xl),
      children: <Widget>[
        if (summary.cover case final ArticleImage cover)
          AppNetworkImage(
            url: cover.urlFor(BlogArticleScreen._heroWidth),
            /*
              The original's ratio when the backend reported it, so the box is
              the right shape before any bytes arrive and the text below does
              not jump when they do.
            */
            aspectRatio: cover.aspectRatio ?? 16 / 9,
            borderRadius: BorderRadius.zero,
          ),
        Padding(
          padding: const EdgeInsets.all(TajeerSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Header(summary: summary, language: language, strings: strings),
              const SizedBox(height: TajeerSpacing.lg),
              for (final ArticleBlock block in article.blocks)
                _Block(block: block, language: language, strings: strings),
              if (article.related.isNotEmpty) ...<Widget>[
                const SizedBox(height: TajeerSpacing.lg),
                AppSeparator(),
                const SizedBox(height: TajeerSpacing.md),
                AppSectionHeader(title: strings.relatedArticles),
                const SizedBox(height: TajeerSpacing.sm),
                for (final ArticleSummary related in article.related)
                  Padding(
                    padding: const EdgeInsets.only(bottom: TajeerSpacing.sm),
                    child: ArticleCard(
                      article: related,
                      language: language,
                      readingTime: strings.readingTime,
                      onTap: () => onOpenRelated(related),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The title, the byline and what it costs to read.
class _Header extends StatelessWidget {
  const _Header({
    required this.summary,
    required this.language,
    required this.strings,
  });

  final ArticleSummary summary;
  final String language;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final String category = summary.categoryName?.resolve(language) ?? '';
    final String label = category.isNotEmpty
        ? category
        : (summary.tags.isNotEmpty ? summary.tags.first : '');

    final List<String> meta = <String>[
      if (summary.publishedAt case final DateTime published)
        AppRelativeTime.forRow(
          published,
          locale: language,
          messages: context.strings,
        ),
      if (summary.readingMinutes case final int minutes)
        strings.readingTime(minutes),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label.isNotEmpty) ...<Widget>[
          AppBadge(label: label, size: AppBadgeSize.small),
          const SizedBox(height: TajeerSpacing.sm),
        ],
        AppBidiText(summary.title.resolve(language)),
        if (meta.isNotEmpty) ...<Widget>[
          const SizedBox(height: TajeerSpacing.xs),
          Text(
            meta.join('  ·  '),
            style: context.text.labelSmall?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
        if (summary.author case final ArticleAuthor author) ...<Widget>[
          const SizedBox(height: TajeerSpacing.md),
          Row(
            children: <Widget>[
              AppAvatar(
                name: author.name,
                /* A 40pt avatar takes the smallest copy there is. */
                imageUrl: author.avatar?.urlFor(80),
                size: 40,
              ),
              const SizedBox(width: TajeerSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppBidiText(author.name, maxLines: 1),
                    if (author.title?.resolve(language) case final String role
                        when role.isNotEmpty)
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelSmall?.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One section of the body.
///
/// A switch over the sealed block type, so a kind the backend adds later
/// arrives here as [UnsupportedBlock] and is drawn as nothing - the app is not
/// broken by a marketing change it has no stake in.
class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.language,
    required this.strings,
  });

  final ArticleBlock block;
  final String language;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final ProseBlock prose => _prose(context, prose),
      final FaqBlock faq => _faq(context, faq),
      UnsupportedBlock() => const SizedBox.shrink(),
    };
  }

  Widget _prose(BuildContext context, ProseBlock block) {
    final String heading = block.heading?.resolve(language) ?? '';
    final List<String> paragraphs = block.paragraphs.isEmpty
        ? const <String>[]
        : block.paragraphs.first.resolve(language);

    if (heading.isEmpty && paragraphs.isEmpty && block.image == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: TajeerSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (block.image case final ArticleImage image) ...<Widget>[
            AppNetworkImage(
              url: image.urlFor(BlogArticleScreen._heroWidth),
              aspectRatio: image.aspectRatio ?? 4 / 3,
              semanticLabel: block.imageAlt?.resolve(language),
            ),
            const SizedBox(height: TajeerSpacing.sm),
          ],
          if (heading.isNotEmpty) ...<Widget>[
            AppBidiText(heading),
            const SizedBox(height: TajeerSpacing.xs),
          ],
          for (final String paragraph in paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: TajeerSpacing.sm),
              child: Text(paragraph, style: context.text.bodyMedium),
            ),
        ],
      ),
    );
  }

  Widget _faq(BuildContext context, FaqBlock block) {
    if (block.items.isEmpty) return const SizedBox.shrink();

    final String heading = block.heading?.resolve(language) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: TajeerSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppSectionHeader(
            title: heading.isEmpty ? strings.commonQuestions : heading,
          ),
          const SizedBox(height: TajeerSpacing.sm),
          for (final FaqItem item in block.items)
            Padding(
              padding: const EdgeInsets.only(bottom: TajeerSpacing.sm),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    AppBidiText(item.question.resolve(language)),
                    const SizedBox(height: TajeerSpacing.xs),
                    Text(
                      item.answer.resolve(language),
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
