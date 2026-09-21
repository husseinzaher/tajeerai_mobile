import 'package:flutter/material.dart';

import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/article.dart';

/// One article, as the index lists it.
///
/// Feature-local rather than a design-system component: it knows what an
/// [ArticleSummary] is, and the design system may not (RULE 16). What it does
/// is compose pieces the design system owns - the card, the image, the chips -
/// so the blog looks like the rest of the app without the design system
/// learning about blogs.
class ArticleCard extends StatelessWidget {
  const ArticleCard({
    required this.article,
    required this.language,
    required this.onTap,
    required this.readingTime,
    this.featured = false,
    super.key,
  });

  final ArticleSummary article;

  /// Which side of every bilingual field to read.
  final String language;

  /// The lead article: a full-width cover rather than a thumbnail.
  final bool featured;

  final VoidCallback onTap;

  /// "5 min read", supplied by the screen so this widget stays free of the
  /// app's string table - it is handed presentation data, like everything the
  /// design system draws.
  final String Function(int minutes) readingTime;

  /// Roughly what the cover occupies, in logical pixels.
  ///
  /// The number the variant choice is made from, so a thumbnail downloads a
  /// thumbnail. Approximate on purpose - the exact width depends on the
  /// device, and asking for one copy size per handset would defeat caching.
  static const double _featuredWidth = 640;
  static const double _thumbnailWidth = 160;

  @override
  Widget build(BuildContext context) {
    final String title = article.title.resolve(language);
    final String excerpt = article.excerpt.resolve(language);
    final String readingLabel = switch (article.readingMinutes) {
      final int minutes => readingTime(minutes),
      null => '',
    };

    return AppCard(
      onTap: onTap,
      semanticLabel: title,
      child: featured
          ? _featured(context, title, excerpt, readingLabel)
          : _row(context, title, excerpt, readingLabel),
    );
  }

  Widget _featured(
    BuildContext context,
    String title,
    String excerpt,
    String readingLabel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (article.cover case final ArticleImage cover) ...<Widget>[
          AppNetworkImage(
            url: cover.urlFor(_featuredWidth),
            aspectRatio: 16 / 9,
            borderRadius: TajeerRadii.mdAll,
          ),
          const SizedBox(height: TajeerSpacing.sm),
        ],
        _tag(context),
        AppBidiText(title, maxLines: 3),
        if (excerpt.isNotEmpty) ...<Widget>[
          const SizedBox(height: TajeerSpacing.xs),
          Text(
            excerpt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: TajeerSpacing.sm),
        _meta(context, readingLabel),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String title,
    String excerpt,
    String readingLabel,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (article.cover case final ArticleImage cover) ...<Widget>[
          SizedBox(
            width: 96,
            child: AppNetworkImage(
              url: cover.urlFor(_thumbnailWidth),
              aspectRatio: 1,
              borderRadius: TajeerRadii.mdAll,
            ),
          ),
          const SizedBox(width: TajeerSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _tag(context),
              AppBidiText(title, maxLines: 2),
              const SizedBox(height: TajeerSpacing.xs),
              _meta(context, readingLabel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tag(BuildContext context) {
    final String category = article.categoryName?.resolve(language) ?? '';
    final String label = category.isNotEmpty
        ? category
        : (article.tags.isNotEmpty ? article.tags.first : '');

    if (label.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: TajeerSpacing.xs),
      child: AppBadge(label: label, size: AppBadgeSize.small),
    );
  }

  /// The date and the reading time, which is all a card needs of either.
  Widget _meta(BuildContext context, String readingLabel) {
    final TextStyle? style = context.text.labelSmall?.copyWith(
      color: context.colors.textMuted,
    );

    final List<String> parts = <String>[
      if (article.publishedAt case final DateTime published)
        AppRelativeTime.forRow(
          published,
          locale: language,
          messages: context.strings,
        ),
      /* Null means the backend did not compute one. "0 min read" would be a
         statement, and a false one. */
      if (readingLabel.isNotEmpty) readingLabel,
    ];

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(parts.join('  ·  '), style: style);
  }
}
