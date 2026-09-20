import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/design_system/channels/channel_capabilities.dart';
import 'package:TajeerAi/design_system/display/chip.dart';
import 'package:TajeerAi/design_system/localization/ds_messages_en.dart';
import 'package:TajeerAi/design_system/messaging/attachment_previews.dart';
import 'package:TajeerAi/design_system/messaging/composer.dart';
import 'package:TajeerAi/design_system/messaging/message_data.dart';
import 'package:TajeerAi/design_system/messaging/quick_reply_bar.dart';
import 'package:TajeerAi/design_system/messaging/reply_preview.dart';
import 'package:TajeerAi/design_system/messaging/voice_record_button.dart';

import '../../support/widget_harness.dart';

const AppChannelCapabilities _everything = AppChannelCapabilities(
  text: true,
  images: true,
  audio: true,
  documents: true,
  replies: true,
);

const AppAttachmentData _invoice = AppAttachmentData(
  name: 'invoice.pdf',
  sizeBytes: 482000,
  mimeType: 'application/pdf',
);

const AppReplyData _quote = AppReplyData(
  authorName: 'Sara',
  text: 'Is it ready?',
);

void main() {
  group('AppComposerController', () {
    test('whitespace is not a message; a file is', () {
      final AppComposerController controller = AppComposerController();
      addTearDown(controller.dispose);

      expect(controller.canSend, isFalse);
      controller.text.text = '   ';
      expect(controller.canSend, isFalse);
      controller.addAttachment(_invoice);
      expect(controller.canSend, isTrue);
    });

    test('a draft is the words, the quote and the files together', () {
      final AppComposerController controller = AppComposerController(
        text: 'Here it is',
      )..startReply(_quote);
      addTearDown(controller.dispose);
      controller.addAttachment(_invoice);

      final AppComposerDraft draft = controller.draft;
      expect(draft.text, 'Here it is');
      expect(draft.replyTo, _quote);
      expect(draft.attachments, <AppAttachmentData>[_invoice]);

      controller.clear();
      expect(controller.text.text, isEmpty);
      expect(controller.replyTo, isNull);
      expect(controller.attachments, isEmpty);
    });

    test('removing takes out one file, and only that one', () {
      final AppComposerController controller = AppComposerController();
      addTearDown(controller.dispose);
      const AppAttachmentData other = AppAttachmentData(name: 'photo.jpg');
      controller
        ..addAttachment(_invoice)
        ..addAttachment(other)
        ..removeAttachment(_invoice);

      expect(controller.attachments, <AppAttachmentData>[other]);
      // Removing what is not there changes nothing.
      controller.removeAttachment(_invoice);
      expect(controller.attachments, <AppAttachmentData>[other]);
    });
  });

  group('AppComposer', () {
    late AppComposerController controller;

    setUp(() => controller = AppComposerController());
    tearDown(() => controller.dispose());

    Widget composer({
      required Future<bool> Function(AppComposerDraft draft) onSend,
      AppChannelCapabilities capabilities = AppChannelCapabilities.textOnly,
      bool enabled = true,
      String? disabledReason,
      VoidCallback? onAttach,
      VoidCallback? onRecordStart,
      ValueChanged<bool>? onTypingChanged,
      List<String> quickReplies = const <String>[],
      TextDirection direction = TextDirection.ltr,
    }) => wrapWidget(
      Align(
        alignment: Alignment.bottomCenter,
        child: AppComposer(
          controller: controller,
          onSend: onSend,
          capabilities: capabilities,
          enabled: enabled,
          disabledReason: disabledReason,
          onAttach: onAttach,
          onRecordStart: onRecordStart,
          onTypingChanged: onTypingChanged,
          quickReplies: quickReplies,
          hintText: 'Write a message',
        ),
      ),
      textDirection: direction,
    );

    testWidgets('send waits for words, and an accepted send empties it', (
      WidgetTester tester,
    ) async {
      final List<String> sent = <String>[];
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async {
            sent.add(draft.text);
            return true;
          },
        ),
      );

      await tester.tap(find.byIcon(LucideIcons.send));
      expect(sent, isEmpty);

      await tester.enterText(find.byType(EditableText), 'On its way');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();

      expect(sent, <String>['On its way']);
      expect(controller.text.text, isEmpty);
    });

    testWidgets('a refused send keeps what was typed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        composer(onSend: (AppComposerDraft draft) async => false),
      );

      await tester.enterText(find.byType(EditableText), 'Not lost');
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();

      expect(controller.text.text, 'Not lost');
    });

    testWidgets('typing is reported when it starts and stops, not per key', (
      WidgetTester tester,
    ) async {
      final List<bool> typing = <bool>[];
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          onTypingChanged: typing.add,
        ),
      );

      await tester.enterText(find.byType(EditableText), 'H');
      await tester.enterText(find.byType(EditableText), 'He');
      await tester.enterText(find.byType(EditableText), 'Hel');
      await tester.enterText(find.byType(EditableText), '');

      expect(typing, <bool>[true, false]);
    });

    testWidgets('the controls come from capabilities, not from a channel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          onAttach: () {},
          onRecordStart: () {},
        ),
      );
      // Text only: no paperclip and no microphone, however the app is wired.
      expect(find.byIcon(LucideIcons.paperclip), findsNothing);
      expect(find.byType(AppVoiceRecordButton), findsNothing);

      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          capabilities: _everything,
          onAttach: () {},
          onRecordStart: () {},
        ),
      );
      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
      // With nothing typed the microphone stands where send would.
      expect(find.byType(AppVoiceRecordButton), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'Hello');
      await tester.pump();
      expect(find.byType(AppVoiceRecordButton), findsNothing);
      expect(find.byIcon(LucideIcons.send), findsOneWidget);
    });

    testWidgets('a channel that carries files still needs an app that picks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          capabilities: _everything,
        ),
      );

      expect(find.byIcon(LucideIcons.paperclip), findsNothing);
      expect(find.byType(AppVoiceRecordButton), findsNothing);
    });

    testWidgets(
      'the quote shows only where replies exist, and can be dropped',
      (WidgetTester tester) async {
        controller.startReply(_quote);

        await tester.pumpWidget(
          composer(onSend: (AppComposerDraft draft) async => true),
        );
        expect(find.byType(AppReplyPreview), findsNothing);

        await tester.pumpWidget(
          composer(
            onSend: (AppComposerDraft draft) async => true,
            capabilities: _everything,
          ),
        );
        expect(find.byType(AppReplyPreview), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(AppReplyPreview),
            matching: find.byIcon(LucideIcons.x),
          ),
        );
        await tester.pump();
        expect(controller.replyTo, isNull);
        expect(find.byType(AppReplyPreview), findsNothing);
      },
    );

    testWidgets('files waiting to go can be taken out again', (
      WidgetTester tester,
    ) async {
      controller.addAttachment(_invoice);
      await tester.pumpWidget(
        composer(onSend: (AppComposerDraft draft) async => true),
      );

      expect(find.byType(AppAttachmentPreview), findsOneWidget);
      expect(find.text('471 KB'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(appMessagesEn.remove));
      await tester.pump();
      expect(controller.attachments, isEmpty);
    });

    testWidgets('a suggestion fills the field instead of sending', (
      WidgetTester tester,
    ) async {
      int sends = 0;
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async {
            sends++;
            return true;
          },
          quickReplies: const <String>['Shipped today'],
        ),
      );

      expect(find.byType(AppQuickReplyBar), findsOneWidget);
      await tester.tap(find.widgetWithText(AppChip, 'Shipped today'));
      await tester.pump();

      expect(controller.text.text, 'Shipped today');
      expect(sends, 0);
    });

    testWidgets('disabled, it says why instead of vanishing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          enabled: false,
          disabledReason: 'This conversation is archived.',
        ),
      );
      expect(find.text('This conversation is archived.'), findsOneWidget);
      expect(find.byType(EditableText), findsNothing);

      await tester.pumpWidget(
        composer(
          onSend: (AppComposerDraft draft) async => true,
          enabled: false,
        ),
      );
      expect(find.text(appMessagesEn.readOnly), findsOneWidget);
    });

    testWidgets(
      'send sits at the end edge, and its arrow turns with the line',
      (WidgetTester tester) async {
        for (final TextDirection direction in TextDirection.values) {
          await tester.pumpWidget(
            composer(
              onSend: (AppComposerDraft draft) async => true,
              direction: direction,
            ),
          );
          await tester.pump();

          final double send = tester
              .getCenter(find.byIcon(LucideIcons.send))
              .dx;
          final double field = tester.getCenter(find.byType(EditableText)).dx;
          final bool rtl = direction == TextDirection.rtl;

          expect(send, rtl ? lessThan(field) : greaterThan(field));
          expect(
            tester
                .widget<Transform>(
                  find
                      .ancestor(
                        of: find.byIcon(LucideIcons.send),
                        matching: find.byType(Transform),
                      )
                      .first,
                )
                .transform
                .storage
                .first,
            rtl ? -1 : 1,
          );
        }
      },
    );
  });

  group('AppVoiceRecordButton', () {
    Future<void> hold(WidgetTester tester, {Offset slide = Offset.zero}) async {
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byType(AppVoiceRecordButton)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      if (slide != Offset.zero) {
        await gesture.moveBy(slide);
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
    }

    Widget button({
      bool recording = false,
      required List<String> events,
      TextDirection direction = TextDirection.ltr,
    }) => wrapWidget(
      Center(
        child: AppVoiceRecordButton(
          recording: recording,
          onStart: () => events.add('start'),
          onStop: () => events.add('stop'),
          onCancel: () => events.add('cancel'),
        ),
      ),
      textDirection: direction,
    );

    testWidgets('hold records, and letting go keeps it', (
      WidgetTester tester,
    ) async {
      final List<String> events = <String>[];
      await tester.pumpWidget(button(events: events));

      await hold(tester);

      expect(events, <String>['start', 'stop']);
    });

    testWidgets(
      'sliding toward the start edge throws it away — in Arabic too',
      (WidgetTester tester) async {
        for (final (TextDirection direction, Offset toward)
            in <(TextDirection, Offset)>[
              (TextDirection.ltr, const Offset(-120, 0)),
              (TextDirection.rtl, const Offset(120, 0)),
            ]) {
          final List<String> events = <String>[];
          await tester.pumpWidget(button(events: events, direction: direction));

          await hold(tester, slide: toward);

          expect(events, <String>['start', 'cancel'], reason: direction.name);
        }
      },
    );

    testWidgets('sliding the other way does not cancel', (
      WidgetTester tester,
    ) async {
      final List<String> events = <String>[];
      await tester.pumpWidget(button(events: events));

      await hold(tester, slide: const Offset(120, 0));

      expect(events, <String>['start', 'stop']);
    });

    testWidgets('a tap starts and a tap stops, for a reader that cannot hold', (
      WidgetTester tester,
    ) async {
      final List<String> events = <String>[];
      await tester.pumpWidget(button(events: events));
      await tester.tap(find.byType(AppVoiceRecordButton));

      await tester.pumpWidget(button(events: events, recording: true));
      await tester.tap(find.byType(AppVoiceRecordButton));

      expect(events, <String>['start', 'stop']);
      expect(find.bySemanticsLabel(appMessagesEn.recording), findsOneWidget);
    });
  });
}
