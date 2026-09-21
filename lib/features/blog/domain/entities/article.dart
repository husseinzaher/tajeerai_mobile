/// The blog, as this application understands it.
///
/// Framework-free, like every domain file: no Flutter, no Riverpod, no Dio.
/// What arrives from the backend is bilingual - every piece of copy is
/// `{ ar, en }` - and that shape is kept rather than flattened at the edge,
/// because which language a reader wants is a question the screen answers from
/// the app's locale, not one the network layer can.
library;

/// A string the backend holds in both languages.
class LocalizedText {
  const LocalizedText({this.ar = '', this.en = ''});

  final String ar;
  final String en;

  static const LocalizedText empty = LocalizedText();

  /// The side a reader of [languageCode] wants, falling back to the other.
  ///
  /// The fallback is the point. A post written in one language only is normal -
  /// the writer is asked for one or both - and showing an empty headline
  /// because the reader's side is blank would be worse than showing the other
  /// language.
  String resolve(String languageCode) {
    final String preferred = languageCode == 'ar' ? ar : en;

    if (preferred.trim().isNotEmpty) return preferred;

    final String other = languageCode == 'ar' ? en : ar;

    return other.trim().isEmpty ? '' : other;
  }

  bool get isEmpty => ar.trim().isEmpty && en.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.ar == ar && other.en == en;

  @override
  int get hashCode => Object.hash(ar, en);
}

/// One optimised copy of an image the backend derived.
class ImageVariant {
  const ImageVariant({
    required this.url,
    required this.width,
    required this.format,
  });

  final String url;
  final int width;

  /// `webp` or `avif`. Kept so a client that cannot decode one can skip it.
  final String format;
}

/// A picture, and the smaller copies of it the backend made.
class ArticleImage {
  const ArticleImage({
    required this.url,
    this.width,
    this.height,
    this.variants = const <ImageVariant>[],
  });

  /// The original. Always a complete answer on its own.
  final String url;

  /// The original's dimensions, when the backend reported them. Used to
  /// reserve the right box before any bytes arrive.
  final int? width;
  final int? height;

  final List<ImageVariant> variants;

  double? get aspectRatio {
    final int? w = width;
    final int? h = height;

    return w == null || h == null || h == 0 ? null : w / h;
  }

  /// The narrowest copy that still fills [targetWidth] logical pixels.
  ///
  /// The whole reason variants exist: a 48-pixel avatar and a full-width cover
  /// should not download the same file. Falls back to the original when no
  /// copy is wide enough, which is correct rather than a failure - the
  /// original is the widest thing there is.
  ///
  /// `avif` is skipped: Flutter's image codecs do not decode it on every
  /// platform this app ships to, and a picture that fails to decode is worse
  /// than a larger one that renders.
  String urlFor(double targetWidth) {
    final List<ImageVariant> usable =
        variants.where((variant) => variant.format == 'webp').toList()
          ..sort((a, b) => a.width.compareTo(b.width));

    for (final ImageVariant variant in usable) {
      if (variant.width >= targetWidth) return variant.url;
    }

    return url;
  }
}

/// Who wrote an article.
class ArticleAuthor {
  const ArticleAuthor({required this.name, this.title, this.avatar});

  final String name;
  final LocalizedText? title;
  final ArticleImage? avatar;
}

/// A post as the list shows it: everything except the body.
///
/// A separate type from [Article] because the backend genuinely sends less -
/// the list endpoint omits the blocks - and a single type with a nullable body
/// would let a screen read a field that was never going to be there.
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.excerpt,
    this.slugAr,
    this.cover,
    this.author,
    this.categoryName,
    this.tags = const <String>[],
    this.publishedAt,
    this.readingMinutes,
  });

  final String id;

  /// The Latin address, which every post has.
  final String slug;

  /// The Arabic address, when the post has one.
  final String? slugAr;

  final LocalizedText title;
  final LocalizedText excerpt;
  final ArticleImage? cover;
  final ArticleAuthor? author;
  final LocalizedText? categoryName;
  final List<String> tags;
  final DateTime? publishedAt;

  /// Null when the backend did not compute one; never rendered as "0 min".
  final int? readingMinutes;

  /// The address to open this post at, in the reader's language.
  ///
  /// An Arabic reader gets the Arabic address when there is one, so the URL
  /// they could copy out of the app is the one they would recognise. The
  /// backend accepts either.
  String addressFor(String languageCode) {
    final String? arabic = slugAr;

    return languageCode == 'ar' && arabic != null && arabic.isNotEmpty
        ? arabic
        : slug;
  }
}

/// One piece of an article's body.
///
/// A sealed hierarchy so a screen must handle every kind it can be handed, and
/// so a kind the backend adds later arrives as [UnsupportedBlock] rather than
/// as a crash or a blank space.
sealed class ArticleBlock {
  const ArticleBlock();
}

/// Prose, with an optional heading and an optional illustration.
class ProseBlock extends ArticleBlock {
  const ProseBlock({
    required this.paragraphs,
    this.heading,
    this.html,
    this.image,
    this.imageAlt,
  });

  final LocalizedText? heading;

  /// The paragraphs, per language. What every post has, including ones written
  /// before the backend could format anything.
  final List<LocalizedParagraphs> paragraphs;

  /// The same prose with the writer's formatting, when the post has it.
  ///
  /// Carried but not yet rendered - see the note on the article screen. Kept
  /// on the entity so adding a renderer later is a presentation change rather
  /// than a trip back through the data layer.
  final LocalizedText? html;

  final ArticleImage? image;
  final LocalizedText? imageAlt;
}

/// A section's paragraphs in one language.
class LocalizedParagraphs {
  const LocalizedParagraphs({
    this.ar = const <String>[],
    this.en = const <String>[],
  });

  final List<String> ar;
  final List<String> en;

  List<String> resolve(String languageCode) {
    final List<String> preferred = languageCode == 'ar' ? ar : en;

    if (preferred.isNotEmpty) return preferred;

    return languageCode == 'ar' ? en : ar;
  }
}

/// Questions a reader would ask after finishing, and their answers.
class FaqBlock extends ArticleBlock {
  const FaqBlock({required this.items, this.heading});

  final LocalizedText? heading;
  final List<FaqItem> items;
}

class FaqItem {
  const FaqItem({required this.question, required this.answer});

  final LocalizedText question;
  final LocalizedText answer;
}

/// A block this version of the app does not know how to draw.
///
/// Rendered as nothing rather than as an error. The backend's block vocabulary
/// is shared with a website that has more kinds of section than a phone needs,
/// and an app that crashed on an unfamiliar one would be broken by a marketing
/// change it has no stake in.
class UnsupportedBlock extends ArticleBlock {
  const UnsupportedBlock(this.type);

  final String type;
}

/// A post in full.
class Article {
  const Article({
    required this.summary,
    required this.blocks,
    this.related = const <ArticleSummary>[],
  });

  final ArticleSummary summary;
  final List<ArticleBlock> blocks;
  final List<ArticleSummary> related;

  String get id => summary.id;
  String get slug => summary.slug;
}

/// One page of the index.
class ArticlePage {
  const ArticlePage({
    required this.articles,
    required this.page,
    required this.hasMore,
  });

  final List<ArticleSummary> articles;
  final int page;
  final bool hasMore;

  static const ArticlePage empty = ArticlePage(
    articles: <ArticleSummary>[],
    page: 1,
    hasMore: false,
  );
}
