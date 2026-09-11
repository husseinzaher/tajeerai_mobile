import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/buttons/app_button.dart';
import 'package:tajeerai_mobile/design_system/feedback/async_view.dart';
import 'package:tajeerai_mobile/design_system/localization/ds_messages_en.dart';
import 'package:tajeerai_mobile/design_system/messaging/attachment_previews.dart';
import 'package:tajeerai_mobile/design_system/messaging/composer.dart';
import 'package:tajeerai_mobile/design_system/messaging/conversation_shell.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_actions.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_bubble.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_data.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_reactions.dart';
import 'package:tajeerai_mobile/design_system/messaging/message_timeline.dart';
import 'package:tajeerai_mobile/design_system/messaging/reply_preview.dart';
import 'package:tajeerai_mobile/design_system/shell/toolbar.dart';

import '../../support/widget_harness.dart';

/// A player that records what it was asked to do.
class _FakeAudio extends ChangeNotifier implements AppAudioController {
  final List<AppAttachmentData> toggled = <AppAttachmentData>[];
  bool playing = false;

  @override
  AppAudioPlayback playbackOf(AppAttachmentData attachment) => AppAudioPlayback(
    playing: playing,
    position: const Duration(seconds: 5),
    duration: const Duration(seconds: 20),
  );

  @override
  Future<void> toggle(AppAttachmentData attachment) async {
    toggled.add(attachment);
    playing = !playing;
    notifyListeners();
  }
}

const AppAttachmentData _voice = AppAttachmentData(name: 'note.ogg');

