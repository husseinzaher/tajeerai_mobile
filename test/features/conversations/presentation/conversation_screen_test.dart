import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_bubble.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_en.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/message.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/controllers/conversation_thread_controller.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/screens/conversation_screen.dart';
import 'package:tajeerai_mobile/infrastructure/storage/preferences_storage.dart';

import '../../../support/fixed_clock.dart';

const String _id = 'c1';

/// The thread's actions, recorded rather than sent.
class _Thread extends ConversationThreadController {
  final List<String> retried = <String>[];
  final List<String> discarded = <String>[];

  @override
  ComposerState build(String conversationId) => const ComposerState();

  @override
  Future<void> retry(Message message) async {
    retried.add(message.id);
  }

  @override
  Future<void> discard(Message message) async {
    discarded.add(message.id);
  }
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

void main() {
  late PreferencesStorage preferences;
  late StreamController<List<Message>> messages;
  late StreamController<Conversation?> conversation;
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
      threadConversationProvider(
        _id,
      ).overrideWith((Ref ref) => conversation.stream),
      conversationThreadControllerProvider(
        _id,
      ).overrideWith(() => thread = _Thread()),
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

      expect(find.bySemanticsLabel(appMessagesEn.loading), findsOneWidget);
      expect(find.byType(AppMessageBubble), findsNothing);
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

    testWidgets('a thread that cannot be read offers a retry that reads again', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(subject());
      await tester.pump();
      messages.addError(StateError('the database is locked'));
      await settle(tester);

      expect(find.text('This conversation could not be read.'), findsOneWidget);
      expect(find.textContaining('locked'), findsNothing);

      await tester.tap(find.text(appMessagesEn.tryAgain));
      await tester.pump();
      messages.add(<Message>[_message('m1')]);
      await settle(tester);

      expect(find.text('Hello'), findsOneWidget);
    });

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
  });
}
