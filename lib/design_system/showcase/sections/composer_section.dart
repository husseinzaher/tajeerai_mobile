import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../buttons/app_button.dart';
import '../../channels/channel_capabilities.dart';
import '../../feedback/async_view.dart';
import '../../messaging/attachment_previews.dart';
import '../../messaging/composer.dart';
import '../../messaging/conversation_shell.dart';
import '../../messaging/message_actions.dart';
import '../../messaging/message_bubble.dart';
import '../../messaging/message_data.dart';
import '../../messaging/message_reactions.dart';
import '../../messaging/message_timeline.dart';
import '../../messaging/quick_reply_bar.dart';
import '../../messaging/reply_preview.dart';
import '../../messaging/voice_record_button.dart';
import '../../shell/toolbar.dart';
import '../showcase_fixtures.dart';
import '../showcase_section.dart';

/// Everything WhatsApp can carry, for the showcase alone.
const AppChannelCapabilities _everything = AppChannelCapabilities(
  text: true,
  images: true,
  audio: true,
  documents: true,
  reactions: true,
  replies: true,
);

const AppAttachmentData _invoice = AppAttachmentData(
  name: 'فاتورة-1042.pdf',
  sizeBytes: 482000,
  mimeType: 'application/pdf',
);

const AppAttachmentData _voiceNote = AppAttachmentData(
  name: 'voice-note.ogg',
  mimeType: 'audio/ogg',
);

void _noop() {}

Future<bool> _accept(AppComposerDraft draft) async => true;

ShowcaseSection composerSection() => ShowcaseSection(
  title: 'Composer and media',
  icon: LucideIcons.send,
  description:
      'Where a message is written, and how what it carries is drawn. The '
      'composer decides its controls from what the channel can carry, never '
      'from which channel it is.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Composer',
      description:
          'With a channel that carries files, voice and replies. Pick a '
          'suggestion to fill the field, attach a file, hold the microphone. '
          'The send arrow points the way the line runs.',
      builder: (BuildContext context) => const _ComposerDemo(),
    ),
    ShowcaseExample(
      name: 'Text only',
      description:
          'An SMS channel: words and a send button, and no code anywhere that '
          'asks whether it is SMS.',
      builder: (BuildContext context) => const _ComposerDemoTextOnly(),
    ),
    ShowcaseExample(
      name: 'Read-only',
      description:
          'A conversation that takes no messages says why, instead of a '
          'composer that silently is not there.',
      builder: (BuildContext context) => AppComposer(
        controller: AppComposerController(),
        onSend: _accept,
        enabled: false,
        disabledReason: 'هذه المحادثة مؤرشفة ولا يمكنها استقبال رسائل جديدة.',
      ),
    ),
    ShowcaseExample(
      name: 'Voice',
      description:
          'Hold to record, release to keep, slide toward the start edge to '
          'throw it away. A tap starts and stops it too, for a screen reader.',
      builder: (BuildContext context) => const _VoiceDemo(),
    ),
    ShowcaseExample(
      name: 'Replies and suggestions',
      description:
          'The quoted message, with and without a way to drop it, and the '
          'chips a member can pick instead of typing.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          const AppReplyPreview(
            reply: AppReplyData(
              authorName: ShowcaseFixtures.customer,
              text: ShowcaseFixtures.question,
            ),
            onDismiss: _noop,
          ),
          const AppReplyPreview(
            reply: AppReplyData(
              authorName: ShowcaseFixtures.latinCustomer,
              kind: AppMessageKind.image,
            ),
          ),
          AppQuickReplyBar(
            replies: const <String>[
              'أهلاً بك، كيف أقدر أساعدك؟',
              'تم شحن طلبك',
              'شكراً لتواصلك',
            ],
            onSelected: (String reply) {},
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Media in a bubble',
      description:
          'A picture reports a tap and owns no gallery; a file shows its name '
          'and size; a voice note plays through a controller the app supplies.',
      builder: (BuildContext context) => const _AudioDemo(),
    ),
    ShowcaseExample(
      name: 'Previews on their own',
      description:
          'What a bubble and the composer are built from. A picture still on '
          'this device has nothing to fetch yet; a file waiting in the '
          'composer can be taken out again; a voice note with no player is '
          'drawn, and cannot play.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppImagePreview(
            attachment: AppAttachmentData(name: 'product.jpg'),
            width: 160,
            height: 120,
          ),
          AppFilePreview(attachment: _invoice),
          AppAudioMessage(
            attachment: _voiceNote,
            duration: Duration(seconds: 42),
          ),
          AppAttachmentPreview(attachment: _invoice, onRemove: _noop),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Links and reactions',
      description:
          'A link says where it goes before it is opened. A member\'s own '
          'reaction is marked by a tint and an edge, never the tint alone.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          AppLinkPreview(
            url: Uri.parse('https://tajeerai.com/products/1042'),
            title: 'حقيبة جلدية — المقاس الكبير',
            description: 'متوفرة بثلاثة ألوان، والشحن مجاني داخل الرياض.',
            onOpen: _noop,
          ),
          AppMessageReactions(
            reactions: const <AppReactionData>[
              AppReactionData(emoji: '👍', count: 3, mine: true),
              AppReactionData(emoji: '❤️', count: 1),
            ],
            onToggle: (String emoji) {},
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Long press',
      description:
          'Copy is the design system\'s own. Reply, retry and discard appear '
          'only when the app hands them in and the message can take them.',
      builder: (BuildContext context) => const _ActionsDemo(),
    ),
    ShowcaseExample(
      name: 'The conversation',
      description:
          'AppConversationShell: the header, the thread taking the space, and '
          'the composer on the bottom edge.',
      builder: (BuildContext context) =>
          const SizedBox(height: 520, child: _ThreadDemo()),
    ),
  ],
);

