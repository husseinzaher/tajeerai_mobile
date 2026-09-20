import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/localization/ds_messages_en.dart';
import 'package:TajeerAi/design_system/messaging/composer.dart';
import 'package:TajeerAi/design_system/messaging/message_bubble.dart';
import 'package:TajeerAi/design_system/shell/toolbar.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/domain/entities/message.dart';
import 'package:TajeerAi/features/conversations/application/coordinators/message_media_coordinator.dart';
import 'package:TajeerAi/features/conversations/presentation/controllers/conversation_thread_controller.dart';
import 'package:TajeerAi/infrastructure/logging/logger.dart';
import 'package:TajeerAi/infrastructure/storage/file_storage.dart';

import '../application/fakes/fake_conversation_media_remote.dart';
import '../domain/fakes/fake_message_repository.dart';

import 'package:TajeerAi/features/conversations/presentation/screens/conversation_screen.dart';
import 'package:TajeerAi/infrastructure/storage/preferences_storage.dart';

import '../../../support/fixed_clock.dart';

const String _id = 'c1';

/// The thread's actions, recorded rather than sent.
class _Thread extends ConversationThreadController {
  final List<String> sent = <String>[];
  final List<String> retried = <String>[];
  final List<String> discarded = <String>[];

  /// What the next send answers.
  bool accept = true;

  @override
  ComposerState build(String conversationId) => const ComposerState();

  @override
  Future<bool> send(String body) async {
    sent.add(body);
    return accept;
  }

  @override
  Future<bool> sendDraft(AppComposerDraft draft) async {
    sent.add(draft.text);
    return accept;
  }

  @override
  Future<void> loadInitial() async {}

  @override
  Future<void> retry(Message message) async {
    retried.add(message.id);
  }

  @override
  Future<void> discard(Message message) async {
    discarded.add(message.id);
  }

  void fail(ComposerError error) => state = state.copyWith(error: error);
}

Message _message(
  String id, {
  MessageDirection direction = MessageDirection.inbound,
  MessageState state = MessageState.read,
  String body = 'Hello',
  Duration after = Duration.zero,
}) => Message(
  id: id,
  conversationId: _id,
  direction: direction,
  state: state,
  body: body,
  createdAt: testEpoch.add(after),
);

Conversation _conversation({bool archived = false}) => Conversation(
  id: _id,
  state: ConversationState.open,
  customerName: 'Sara Ahmed',
  isArchived: archived,
  createdAt: testEpoch,
);

