import '../../domain/entities/article.dart';

/// The backend's blog JSON, as this app's entities.
///
/// Forgiving on purpose, in the same shape as `CustomerDto`: a missing
/// identity is a `FormatException` because there is nothing to show, and
/// everything else degrades. The blog's block vocabulary is shared with a
/// website that has sections a phone has no use for, so a decoder that threw
/// on an unfamiliar one would break this app whenever the marketing site grew
/// a feature.
abstract final class ArticleDto {
  /// A page of summaries from `GET /v1/blog/public/posts`.
  ///
  /// The envelope is `{ data, meta }`, and `meta` carries the page numbers.
  /// `hasMore` is derived rather than read: the backend sends `lastPage` or
  /// `totalPages` depending on the endpoint, and a client that guessed wrong
  /// would either stop early or ask forever.
  static ArticlePage decodePage(Map<String, Object?> json) {
    final List<ArticleSummary> articles = decodeSummaries(json['data']);
    final Map<String, Object?> meta =
        _map(json['meta']) ?? const <String, Object?>{};

    final int page = _int(meta['page']) ?? 1;
    final int? last = _int(meta['lastPage']) ?? _int(meta['totalPages']);
    final int? total = _int(meta['total']);
    final int perPage = _int(meta['perPage']) ?? articles.length;

    return ArticlePage(
      articles: articles,
      page: page,
      hasMore: switch ((last, total)) {
        (final int lastPage, _) => page < lastPage,
        (_, final int count) => page * perPage < count,
        /*
          Neither number was sent. A full page probably has more behind it and
          a short one does not - which is the same guess a reader makes, and is
          wrong only in the harmless direction of one extra request.
        */
        _ => articles.isNotEmpty && articles.length >= perPage,
      },
    );
  }

  static List<ArticleSummary> decodeSummaries(Object? raw) {
    if (raw is! List) return const <ArticleSummary>[];

    final List<ArticleSummary> decoded = <ArticleSummary>[];

    for (final Object? entry in raw) {
      final Map<String, Object?>? row = _map(entry);

      if (row == null) continue;

      try {
        decoded.add(decodeSummary(row));
      } on FormatException {
        /* One unreadable row must not cost the reader the other nineteen. */
        continue;
      }
    }

    return decoded;
  }

  static ArticleSummary decodeSummary(Map<String, Object?> json) {
    final String? id = _text(json['id']);
    final String? slug = _text(json['slug']);

    if (id == null || slug == null) {
      throw const FormatException('A blog post arrived with no id or slug.');
    }

    return ArticleSummary(
      id: id,
      slug: slug,
      slugAr: _text(json['slugAr']),
      title: localized(json['title']),
      excerpt: localized(json['excerpt']),
      cover: image(json['coverMedia']),
      author: author(json['author']),
      categoryName: json['categoryName'] == null
          ? null
          : localized(json['categoryName']),
      tags: _strings(json['tags']),
      publishedAt: _time(json['publishedAt']),
      /* Zero means "not computed"; a card saying "0 min read" states something false. */
      readingMinutes: switch (_int(json['readingMinutes'])) {
        final int minutes when minutes > 0 => minutes,
        _ => null,
      },
    );
  }

  /// One article from `GET /v1/blog/public/posts/:slug`, envelope included.
  static Article decodeArticle(Map<String, Object?> json) {
    final Map<String, Object?>? post = _map(json['post']);

    if (post == null) {
      throw const FormatException('The article response carried no post.');
    }

    return Article(
      summary: decodeSummary(post),
      blocks: decodeBlocks(post['blocks']),
      related: decodeSummaries(json['related']),
    );
  }

  static List<ArticleBlock> decodeBlocks(Object? raw) {
    if (raw is! List) return const <ArticleBlock>[];

    final List<ArticleBlock> blocks = <ArticleBlock>[];

    for (final Object? entry in raw) {
      final Map<String, Object?>? row = _map(entry);

      if (row == null) continue;
      /* The website hides a block without deleting it; so does this. */
      if (row['isVisible'] == false) continue;

      blocks.add(decodeBlock(row));
    }

    return blocks;
  }