class _ComposerDemoTextOnly extends StatefulWidget {
  const _ComposerDemoTextOnly();

  @override
  State<_ComposerDemoTextOnly> createState() => _ComposerDemoTextOnlyState();
}

class _ComposerDemoTextOnlyState extends State<_ComposerDemoTextOnly> {
  final AppComposerController _controller = AppComposerController(
    text: 'تم شحن طلبك اليوم',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppComposer(
    controller: _controller,
    onSend: _accept,
    capabilities: AppChannelCapabilities.textOnly,
    hintText: 'اكتب رسالة',
  );
}

class _ComposerDemo extends StatefulWidget {
  const _ComposerDemo();

  @override
  State<_ComposerDemo> createState() => _ComposerDemoState();
}

class _ComposerDemoState extends State<_ComposerDemo> {
  final AppComposerController _controller = AppComposerController()
    ..startReply(
      const AppReplyData(
        authorName: ShowcaseFixtures.customer,
        text: ShowcaseFixtures.question,
      ),
    );
  bool _recording = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppComposer(
    controller: _controller,
    onSend: _accept,
    capabilities: _everything,
    hintText: 'اكتب رسالة',
    quickReplies: const <String>['تم شحن طلبك', 'شكراً لتواصلك'],
    onAttach: () => _controller.addAttachment(_invoice),
    recording: _recording,
    recordingElapsed: const Duration(seconds: 12),
    onRecordStart: () => setState(() => _recording = true),
    onRecordStop: () => setState(() => _recording = false),
    onRecordCancel: () => setState(() => _recording = false),
  );
}

class _VoiceDemo extends StatefulWidget {
  const _VoiceDemo();

  @override
  State<_VoiceDemo> createState() => _VoiceDemoState();
}

class _VoiceDemoState extends State<_VoiceDemo> {
  bool _recording = false;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: TajeerSpacing.lg,
    children: <Widget>[
      const AppVoiceRecordButton(recording: false),
      AppVoiceRecordButton(
        recording: _recording,
        onStart: () => setState(() => _recording = true),
        onStop: () => setState(() => _recording = false),
        onCancel: () => setState(() => _recording = false),
      ),
      const AppVoiceRecordButton(recording: true, onStart: _noop),
    ],
  );
}

/// A player that only pretends: toggling flips the state and jumps halfway.
class _FakeAudio extends ChangeNotifier implements AppAudioController {
  bool _playing = false;

