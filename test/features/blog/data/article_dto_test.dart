import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/blog/data/models/article_dto.dart';
import 'package:TajeerAi/features/blog/domain/entities/article.dart';

/// Decoding the backend's blog, in the shapes it actually sends.
///
/// The payloads here are trimmed copies of real responses from
/// `/v1/blog/public/posts`, including the awkward parts: a post with no cover,
/// a post whose Arabic side is the only one filled, and a block type this app
/// has never heard of.
void main() {
  group('a page of the index', () {
    Map<String, Object?> page({
      List<Object?>? data,
      Map<String, Object?>? meta,
    }) => <String, Object?>{
      'data': data ?? <Object?>[_summaryJson()],
      'meta':
          meta ?? <String, Object?>{'page': 1, 'perPage': 20, 'lastPage': 3},
    };

    test('reads the articles and where it is in the list', () {
      final ArticlePage decoded = ArticleDto.decodePage(page());

      expect(decoded.articles, hasLength(1));
      expect(decoded.page, 1);
      expect(decoded.hasMore, isTrue);
    });

    test('knows the last page has nothing after it', () {
      final ArticlePage decoded = ArticleDto.decodePage(
        page(meta: <String, Object?>{'page': 3, 'perPage': 20, 'lastPage': 3}),
      );

      expect(decoded.hasMore, isFalse);
    });

    test('falls back to a total when no last page was sent', () {
      final ArticlePage decoded = ArticleDto.decodePage(
        page(meta: <String, Object?>{'page': 1, 'perPage': 20, 'total': 45}),
      );

      expect(decoded.hasMore, isTrue);
    });

    /* One unreadable row must not cost the reader the other nineteen. */
    test('skips a row it cannot read and keeps the rest', () {
      final ArticlePage decoded = ArticleDto.decodePage(
        page(
          data: <Object?>[
            <String, Object?>{'title': 'no id and no slug'},
            'not even a map',
            _summaryJson(),
          ],
        ),
      );

      expect(decoded.articles, hasLength(1));
    });

    test('survives an envelope with nothing in it', () {
      expect(
        ArticleDto.decodePage(const <String, Object?>{}).articles,
        isEmpty,
      );
    });
  });

  group('one summary', () {
    test('reads both languages, the tags and the reading time', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(_summaryJson());

      expect(summary.title.ar, 'كيف تحول محادثات الواتساب');
      expect(summary.title.en, 'How to turn chats into sales');
      expect(summary.tags, <String>['whatsapp', 'e-commerce']);
      expect(summary.readingMinutes, 4);
      expect(summary.publishedAt, isNotNull);
    });

    /* Zero means "not computed"; a card reading "0 min read" states something
       false rather than omitting something unknown. */
    test('treats a reading time of zero as unknown', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(
        _summaryJson(readingMinutes: 0),
      );

      expect(summary.readingMinutes, isNull);
    });

    test('refuses a post with no identity', () {
      expect(
        () => ArticleDto.decodeSummary(const <String, Object?>{'title': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('copes with a post that has no cover, author or category', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(
        _summaryJson(coverMedia: null, author: null),
      );

      expect(summary.cover, isNull);
      expect(summary.author, isNull);
      expect(summary.categoryName, isNull);
    });

    test('reads the Arabic address when the post has one', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(_summaryJson());

      expect(summary.addressFor('ar'), 'كيف-تحول-محادثات-الواتساب');
      expect(summary.addressFor('en'), 'how-to-turn-chats-into-sales');
    });

    test('falls back to the Latin address when there is no Arabic one', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(
        _summaryJson(slugAr: null),
      );

      expect(summary.addressFor('ar'), 'how-to-turn-chats-into-sales');
    });
  });

  group('the optimised copies of a picture', () {
    test('reads the original size and every variant', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(_summaryJson());
      final ArticleImage cover = summary.cover!;

      expect(cover.width, 1184);
      expect(cover.height, 864);
      expect(cover.variants, hasLength(3));
      expect(cover.aspectRatio, closeTo(1184 / 864, 0.001));
    });

    /* The whole point of variants: a thumbnail downloads a thumbnail. */
    test('picks the narrowest copy that still fills the slot', () {
      final ArticleImage cover = ArticleDto.decodeSummary(_summaryJson())
          .cover!;

      expect(cover.urlFor(100), '/w320.webp');
      expect(cover.urlFor(320), '/w320.webp');
      expect(cover.urlFor(500), '/w768.webp');
    });

    test('falls back to the original when no copy is wide enough', () {
      final ArticleImage cover = ArticleDto.decodeSummary(_summaryJson())
          .cover!;

      expect(cover.urlFor(4000), '/cover.png');
    });

    /* AVIF is skipped: it does not decode on every platform this ships to,
       and a picture that fails to render is worse than a larger one. */
    test('never offers a format Flutter may not decode', () {
      final ArticleImage cover = ArticleDto.decodeSummary(_summaryJson())
          .cover!;

      for (final double width in <double>[10, 320, 700, 5000]) {
        expect(cover.urlFor(width), isNot(endsWith('.avif')));
      }
    });

    test('copes with a picture the backend has not derived copies of yet', () {
      final ArticleSummary summary = ArticleDto.decodeSummary(
        _summaryJson(coverMedia: <String, Object?>{'url': '/cover.png'}),
      );

      expect(summary.cover!.urlFor(320), '/cover.png');
      expect(summary.cover!.aspectRatio, isNull);
    });
  });

  group('an article in full', () {
    test('reads its blocks and what is related to it', () {
      final Article article = ArticleDto.decodeArticle(<String, Object?>{
        'post': _summaryJson(
          blocks: <Object?>[
            _proseJson(),
            _faqJson(),
            <String, Object?>{'type': 'pricing', 'data': <String, Object?>{}},
          ],
        ),
        'related': <Object?>[_summaryJson(id: 'p2', slug: 'another')],
      });

      expect(article.blocks, hasLength(3));
      expect(article.blocks[0], isA<ProseBlock>());
      expect(article.blocks[1], isA<FaqBlock>());
      /* A kind this app has never heard of, kept and drawn as nothing. */
      expect(article.blocks[2], isA<UnsupportedBlock>());
      expect(article.related, hasLength(1));
    });

    test('reads a section its paragraphs and its heading', () {
      final Article article = ArticleDto.decodeArticle(<String, Object?>{
        'post': _summaryJson(blocks: <Object?>[_proseJson()]),
      });
      final ProseBlock prose = article.blocks.first as ProseBlock;

      expect(prose.heading!.resolve('ar'), 'الخطوة الأولى');
      expect(prose.paragraphs.first.resolve('ar'), hasLength(2));
      expect(prose.paragraphs.first.resolve('en'), hasLength(1));
    });

    test('hides a block the editor hid', () {
      final Article article = ArticleDto.decodeArticle(<String, Object?>{
        'post': _summaryJson(
          blocks: <Object?>[
            <String, Object?>{..._proseJson(), 'isVisible': false},
          ],
        ),
      });

      expect(article.blocks, isEmpty);
    });

    /* Half an entry is an accordion that opens on nothing. */
    test('drops an FAQ entry missing its question or its answer', () {
      final Article article = ArticleDto.decodeArticle(<String, Object?>{
        'post': _summaryJson(
          blocks: <Object?>[
            <String, Object?>{
              'type': 'faq',
              'data': <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'question': <String, Object?>{'ar': 'سؤال', 'en': 'Q'},
                    'answer': <String, Object?>{'ar': 'جواب', 'en': 'A'},
                  },
                  <String, Object?>{
                    'question': <String, Object?>{'ar': 'بلا جواب', 'en': ''},
                  },
                ],
              },
            },
          ],
        ),
      });

      expect((article.blocks.first as FaqBlock).items, hasLength(1));
    });

    test('refuses a response with no post in it', () {
      expect(
        () => ArticleDto.decodeArticle(const <String, Object?>{}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('bilingual copy', () {
    test('falls back to the other language rather than showing nothing', () {
      const LocalizedText arabicOnly = LocalizedText(ar: 'عنوان', en: '');

      expect(arabicOnly.resolve('en'), 'عنوان');
      expect(arabicOnly.resolve('ar'), 'عنوان');
    });

    test('is empty only when both sides are', () {
      expect(const LocalizedText().isEmpty, isTrue);
      expect(const LocalizedText(ar: '  ', en: '').isEmpty, isTrue);
      expect(const LocalizedText(en: 'x').isEmpty, isFalse);
    });
  });

  group('tags', () {
    test('reads the index vocabulary', () {
      expect(
        ArticleDto.decodeTags(const <String, Object?>{
          'categories': <Object?>[],
          'tags': <Object?>['whatsapp', 'retail'],
        }),
        <String>['whatsapp', 'retail'],
      );
    });

    test('is empty for a blog with no tags yet', () {
      expect(ArticleDto.decodeTags(const <String, Object?>{}), isEmpty);
    });
  });
}

Map<String, Object?> _summaryJson({
  String id = 'p1',
  String slug = 'how-to-turn-chats-into-sales',
  String? slugAr = 'كيف-تحول-محادثات-الواتساب',
  int? readingMinutes = 4,
  Object? coverMedia = _defaultCover,
  Object? author = _defaultAuthor,
  List<Object?>? blocks,
}) => <String, Object?>{
  'id': id,
  'slug': slug,
  'slugAr': slugAr,
  'title': <String, Object?>{
    'ar': 'كيف تحول محادثات الواتساب',
    'en': 'How to turn chats into sales',
  },
  'excerpt': <String, Object?>{'ar': 'مقتطف', 'en': 'An excerpt'},
  'tags': <Object?>['whatsapp', 'e-commerce'],
  'publishedAt': '2026-09-20T10:00:00.000Z',
  'readingMinutes': readingMinutes,
  'coverMedia': coverMedia,
  'author': author,
  if (blocks != null) 'blocks': blocks,
};

const Map<String, Object?> _defaultCover = <String, Object?>{
  'url': '/cover.png',
  'image': <String, Object?>{
    'width': 1184,
    'height': 864,
    'variants': <Object?>[
      <String, Object?>{'url': '/w320.webp', 'width': 320, 'format': 'webp'},
      <String, Object?>{'url': '/w768.webp', 'width': 768, 'format': 'webp'},
      <String, Object?>{'url': '/w320.avif', 'width': 320, 'format': 'avif'},
    ],
  },
};

const Map<String, Object?> _defaultAuthor = <String, Object?>{
  'name': 'Team Tajeer',
  'bio': <String, Object?>{'ar': 'فريق تاجر', 'en': 'The Tajeer team'},
};

Map<String, Object?> _proseJson() => <String, Object?>{
  'type': 'richText',
  'isVisible': true,
  'data': <String, Object?>{
    'title': <String, Object?>{'ar': 'الخطوة الأولى', 'en': 'The first step'},
    'body': <String, Object?>{
      'ar': <Object?>['فقرة أولى.', 'فقرة ثانية.'],
      'en': <Object?>['One paragraph.'],
    },
  },
};

Map<String, Object?> _faqJson() => <String, Object?>{
  'type': 'faq',
  'isVisible': true,
  'data': <String, Object?>{
    'items': <Object?>[
      <String, Object?>{
        'question': <String, Object?>{
          'ar': 'كيف أبدأ؟',
          'en': 'How do I start?',
        },
        'answer': <String, Object?>{'ar': 'بخطوة واحدة.', 'en': 'In one step.'},
      },
    ],
  },
};