void main() {
  group('AppFileSize', () {
    test('bytes, then kilobytes, then megabytes, in Latin digits', () {
      expect(AppFileSize.format(512), '512 B');
      expect(AppFileSize.format(2048), '2.0 KB');
      expect(AppFileSize.format(482000), '471 KB');
      expect(AppFileSize.format(2500000), '2.4 MB');
      expect(AppFileSize.format(5 * 1024 * 1024 * 1024), '5.0 GB');
    });
  });

  group('AppAudioPlayback', () {
    test('progress is unknown until the length is', () {
      expect(const AppAudioPlayback().progress, isNull);
      expect(
        const AppAudioPlayback(
          position: Duration(seconds: 5),
          duration: Duration(seconds: 20),
        ).progress,
        0.25,
      );
      expect(AppAudioPlayback.clock(const Duration(seconds: 75)), '1:15');
    });
  });

  group('previews', () {
    testWidgets(
      'a picture not yet uploaded is a placeholder that still opens',
      (WidgetTester tester) async {
        int opened = 0;
        await tester.pumpWidget(
          wrapWidget(
            Center(
              child: AppImagePreview(
                attachment: const AppAttachmentData(name: 'product.jpg'),
                onOpen: () => opened++,
              ),
            ),
          ),
        );

        expect(find.byIcon(LucideIcons.image), findsOneWidget);
        tester.semantics.tap(find.semantics.byLabel('product.jpg'));
        expect(opened, 1);
      },
    );

    testWidgets('a file shows its name and size, and reads as both', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppFilePreview(
              attachment: AppAttachmentData(
                name: 'invoice.pdf',
                sizeBytes: 482000,
                mimeType: 'application/pdf',
              ),
            ),
          ),
        ),
      );

      expect(find.text('invoice.pdf'), findsOneWidget);
      expect(find.text('471 KB'), findsOneWidget);
      expect(find.bySemanticsLabel('invoice.pdf, 471 KB'), findsOneWidget);
      // Identifiers, left to right in either language: in Arabic a size laid
      // out right to left reads "KB 471".
      expect(
        tester.widget<Text>(find.text('471 KB')).textDirection,
        TextDirection.ltr,
      );
      expect(
        tester.widget<Text>(find.text('invoice.pdf')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('a voice note plays through the app\'s controller', (
      WidgetTester tester,
    ) async {
      final _FakeAudio audio = _FakeAudio();
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        wrapWidget(
          Center(
            child: AppAudioMessage(attachment: _voice, controller: audio),
          ),
        ),
      );

      expect(find.text('0:20'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.play));
      await tester.pump();

      expect(audio.toggled, <AppAttachmentData>[_voice]);
      expect(find.byIcon(LucideIcons.pause), findsOneWidget);
      expect(find.text('0:05'), findsOneWidget);
    });

    testWidgets('without a controller a voice note is drawn and cannot play', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppAudioMessage(
              attachment: _voice,
              duration: Duration(seconds: 7),
            ),
          ),
        ),
      );

      expect(find.text('0:07'), findsOneWidget);
      expect(
        tester
            .widget<AppButton>(find.widgetWithIcon(AppButton, LucideIcons.play))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a link says where it goes, and opens', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await tester.pumpWidget(
        wrapWidget(
          Center(
            child: AppLinkPreview(
              url: Uri.parse('https://tajeerai.com/p/1042'),
              title: 'Leather bag',
              onOpen: () => opened++,
            ),
          ),
        ),
      );

      expect(find.text('tajeerai.com'), findsOneWidget);
      await tester.tap(find.text('Leather bag'));
      expect(opened, 1);
    });

    testWidgets('the quote names who is being answered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const AppReplyPreview(
            reply: AppReplyData(authorName: 'Sara', kind: AppMessageKind.image),
          ),
        ),
      );

      expect(find.text('Sara'), findsOneWidget);
      expect(find.text(appMessagesEn.photo), findsOneWidget);
      expect(
        find.bySemanticsLabel('Replying to Sara, ${appMessagesEn.photo}'),
        findsOneWidget,
      );
    });
  });

  group('AppMessageReactions', () {
    testWidgets('a member\'s own reaction reads as theirs, and toggles', (
      WidgetTester tester,
    ) async {
      final List<String> toggled = <String>[];
      await tester.pumpWidget(
        wrapWidget(
          AppMessageReactions(
            reactions: const <AppReactionData>[
              AppReactionData(emoji: '👍', count: 3, mine: true),
              AppReactionData(emoji: '❤️', count: 1),
            ],
            onToggle: toggled.add,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('👍 3, ${appMessagesEn.youReacted}'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('❤️ 1'), findsOneWidget);

      await tester.tap(find.text('❤️'));
      expect(toggled, <String>['❤️']);
    });
  });

  group('AppMessageBubble with what a message carries', () {
    testWidgets('a reply quotes, a file previews, reactions sit underneath', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: AppMessageData(
              id: 'm1',
              side: AppMessageSide.outgoing,
              sentAt: DateTime(2026, 3, 12, 9, 40),
              kind: AppMessageKind.document,
              attachment: const AppAttachmentData(name: 'invoice.pdf'),
              replyTo: const AppReplyData(authorName: 'Sara', text: 'Invoice?'),
              reactions: const <AppReactionData>[
                AppReactionData(emoji: '👍', count: 1),
              ],
              status: AppMessageStatus.delivered,
            ),
            onOpenAttachment: () => opened++,
          ),
        ),
      );

      expect(find.byType(AppReplyPreview), findsOneWidget);
      expect(find.byType(AppFilePreview), findsOneWidget);
      expect(find.byType(AppMessageReactions), findsOneWidget);

      await tester.tap(find.text('invoice.pdf'));
      expect(opened, 1);
    });

    testWidgets('a picture type with no file stays a labelled line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          AppMessageBubble(
            message: AppMessageData(
              id: 'm1',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 40),
              kind: AppMessageKind.image,
            ),
          ),
        ),
      );

      expect(find.byType(AppImagePreview), findsNothing);
      expect(find.text(appMessagesEn.photo), findsOneWidget);
    });
  });

  group('AppMessageActions', () {
    late List<MethodCall> clipboard;

    setUp(() {
      clipboard = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
            MethodCall call,
          ) async {
            clipboard.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Widget opener(
      AppMessageData message, {
      VoidCallback? onRetry,
      VoidCallback? onDiscard,
    }) => wrapWidget(
      Builder(
        builder: (BuildContext context) => Center(
          child: AppButton(
            label: 'open',
            onPressed: () => AppMessageActions.show(
              context,
              message: message,
              onRetry: onRetry,
              onDiscard: onDiscard,
            ),
          ),
        ),
      ),
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('copy puts the words on the clipboard and says so', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        opener(
          AppMessageData(
            id: 'm1',
            side: AppMessageSide.incoming,
            sentAt: DateTime(2026, 3, 12, 9),
            text: 'Order #1042',
          ),
        ),
      );
      await open(tester);

      // Retry and discard belong to a failed send, not to this one.
      expect(find.text(appMessagesEn.retry), findsNothing);
      await tester.tap(find.text(appMessagesEn.copy));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        clipboard.where((MethodCall c) => c.method == 'Clipboard.setData'),
        hasLength(1),
      );
      expect(
        (clipboard.last.arguments as Map<Object?, Object?>)['text'],
        'Order #1042',
      );
      expect(find.text(appMessagesEn.copied), findsOneWidget);
    });

    testWidgets('a failed send offers retry and discard', (
      WidgetTester tester,
    ) async {
      int retried = 0;
      await tester.pumpWidget(
        opener(
          AppMessageData(
            id: 'm1',
            side: AppMessageSide.outgoing,
            sentAt: DateTime(2026, 3, 12, 9),
            text: 'Order #1042',
            status: AppMessageStatus.notSent,
          ),
          onRetry: () => retried++,
          onDiscard: () {},
        ),
      );
      await open(tester);

      expect(find.text(appMessagesEn.discard), findsOneWidget);
      await tester.tap(find.text(appMessagesEn.retry));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('a message with nothing to offer opens nothing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        opener(
          AppMessageData(
            id: 'm1',
            side: AppMessageSide.incoming,
            sentAt: DateTime(2026, 3, 12, 9),
            kind: AppMessageKind.image,
          ),
        ),
      );
      await open(tester);

      expect(find.text(appMessagesEn.cancel), findsNothing);
    });
  });

  group('AppConversationShell', () {
    testWidgets('the thread takes the space; the composer sits under it', (
      WidgetTester tester,
    ) async {
      final AppComposerController controller = AppComposerController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrapWidget(
          AppConversationShell(
            toolbar: AppToolbar.conversation(title: 'Sara'),
            timeline: const AppMessageTimeline(
              state: AppViewLoaded<List<AppMessageData>>(<AppMessageData>[]),
              emptyTitle: 'No messages yet',
            ),
            composer: AppComposer(
              controller: controller,
              onSend: (AppComposerDraft draft) async => true,
            ),
          ),
        ),
      );

      final Rect header = tester.getRect(find.byType(AppToolbar));
      final Rect thread = tester.getRect(find.byType(AppMessageTimeline));
      final Rect composer = tester.getRect(find.byType(AppComposer));

      expect(header.bottom, lessThanOrEqualTo(thread.top));
      expect(thread.bottom, lessThanOrEqualTo(composer.top));
      expect(thread.height, greaterThan(composer.height));
      expect(tester.takeException(), isNull);
      expect(find.byType(AppToolbar), findsOneWidget);
      expect(tester.element(find.byType(AppComposer)).colors, isNotNull);
    });
  });
}