  @override
  AppAudioPlayback playbackOf(AppAttachmentData attachment) => AppAudioPlayback(
    playing: _playing,
    position: _playing ? const Duration(seconds: 9) : Duration.zero,
    duration: const Duration(seconds: 18),
  );

  @override
  Future<void> toggle(AppAttachmentData attachment) async {
    _playing = !_playing;
    notifyListeners();
  }
}

class _AudioDemo extends StatefulWidget {
  const _AudioDemo();

  @override
  State<_AudioDemo> createState() => _AudioDemoState();
}

class _AudioDemoState extends State<_AudioDemo> {
  final _FakeAudio _audio = _FakeAudio();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: TajeerSpacing.sm,
    children: <Widget>[
      AppMessageBubble(
        message: AppMessageData(
          id: 'i1',
          side: AppMessageSide.incoming,
          sentAt: DateTime(2026, 3, 12, 9, 13),
          kind: AppMessageKind.image,
          text: ShowcaseFixtures.photoCaption,
          attachment: const AppAttachmentData(name: 'product.jpg'),
          replyTo: const AppReplyData(
            authorName: 'أحمد',
            text: 'أرسلي لي صورة المنتج',
          ),
        ),
        onOpenAttachment: _noop,
      ),
      AppMessageBubble(
        message: AppMessageData(
          id: 'f1',
          side: AppMessageSide.outgoing,
          sentAt: DateTime(2026, 3, 12, 9, 40),
          kind: AppMessageKind.document,
          attachment: _invoice,
          status: AppMessageStatus.delivered,
          reactions: const <AppReactionData>[
            AppReactionData(emoji: '👍', count: 1),
          ],
        ),
        onOpenAttachment: _noop,
      ),
      AppMessageBubble(
        message: AppMessageData(
          id: 'a1',
          side: AppMessageSide.incoming,
          sentAt: DateTime(2026, 3, 12, 9, 41),
          kind: AppMessageKind.audio,
          attachment: _voiceNote,
        ),
        audioController: _audio,
      ),
    ],
  );
}

class _ActionsDemo extends StatelessWidget {
  const _ActionsDemo();

  @override
  Widget build(BuildContext context) => Center(
    child: AppButton(
      label: 'اضغط مطولاً على رسالة',
      variant: AppButtonVariant.outline,
      onPressed: () => AppMessageActions.show(
        context,
        message: AppMessageData(
          id: 'x1',
          side: AppMessageSide.outgoing,
          sentAt: DateTime(2026, 3, 12, 9, 31),
          text: ShowcaseFixtures.orderNumber,
          status: AppMessageStatus.notSent,
        ),
        onReply: _noop,
        onRetry: _noop,
        onDiscard: _noop,
      ),
    ),
  );
}

class _ThreadDemo extends StatefulWidget {
  const _ThreadDemo();

  @override
  State<_ThreadDemo> createState() => _ThreadDemoState();
}

class _ThreadDemoState extends State<_ThreadDemo> {
  final AppComposerController _controller = AppComposerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppConversationShell(
    toolbar: AppToolbar.conversation(
      title: ShowcaseFixtures.customer,
      subtitle: 'واتساب · المبيعات',
      onBack: _noop,
    ),
    timeline: AppMessageTimeline(
      state: AppViewLoaded<List<AppMessageData>>(<AppMessageData>[
        AppMessageData(
          id: 't1',
          side: AppMessageSide.incoming,
          sentAt: DateTime(2026, 3, 12, 9, 12),
          text: ShowcaseFixtures.question,
        ),
        AppMessageData(
          id: 't2',
          side: AppMessageSide.outgoing,
          sentAt: DateTime(2026, 3, 12, 9, 20),
          text: ShowcaseFixtures.answer,
          status: AppMessageStatus.read,
        ),
      ]),
      emptyTitle: '',
      now: DateTime(2026, 3, 12, 18, 30),
    ),
    composer: AppComposer(
      controller: _controller,
      onSend: _accept,
      hintText: 'اكتب رسالة',
    ),
  );
}