  static ArticleBlock decodeBlock(Map<String, Object?> json) {
    final String type = _text(json['type']) ?? '';
    final Map<String, Object?> data =
        _map(json['data']) ?? const <String, Object?>{};

    return switch (type) {
      'richText' => ProseBlock(
        heading: data['title'] == null ? null : localized(data['title']),
        paragraphs: <LocalizedParagraphs>[paragraphs(data['body'])],
        html: data['html'] == null ? null : localized(data['html']),
        image: image(data['image']),
        imageAlt: data['imageAlt'] == null ? null : localized(data['imageAlt']),
      ),
      'faq' => FaqBlock(
        heading: data['title'] == null ? null : localized(data['title']),
        items: faqItems(data['items']),
      ),
      _ => UnsupportedBlock(type),
    };
  }

  static List<FaqItem> faqItems(Object? raw) {
    if (raw is! List) return const <FaqItem>[];

    final List<FaqItem> items = <FaqItem>[];

    for (final Object? entry in raw) {
      final Map<String, Object?>? row = _map(entry);

      if (row == null) continue;

      final LocalizedText question = localized(row['question']);
      final LocalizedText answer = localized(row['answer']);

      /* Half an entry is not an entry: an accordion that opens on nothing. */
      if (question.isEmpty || answer.isEmpty) continue;

      items.add(FaqItem(question: question, answer: answer));
    }

    return items;
  }

  static LocalizedText localized(Object? raw) {
    final Map<String, Object?>? map = _map(raw);

    if (map == null) {
      /* A plain string is one language, and the backend sends one in places. */
      final String? single = _text(raw);

      return single == null
          ? LocalizedText.empty
          : LocalizedText(en: single, ar: single);
    }

    return LocalizedText(
      ar: _text(map['ar']) ?? '',
      en: _text(map['en']) ?? '',
    );
  }

  static LocalizedParagraphs paragraphs(Object? raw) {
    final Map<String, Object?>? map = _map(raw);

    if (map == null) return const LocalizedParagraphs();

    return LocalizedParagraphs(
      ar: _strings(map['ar']),
      en: _strings(map['en']),
    );
  }

  /// A media object, with the optimised copies the backend derived.
  static ArticleImage? image(Object? raw) {
    final Map<String, Object?>? map = _map(raw);
    final String? url = _text(map?['url']);

    if (map == null || url == null) return null;

    final Map<String, Object?>? picture = _map(map['image']);

    return ArticleImage(
      url: url,
      width: _int(picture?['width']),
      height: _int(picture?['height']),
      variants: variants(picture?['variants']),
    );
  }

  static List<ImageVariant> variants(Object? raw) {
    if (raw is! List) return const <ImageVariant>[];

    final List<ImageVariant> decoded = <ImageVariant>[];

    for (final Object? entry in raw) {
      final Map<String, Object?>? row = _map(entry);
      final String? url = _text(row?['url']);
      final int? width = _int(row?['width']);

      if (row == null || url == null || width == null) continue;

      decoded.add(
        ImageVariant(
          url: url,
          width: width,
          format: _text(row['format']) ?? '',
        ),
      );
    }

    return decoded;
  }

  static ArticleAuthor? author(Object? raw) {
    final Map<String, Object?>? map = _map(raw);
    final String? name = _text(map?['name']);

    if (map == null || name == null) return null;

    return ArticleAuthor(
      name: name,
      title: map['bio'] == null ? null : localized(map['bio']),
      avatar: image(map['avatarMedia']),
    );
  }

  /// Tag names from `GET /v1/blog/public/index`.
  static List<String> decodeTags(Map<String, Object?> json) =>
      _strings(json['tags']);

  static Map<String, Object?>? _map(Object? raw) => switch (raw) {
    final Map<String, Object?> typed => typed,
    final Map<Object?, Object?> loose => loose.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    _ => null,
  };

  static String? _text(Object? raw) {
    if (raw is! String) return null;

    final String trimmed = raw.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _strings(Object? raw) {
    if (raw is! List) return const <String>[];

    return <String>[
      for (final Object? entry in raw)
        if (_text(entry) case final String value) value,
    ];
  }

  static int? _int(Object? raw) => switch (raw) {
    final int value => value,
    final num value => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };

  /// A timestamp, or null for anything unparseable - never a thrown exception.
  static DateTime? _time(Object? raw) {
    final String? text = _text(raw);

    return text == null ? null : DateTime.tryParse(text)?.toLocal();
  }
}
