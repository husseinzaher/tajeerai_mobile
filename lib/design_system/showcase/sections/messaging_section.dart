import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../display/labelled_separator.dart';
import '../../feedback/async_view.dart';
import '../../messaging/day_and_system_lines.dart';
import '../../messaging/message_bubble.dart';
import '../../messaging/message_data.dart';
import '../../messaging/message_status_icon.dart';
import '../../messaging/message_timeline.dart';
import '../../messaging/typing_indicator.dart';
import '../showcase_fixtures.dart';
import '../showcase_section.dart';

/// The showcase's own "today", so day headings read the same on any date.
final DateTime _now = DateTime(2026, 3, 12, 18, 30);

List<AppMessageData> _thread() => <AppMessageData>[
  AppMessageData(
    id: 'm1',
    side: AppMessageSide.incoming,
    sentAt: DateTime(2026, 3, 11, 21, 4),
    text: 'مساء الخير، هل يتوفر المقاس الكبير؟',
  ),
  AppMessageData(
    id: 'm2',
    side: AppMessageSide.outgoing,
    sentAt: DateTime(2026, 3, 11, 21, 9),
    text: 'أهلاً سارة، نعم متوفر بثلاثة ألوان.',
    status: AppMessageStatus.read,
  ),
  AppMessageData(
    id: 'm3',
    side: AppMessageSide.incoming,
    sentAt: DateTime(2026, 3, 11, 21, 20),
    kind: AppMessageKind.system,
    text: 'أُسندت المحادثة إلى أحمد',
  ),
  AppMessageData(
    id: 'm4',
    side: AppMessageSide.incoming,
    sentAt: DateTime(2026, 3, 12, 9, 12),
    text: 'تمام، أرسلت لكم صورة المنتج',
  ),
  AppMessageData(
    id: 'm5',
    side: AppMessageSide.incoming,
    sentAt: DateTime(2026, 3, 12, 9, 13),
    kind: AppMessageKind.image,
    text: ShowcaseFixtures.photoCaption,
  ),
  AppMessageData(
    id: 'm6',
    side: AppMessageSide.incoming,
    sentAt: DateTime(2026, 3, 12, 9, 14),
    text: 'Is it available for delivery today?',
  ),
  AppMessageData(
    id: 'm7',
    side: AppMessageSide.outgoing,
    sentAt: DateTime(2026, 3, 12, 9, 30),
    text: ShowcaseFixtures.answer,
    status: AppMessageStatus.delivered,
  ),
  AppMessageData(
    id: 'm8',
    side: AppMessageSide.outgoing,
    sentAt: DateTime(2026, 3, 12, 9, 31),
    text: ShowcaseFixtures.orderNumber,
    status: AppMessageStatus.notSent,
  ),
  AppMessageData(
    id: 'm9',
    side: AppMessageSide.outgoing,
    sentAt: DateTime(2026, 3, 12, 18, 20),
    text: 'شكراً لتسوقك معنا',
    status: AppMessageStatus.queued,
    isFromBot: true,
  ),
];

void _noop() {}

void _ignore(AppMessageData message) {}

