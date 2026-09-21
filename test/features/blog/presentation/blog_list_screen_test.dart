import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/design_system/design_system.dart';
import 'package:TajeerAi/features/blog/domain/entities/article.dart';
import 'package:TajeerAi/features/blog/domain/repositories/blog_repository.dart';
import 'package:TajeerAi/features/blog/presentation/screens/blog_list_screen.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

import '../../../support/widget_harness.dart';

/// The blog index, in the four states a screen is actually in.
///
/// Every test here signs nobody in. That is the point of the feature: the
/// repository is reached with no session, and nothing on this screen asks for
/// one.
void main() {
  late PreferencesStorage preferences;

  /*
    The screen reads the app's locale, which is stored in preferences rather
    than the database so the very first frame has the right direction. A test
    that did not seed it would fail on the composition root rather than on
    anything the blog does.
  */
  Future<void> storeLocale(String code) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: code,
    });
    preferences = await PreferencesStorage.open();
  }

  setUp(() => storeLocale('en'));

  ArticleSummary article(String id, {String title = 'How to sell more'}) =>
      ArticleSummary(
        id: id,
        slug: 'article-$id',
        title: LocalizedText(ar: 'عنوان $id', en: title),
        excerpt: const LocalizedText(ar: 'مقتطف', en: 'An excerpt'),
        tags: const <String>['whatsapp'],
        readingMinutes: 4,
        publishedAt: DateTime.utc(2026, 9, 20),
      );

  Widget subject(
    BlogRepository repository, {
    Locale locale = const Locale('en'),
  }) {
    final bool arabic = locale.languageCode == 'ar';

    return ProviderScope(
      overrides: [
        blogRepositoryProvider.overrideWithValue(repository),
        preferencesStorageProvider.overrideWithValue(preferences),
        appStringsProvider.overrideWithValue(
          AppStrings(arabic ? AppLocale.arabic : AppLocale.english),
        ),
      ],
      child: wrapWidget(
        const BlogListScreen(),
        locale: locale,
        textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
      ),
    );
  }

  group('a guest opening the blog', () {
    testWidgets('sees the articles, with no session anywhere', (tester) async {
      final repository = _ScriptedBlog(
        page: ArticlePage(
          articles: <ArticleSummary>[
            article('1'),
            article('2', title: 'Second'),
          ],
          page: 1,
          hasMore: false,
        ),
      );

      await tester.pumpWidget(subject(repository));
      await tester.pumpAndSettle();

      expect(find.text('How to sell more'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      /* Nothing on this path consulted a session. */
      expect(repository.pagesRequested, 1);
    });

    testWidgets('waits without a spinner where the list will be', (
      tester,
    ) async {
      await tester.pumpWidget(subject(_ScriptedBlog(page: null)));
      await tester.pump();

      expect(find.byType(AppLoadingState), findsOneWidget);
    });

    testWidgets('says so when the blog has nothing in it yet', (tester) async {
      await tester.pumpWidget(subject(_ScriptedBlog(page: ArticlePage.empty)));
      await tester.pumpAndSettle();

      expect(find.text('No articles yet'), findsOneWidget);
    });

    testWidgets('offers a retry when it could not be read', (tester) async {
      await tester.pumpWidget(
        subject(
          _ScriptedBlog(failure: const TransportFailure(message: 'down')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The blog could not be loaded.'), findsOneWidget);
    });
  });

  group('narrowing it', () {
    testWidgets('shows the tags the blog actually uses', (tester) async {
      final repository = _ScriptedBlog(
        page: ArticlePage(
          articles: <ArticleSummary>[article('1')],
          page: 1,
          hasMore: false,
        ),
        tags: const <String>['whatsapp', 'retail'],
      );

      await tester.pumpWidget(subject(repository));
      await tester.pumpAndSettle();

      expect(find.text('whatsapp'), findsWidgets);
      expect(find.text('retail'), findsOneWidget);
    });

    /* A row containing nothing looks like a filter that is broken, rather than
       one that is unnecessary. */
    testWidgets('hides the filter entirely when there are no tags', (
      tester,
    ) async {
      final repository = _ScriptedBlog(
        page: ArticlePage(
          articles: <ArticleSummary>[article('1')],
          page: 1,
          hasMore: false,
        ),
        tags: const <String>[],
      );

      await tester.pumpWidget(subject(repository));
      await tester.pumpAndSettle();

      expect(find.byType(AppChip), findsNothing);
    });
  });

  group('in Arabic', () {
    testWidgets('reads the Arabic side and lays out right to left', (
      tester,
    ) async {
      final repository = _ScriptedBlog(
        page: ArticlePage(
          articles: <ArticleSummary>[article('1')],
          page: 1,
          hasMore: false,
        ),
      );

      await storeLocale('ar');
      await tester.pumpWidget(subject(repository, locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('عنوان 1'), findsOneWidget);
      expect(find.text('المدونة'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(BlogListScreen))),
        TextDirection.rtl,
      );
    });
  });
}

/// A blog that answers from a script.
///
/// `page: null` means "never answers", which is how a test holds the screen in
/// its loading state without a timer.
class _ScriptedBlog implements BlogRepository {
  _ScriptedBlog({this.page, this.failure, this.tags = const <String>[]});

  final ArticlePage? page;
  final AppFailure? failure;
  final List<String> tags;

  int pagesRequested = 0;

  @override
  Future<ArticlePage> fetchPage({
    int page = 1,
    int perPage = 20,
    String? tag,
    String? search,
  }) {
    pagesRequested += 1;

    final AppFailure? thrown = failure;

    if (thrown != null) return Future<ArticlePage>.error(thrown);

    final ArticlePage? answer = this.page;

    return answer == null
        ? Completer<ArticlePage>().future
        : Future<ArticlePage>.value(answer);
  }

  @override
  Future<Article> fetchArticle(String slug) =>
      Future<Article>.error(const NotFoundFailure(message: 'no such article'));

  @override
  Future<List<String>> fetchTags() => Future<List<String>>.value(tags);
}
