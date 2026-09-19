import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/app/router/routes.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/feedback/connection_banner.dart';
import 'package:tajeerai_mobile/design_system/feedback/loading_state.dart';
import 'package:tajeerai_mobile/design_system/feedback/status_banner.dart';
import 'package:tajeerai_mobile/design_system/inbox/conversation_list_item.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_en.dart';
import 'package:tajeerai_mobile/features/conversations/application/state/sync_state.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/controllers/conversation_list_controller.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/screens/conversation_list_screen.dart';
import 'package:tajeerai_mobile/infrastructure/storage/preferences_storage.dart';

import '../../../support/fixed_clock.dart';

/// The rail's actions, counted rather than performed.
class _Controller extends ConversationListController {
  _Controller(super.ref);

  final List<String> markedRead = <String>[];
  int refreshes = 0;

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> markRead(Conversation conversation) async {
    markedRead.add(conversation.id);
  }
}

Conversation _conversation({String id = 'c1', int unreadCount = 0}) =>
    Conversation(
      id: id,
      state: ConversationState.open,
      customerName: 'Ada Lovelace',
      lastMessagePreview: 'See you then',
      lastMessageAt: testEpoch,
      unreadCount: unreadCount,
      createdAt: testEpoch,
    );

void main() {
  late PreferencesStorage preferences;
  late StreamController<List<Conversation>> conversations;
  late StreamController<ConversationSyncState> sync;
  _Controller? controller;

  Future<void> storeLocale(String code) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: code,
    });
    preferences = await PreferencesStorage.open();
  }

  setUp(() {
    // Broadcast, because a retry re-subscribes to the same source.
    conversations = StreamController<List<Conversation>>.broadcast();
    sync = StreamController<ConversationSyncState>.broadcast();
    controller = null;
  });

  tearDown(() async {
    await conversations.close();
    await sync.close();
  });

  /// The real screen under a real router, with the database and the sync
  /// coordinator replaced by streams the test drives.
  Widget subject() {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.conversations,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.conversations,
          builder: (BuildContext context, GoRouterState state) =>
              const ConversationListScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: AppRoutes.conversationDetail,
              builder: (BuildContext context, GoRouterState state) =>
                  Text('thread ${state.pathParameters['conversationId']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    return ProviderScope(
      overrides: [
        preferencesStorageProvider.overrideWithValue(preferences),
        conversationListProvider.overrideWith(
          (Ref ref) => conversations.stream,
        ),
        conversationSyncStateProvider.overrideWith((Ref ref) => sync.stream),
        conversationListControllerProvider.overrideWith(
          (Ref ref) => controller = _Controller(ref),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(TajeerPreset.fallback, Brightness.light),
        routerConfig: router,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('in English', () {
    setUp(() => storeLocale('en'));

    testWidgets('before the database answers, it draws placeholder rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      expect(find.text('Inbox'), findsOneWidget);
      expect(find.byType(AppLoadingState), findsOneWidget);
      expect(find.byType(AppStatusBanner), findsNothing);
    });

    testWidgets('an empty Inbox says so, in the app\'s words', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      sync.add(
        ConversationSyncState(phase: SyncPhase.synchronized, syncedAt: testEpoch),
      );
      conversations.add(<Conversation>[]);
      await settle(tester);

      expect(find.text('No conversations yet'), findsOneWidget);
      expect(
        find.text('New conversations appear here as customers get in touch.'),
        findsOneWidget,
      );
    });

    testWidgets('a search that finds nothing says that instead', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'zzz');
      conversations.add(<Conversation>[]);
      await settle(tester);

      expect(find.text(appMessagesEn.noMatches), findsOneWidget);
      expect(
        find.text('Nothing on this device matches that search.'),
        findsOneWidget,
      );
    });

    testWidgets('a list that cannot be read offers a retry that reads again', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversations.addError(StateError('the database is locked'));
      await settle(tester);

      expect(
        find.text('The conversation list could not be read.'),
        findsOneWidget,
      );
      // The exception's own text never reaches the screen.
      expect(find.textContaining('locked'), findsNothing);

      await tester.tap(find.text(appMessagesEn.tryAgain));
      await tester.pump();
      conversations.add(<Conversation>[_conversation()]);
      await settle(tester);

      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('opening a row clears its unread and goes to the thread', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversations.add(<Conversation>[_conversation(unreadCount: 2)]);
      await settle(tester);

      expect(find.byType(AppConversationListItem), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Ada Lovelace'));
      await settle(tester);

      expect(controller?.markedRead, <String>['c1']);
      expect(find.text('thread c1'), findsOneWidget);
    });

    testWidgets('pulling the list asks for a refresh', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversations.add(<Conversation>[_conversation()]);
      await settle(tester);

      await tester.fling(find.text('Ada Lovelace'), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(controller?.refreshes, 1);
    });

    testWidgets('before the first sync lands, an empty Inbox draws placeholders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      sync.add(const ConversationSyncState(phase: SyncPhase.syncing));
      conversations.add(<Conversation>[]);
      await settle(tester);

      expect(find.byType(AppLoadingState), findsOneWidget);
      expect(find.text('No conversations yet'), findsNothing);
      expect(find.byType(AppStatusBanner), findsNothing);
    });

    testWidgets('the banner follows synchronisation, and leaves when current', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversations.add(<Conversation>[_conversation()]);
      sync.add(
        ConversationSyncState(phase: SyncPhase.synchronized, syncedAt: testEpoch),
      );

      sync.add(
        ConversationSyncState(phase: SyncPhase.stale, syncedAt: testEpoch),
      );
      await settle(tester);
      expect(
        tester
            .widget<AppConnectionBanner>(find.byType(AppConnectionBanner))
            .status,
        AppConnectionStatus.offline,
      );
      expect(find.byType(AppStatusBanner), findsOneWidget);

      sync.add(const ConversationSyncState(phase: SyncPhase.synchronized));
      await settle(tester);
      expect(find.byType(AppStatusBanner), findsNothing);
    });
  });

  group('in Arabic', () {
    setUp(() => storeLocale('ar'));

    testWidgets('the Inbox speaks the member\'s language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      sync.add(
        ConversationSyncState(phase: SyncPhase.synchronized, syncedAt: testEpoch),
      );
      conversations.add(<Conversation>[]);
      await settle(tester);

      expect(find.text('صندوق الوارد'), findsOneWidget);
      expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
    });
  });
}