ShowcaseSection messagingSection() => ShowcaseSection(
  title: 'Messaging',
  icon: LucideIcons.messageSquareText,
  description:
      'A thread, drawn from presentation data. AppTimelineBuilder decides the '
      'day headings, the unread marker and the runs; the bubble draws one '
      'message; the timeline draws the list, newest at the bottom.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Timeline',
      description:
          'Two days, a system line that belongs to neither side, a run broken '
          'by the unread marker, an English message keeping its own direction, '
          'a failed send with its actions, and somebody typing.',
      builder: (BuildContext context) => SizedBox(
        height: 680,
        child: AppMessageTimeline(
          state: AppViewLoaded<List<AppMessageData>>(_thread()),
          emptyTitle: '',
          unreadCount: 2,
          typing: true,
          typingName: 'سارة',
          onRetry: _ignore,
          onDiscard: _ignore,
          now: _now,
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Runs and the tail',
      description:
          'The corner nearest the speaker is tightened on every bubble — the '
          'tail, without drawing one — and so is the join inside a run. Only '
          'the last bubble of a run carries the time.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.xs2,
        children: <Widget>[
          AppMessageBubble(
            message: AppMessageData(
              id: 'r1',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 12),
              text: 'السلام عليكم',
            ),
            endsRun: false,
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'r2',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 12),
              text: 'عندي استفسار عن الطلب',
            ),
            startsRun: false,
            endsRun: false,
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'r3',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 13),
              text: 'رقمه 1042',
            ),
            startsRun: false,
          ),
          const SizedBox(height: TajeerSpacing.sm),
          AppMessageBubble(
            message: AppMessageData(
              id: 'r4',
              side: AppMessageSide.outgoing,
              sentAt: DateTime(2026, 3, 12, 9, 20),
              text: 'وعليكم السلام، أبشر',
              status: AppMessageStatus.read,
            ),
            endsRun: false,
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'r5',
              side: AppMessageSide.outgoing,
              sentAt: DateTime(2026, 3, 12, 9, 20),
              text: 'الطلب في الطريق إليك',
              status: AppMessageStatus.read,
            ),
            startsRun: false,
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Delivery',
      description:
          'Sent, delivered and read speak through their ticks. The states a '
          'member waits on or acts on also say so in words.',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.md,
        runSpacing: TajeerSpacing.sm,
        children: <Widget>[
          for (final AppMessageStatus status in AppMessageStatus.values)
            if (status != AppMessageStatus.none)
              AppMessageStatusIcon(status: status),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'When a send fails',
      description:
          'Outlined in danger, said in words, and retry and discard offered as '
          'buttons.',
      builder: (BuildContext context) => AppMessageBubble(
        message: AppMessageData(
          id: 'f1',
          side: AppMessageSide.outgoing,
          sentAt: DateTime(2026, 3, 12, 9, 31),
          text: ShowcaseFixtures.orderNumber,
          status: AppMessageStatus.notSent,
        ),
        onRetry: _noop,
        onDiscard: _noop,
      ),
    ),
    ShowcaseExample(
      name: 'Media, before its preview',
      description:
          'A labelled line with its caption, until the previews arrive. A '
          'message this build cannot draw says so rather than drawing nothing.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppMessageBubble(
            message: AppMessageData(
              id: 'p1',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 13),
              kind: AppMessageKind.image,
              text: ShowcaseFixtures.photoCaption,
            ),
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'p2',
              side: AppMessageSide.outgoing,
              sentAt: DateTime(2026, 3, 12, 9, 40),
              kind: AppMessageKind.document,
              status: AppMessageStatus.sent,
            ),
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'p3',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 41),
              kind: AppMessageKind.audio,
            ),
          ),
          AppMessageBubble(
            message: AppMessageData(
              id: 'p4',
              side: AppMessageSide.incoming,
              sentAt: DateTime(2026, 3, 12, 9, 42),
              kind: AppMessageKind.unsupported,
            ),
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Days, unread and system lines',
      description:
          'Day headings are headings to a screen reader, so a long thread can '
          'be moved through by day.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppDateSeparator(day: DateTime(2026, 3, 12), now: _now),
          AppDateSeparator(day: DateTime(2026, 3, 11), now: _now),
          AppDateSeparator(day: DateTime(2026, 2, 3), now: _now),
          const AppLabelledSeparator(
            label: '2 غير مقروءة',
            tone: AppSeparatorTone.primary,
          ),
          const AppSystemMessage(
            text: 'أُسندت المحادثة إلى أحمد',
            icon: LucideIcons.userCheck,
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Typing',
      description:
          'Where their message is about to land. Still under reduced motion; '
          'announced as a live region.',
      builder: (BuildContext context) => const AppTypingIndicator(name: 'سارة'),
    ),
    ShowcaseExample(
      name: 'Loading, empty, failed',
      description:
          'The same four states as every list, with placeholder bubbles on '
          'alternating sides while the database answers.',
      builder: (BuildContext context) => const Column(
        spacing: TajeerSpacing.md,
        children: <Widget>[
          SizedBox(
            height: 200,
            child: AppMessageTimeline(
              state: AppViewLoading<List<AppMessageData>>(),
              emptyTitle: '',
            ),
          ),
          SizedBox(
            height: 220,
            child: AppMessageTimeline(
              state: AppViewLoaded<List<AppMessageData>>(<AppMessageData>[]),
              emptyTitle: 'لا توجد رسائل بعد',
              emptyDescription: 'أرسل أول رسالة في هذه المحادثة.',
            ),
          ),
          SizedBox(
            height: 240,
            child: AppMessageTimeline(
              state: AppViewFailed<List<AppMessageData>>(
                'تعذّرت قراءة هذه المحادثة.',
                onRetry: _noop,
              ),
              emptyTitle: '',
            ),
          ),
        ],
      ),
    ),
  ],
);
