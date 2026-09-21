import '../../../../infrastructure/network/http_client.dart';
import '../../domain/entities/article.dart';
import '../models/article_dto.dart';

/// The blog's HTTP calls.
///
/// The only file in this feature allowed to name `HttpClient` (RULE 36), and
/// the only place the blog's endpoints are written down. Raises
/// `HttpException`; the repository translates it, the same division every
/// other feature uses.
///
/// Every path here is under `/v1/blog/public/`, which the client treats as
/// public: a 401 from one of these is an answer, not a stale credential, and
/// must never trigger the renewal that can sign a member out.
class BlogRemoteDataSource {
  const BlogRemoteDataSource(this._http);

  final HttpClient _http;

  static const String _posts = '/v1/blog/public/posts';
  static const String _index = '/v1/blog/public/index';

  Future<ArticlePage> fetchPage({
    required int page,
    required int perPage,
    String? tag,
    String? search,
  }) async {
    final Map<String, Object?> json = await _http.get(
      _posts,
      query: <String, Object?>{
        'page': page,
        'perPage': perPage,
        if (tag != null && tag.isNotEmpty) 'tag': tag,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );

    return _absolutisePage(ArticleDto.decodePage(json));
  }

  Future<Article> fetchArticle(String slug) async {
    /*
      Encoded, because an Arabic slug is the normal case here and a raw one
      would be an invalid URL. The backend accepts either address.
    */
    final Map<String, Object?> json = await _http.get(
      '$_posts/${Uri.encodeComponent(slug)}',
    );

    final Article article = ArticleDto.decodeArticle(json);

    return Article(
      summary: _absolutiseSummary(article.summary),
      blocks: <ArticleBlock>[
        for (final ArticleBlock block in article.blocks)
          _absolutiseBlock(block),
      ],
      related: <ArticleSummary>[
        for (final ArticleSummary related in article.related)
          _absolutiseSummary(related),
      ],
    );
  }

  Future<List<String>> fetchTags() async {
    return ArticleDto.decodeTags(await _http.get(_index));
  }

  /*
    Media arrives as an origin-relative path - `/api/v1/media/public/<id>` -
    because the website and the API share an origin and a hostname baked into
    stored content is how a domain change breaks old articles. A phone has no
    origin, so the address is completed here, at the one boundary that knows
    which deployment this build points at.
  */
  String _absolute(String url) =>
      url.startsWith('/') ? _http.resolve(url).toString() : url;

  ArticleImage? _absolutiseImage(ArticleImage? image) {
    if (image == null) return null;

    return ArticleImage(
      url: _absolute(image.url),
      width: image.width,
      height: image.height,
      variants: <ImageVariant>[
        for (final ImageVariant variant in image.variants)
          ImageVariant(
            url: _absolute(variant.url),
            width: variant.width,
            format: variant.format,
          ),
      ],
    );
  }

  ArticlePage _absolutisePage(ArticlePage page) => ArticlePage(
    articles: <ArticleSummary>[
      for (final ArticleSummary article in page.articles)
        _absolutiseSummary(article),
    ],
    page: page.page,
    hasMore: page.hasMore,
  );

  ArticleSummary _absolutiseSummary(ArticleSummary summary) => ArticleSummary(
    id: summary.id,
    slug: summary.slug,
    slugAr: summary.slugAr,
    title: summary.title,
    excerpt: summary.excerpt,
    cover: _absolutiseImage(summary.cover),
    author: switch (summary.author) {
      final ArticleAuthor author => ArticleAuthor(
        name: author.name,
        title: author.title,
        avatar: _absolutiseImage(author.avatar),
      ),
      null => null,
    },
    categoryName: summary.categoryName,
    tags: summary.tags,
    publishedAt: summary.publishedAt,
    readingMinutes: summary.readingMinutes,
  );

  ArticleBlock _absolutiseBlock(ArticleBlock block) => switch (block) {
    ProseBlock(
      :final heading,
      :final paragraphs,
      :final html,
      :final image,
      :final imageAlt,
    ) =>
      ProseBlock(
        heading: heading,
        paragraphs: paragraphs,
        html: html,
        image: _absolutiseImage(image),
        imageAlt: imageAlt,
      ),
    _ => block,
  };
}