void main() {
  late PreferencesStorage preferences;
  late StreamController<List<Message>> messages;
  late StreamController<Conversation?> conversation;
  late FakeMessageRepository messageRepository;
  _Thread? thread;

  Future<void> storeLocale(String code) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesStorage.localeKey: code,
    });
    preferences = await PreferencesStorage.open();
  }

  setUp(() {
    // Broadcast, because a retry re-subscribes to the same source.
    messages = StreamController<List<Message>>.broadcast();
    conversation = StreamController<Conversation?>.broadcast();
    messageRepository = FakeMessageRepository();
    thread = null;
  });

  tearDown(() async {
    await messages.close();
    await conversation.close();
  });

  Widget subject() => ProviderScope(
    overrides: [
      preferencesStorageProvider.overrideWithValue(preferences),
      threadMessagesProvider(_id).overrideWith((Ref ref) => messages.stream),
      threadConversationProvider(_id)
          .overrideWith((Ref ref) => conversation.stream),
      conversationThreadControllerProvider(_id)
          .overrideWith(() => thread = _Thread()),
      messageRepositoryProvider.overrideWithValue(messageRepository),
      messageMediaCoordinatorProvider.overrideWithValue(
        MessageMediaCoordinator(
          messages: messageRepository,
          remote: FakeConversationMediaRemote(),
          storage: const FileStorage(),
          logger: Logger('test', verbose: false),
        ),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(TajeerPreset.fallback, Brightness.light),
      home: const ConversationScreen(conversationId: _id),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  group('in English', () {
    setUp(() => storeLocale('en'));

    testWidgets('before the database answers, placeholder bubbles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();

      expect(find.bySemanticsLabel(appMessagesEn.loading), findsWidgets);
      expect(find.byType(AppMessageBubble), findsNothing);
    });

    testWidgets('the header is the customer, and the composer waits for them', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      // No conversation yet: a composer with nothing behind it says so.
      expect(find.byType(EditableText), findsNothing);

      conversation.add(_conversation());
      messages.add(<Message>[]);
      await settle(tester);

      expect(find.byType(AppToolbar), findsOneWidget);
      expect(find.text('Sara Ahmed'), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('an empty thread invites the first message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      messages.add(<Message>[]);
      await settle(tester);

      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.text('Send the first message in this conversation.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a thread that cannot be read offers a retry that reads again',
      (WidgetTester tester) async {
        await tester.pumpWidget(subject());
        await tester.pump();
        messages.addError(StateError('the database is locked'));
        await settle(tester);

        expect(
          find.text('This conversation could not be read.'),
          findsOneWidget,
        );
        expect(find.textContaining('locked'), findsNothing);

        await tester.tap(find.text(appMessagesEn.tryAgain));
        await tester.pump();
        messages.add(<Message>[_message('m1')]);
        await settle(tester);

        expect(find.text('Hello'), findsOneWidget);
      },
    );

    testWidgets('messages are bubbles, newest at the bottom', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      messages.add(<Message>[
        _message('m1', body: 'Is it ready?'),
        _message(
          'm2',
          direction: MessageDirection.outbound,
          body: 'Yes, today',
          after: const Duration(minutes: 1),
        ),
      ]);
      await settle(tester);

      expect(find.byType(AppMessageBubble), findsNWidgets(2));
      expect(
        tester.getCenter(find.text('Is it ready?')).dy,
        lessThan(tester.getCenter(find.text('Yes, today')).dy),
      );
    });

    testWidgets('sending goes to the controller; a refusal keeps the text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversation.add(_conversation());
      messages.add(<Message>[]);
      await settle(tester);

      thread!.accept = false;
      await tester.enterText(find.byType(EditableText), 'Order #1042');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();

      expect(thread!.sent, <String>['Order #1042']);
      expect(find.text('Order #1042'), findsOneWidget);

      thread!.accept = true;
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();
      expect(
        tester
            .widget<AppComposer>(find.byType(AppComposer))
            .controller
            .text
            .text,
        isEmpty,
      );
    });

    testWidgets('an archived conversation says why there is no composer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversation.add(_conversation(archived: true));
      messages.add(<Message>[]);
      await settle(tester);

      expect(
        find.text(
          'This conversation is archived and cannot receive new messages.',
        ),
        findsOneWidget,
      );
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('retry and discard reach the controller with their message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      messages.add(<Message>[
        _message(
          'm2',
          direction: MessageDirection.outbound,
          state: MessageState.failed,
          body: 'Order #1042',
        ),
      ]);
      await settle(tester);

      await tester.tap(find.text(appMessagesEn.retry));
      await tester.tap(find.text(appMessagesEn.discard));

      expect(thread?.retried, <String>['m2']);
      expect(thread?.discarded, <String>['m2']);
    });

    testWidgets('a long press offers copy', (WidgetTester tester) async {
      final List<MethodCall> clipboard = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            clipboard.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(subject());
      await tester.pump();
      messages.add(<Message>[_message('m1', body: 'Tracking 7788')]);
      await settle(tester);

      await tester.longPress(find.text('Tracking 7788'));
      await settle(tester);
      await tester.tap(find.text(appMessagesEn.copy));
      await settle(tester);

      expect(
        clipboard.any((MethodCall call) => call.method == 'Clipboard.setData'),
        isTrue,
      );
    });
  });

  group('in Arabic', () {
    setUp(() => storeLocale('ar'));

    testWidgets('an empty thread says so in the member\'s language', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      messages.add(<Message>[]);
      await settle(tester);

      expect(find.text('لا توجد رسائل بعد'), findsOneWidget);
      expect(find.text('أرسل أول رسالة في هذه المحادثة.'), findsOneWidget);
    });

    testWidgets('a failed send is explained in Arabic, not English', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      conversation.add(_conversation());
      messages.add(<Message>[]);
      await settle(tester);

      thread!.fail(ComposerError.offline);
      await settle(tester);

      expect(
        find.text('أنت غير متصل. ستُرسل الرسالة عند عودة الاتصال.'),
        findsOneWidget,
      );
    });
  });

  group('composerErrorFor', () {
    test('every failure the send path raises has a reason', () {
      expect(
        composerErrorFor(const ValidationFailure(message: 'too long')),
        ComposerError.refused,
      );
      expect(
        composerErrorFor(const DatabaseFailure(message: 'disk full')),
        ComposerError.notSaved,
      );
      expect(composerErrorFor(const UnknownFailure()), ComposerError.unknown);
    });
  });
}
