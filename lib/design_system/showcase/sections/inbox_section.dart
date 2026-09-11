import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../channels/channel_descriptor.dart';
import '../../display/status_dot.dart';
import '../../feedback/async_view.dart';
import '../../feedback/connection_banner.dart';
import '../../inbox/conversation_list.dart';
import '../../inbox/conversation_list_item.dart';
import '../../inbox/conversation_summary.dart';
import '../showcase_section.dart';

/// The showcase's own "today", so a row reads the same whatever the date is.
final DateTime _now = DateTime(2026, 3, 12, 18, 30);

List<AppConversationSummary> _conversations() => <AppConversationSummary>[
  AppConversationSummary(
    id: 'c1',
    title: 'سارة أحمد',
    preview: 'هل الطلب جاهز للاستلام اليوم؟',
    lastActivityAt: DateTime(2026, 3, 12, 18, 12),
    unreadCount: 3,
    presence: AppPresence.online,
    channel: const AppChannelDescriptor(
      kind: AppChannelKind.whatsapp,
      label: 'واتساب',
    ),
  ),
  AppConversationSummary(
    id: 'c2',
    title: 'محمد العتيبي',
    preview: 'شكراً، وصلني المنتج بحالة ممتازة',
    lastActivityAt: DateTime(2026, 3, 12, 9, 41),
    isPinned: true,
    channel: const AppChannelDescriptor(
      kind: AppChannelKind.instagram,
      label: 'إنستغرام',
    ),
  ),
  AppConversationSummary(
    id: 'c3',
    title: 'Lina Hassan',
    preview: 'Can I change the delivery address before it ships?',
    lastActivityAt: DateTime(2026, 3, 11, 20, 5),
    unreadCount: 128,
    channel: const AppChannelDescriptor(
      kind: AppChannelKind.email,
      label: 'البريد الإلكتروني',
    ),
  ),
  AppConversationSummary(
    id: 'c4',
    title: 'مؤسسة النخبة للتجارة',
    preview:
        'نحتاج عرض سعر لأربعين قطعة مع التوصيل إلى الرياض قبل نهاية الأسبوع',
    lastActivityAt: DateTime(2026, 2, 28, 14),
    isMuted: true,
    channel: const AppChannelDescriptor(
      kind: AppChannelKind.sms,
      label: 'رسائل SMS',
    ),
  ),
  AppConversationSummary(
    id: 'c5',
    title: 'عميل غير معروف',
    preview: 'لا توجد رسائل بعد',
    lastActivityAt: DateTime(2025, 12, 2, 11),
  ),
];

void _noop() {}

void _open(AppConversationSummary conversation) {}

ShowcaseSection inboxSection() => ShowcaseSection(
  title: 'Inbox',
  icon: LucideIcons.inbox,
  description:
      'The Inbox, drawn from presentation data. The feature maps its '
      'conversations into AppConversationSummary; nothing here knows what a '
      'conversation is on the server.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Conversation row',
      description:
          'Unread is weight and a count, never a coloured timestamp. The '
          'channel rides on the avatar\'s corner, the time follows the title, '
          'and a screen reader hears one sentence. The second row is selected, '
          'as it would be on a tablet.',
      builder: (BuildContext context) => Column(
        children: <Widget>[
          for (final AppConversationSummary conversation in _conversations())
            AppConversationListItem(
              conversation: conversation,
              onTap: _noop,
              selected: conversation.id == 'c2',
              now: _now,
            ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Loading',
      description:
          'Placeholder rows shaped like the real ones, so nothing jumps when '
          'the first row lands.',
      builder: (BuildContext context) => const SizedBox(
        height: 260,
        child: AppConversationList(
          state: AppViewLoading<List<AppConversationSummary>>(),
          onOpen: _open,
          emptyTitle: '',
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Empty',
      description:
          'What an empty list means is the app\'s to say. It stays pullable: an '
          'empty Inbox is exactly when a member pulls to refresh.',
      builder: (BuildContext context) => SizedBox(
        height: 260,
        child: AppConversationList(
          state: const AppViewLoaded<List<AppConversationSummary>>(
            <AppConversationSummary>[],
          ),
          onOpen: _open,
          onRefresh: () async {},
          emptyTitle: 'لا توجد محادثات بعد',
          emptyDescription:
              'تظهر هنا المحادثات الجديدة عندما يتواصل معك العملاء.',
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Failed',
      description:
          'Only a failure with nothing to show is drawn as one — saved rows '
          'stay on screen when a refresh fails. This one stays pullable too.',
      builder: (BuildContext context) => SizedBox(
        height: 260,
        child: AppConversationList(
          state: const AppViewFailed<List<AppConversationSummary>>(
            'تعذّرت قراءة قائمة المحادثات.',
            onRetry: _noop,
          ),
          onOpen: _open,
          onRefresh: () async {},
          emptyTitle: '',
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Connection banner',
      description:
          'Synchronisation, not a socket. Offline is a warning, never danger: '
          'the saved data is still valid. A phase outranks the queue, and '
          'nothing is drawn when there is nothing to say.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppConnectionBanner(status: AppConnectionStatus.syncing),
          AppConnectionBanner(status: AppConnectionStatus.offline),
          AppConnectionBanner(status: AppConnectionStatus.failed),
          AppConnectionBanner(status: AppConnectionStatus.current, pending: 2),
          AppConnectionBanner(status: AppConnectionStatus.current, failed: 1),
        ],
      ),
    ),
  ],
);
