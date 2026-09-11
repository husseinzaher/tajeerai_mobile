import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/localization/locale_manager.dart';
import 'package:tajeerai_mobile/app/localization/translations/app_strings.dart';
import 'package:tajeerai_mobile/design_system/feedback/connection_banner.dart';
import 'package:tajeerai_mobile/design_system/inbox/conversation_summary.dart';
import 'package:tajeerai_mobile/features/conversations/application/state/sync_state.dart';
import 'package:tajeerai_mobile/features/conversations/domain/entities/conversation.dart';
import 'package:tajeerai_mobile/features/conversations/presentation/widgets/conversation_view_data.dart';

import '../../../support/fixed_clock.dart';

const AppStrings _en = AppStrings(AppLocale.english);
const AppStrings _ar = AppStrings(AppLocale.arabic);

Conversation _conversation({
  String? customerName = 'Ada Lovelace',
  String? subject,
  String? preview = 'See you then',
  String? avatarUrl,
  DateTime? lastMessageAt,
  int unreadCount = 0,
  bool isPinned = false,
  bool isMuted = false,
}) => Conversation(
  id: 'c1',
  state: ConversationState.open,
  customerName: customerName,
  subject: subject,
  customerAvatarUrl: avatarUrl,
  lastMessagePreview: preview,
  lastMessageAt: lastMessageAt,
  unreadCount: unreadCount,
  isPinned: isPinned,
  isMuted: isMuted,
  createdAt: testEpoch,
);

void main() {
  group('Conversation.toSummary', () {
    test('a row is named for the customer', () {
      expect(_conversation().toSummary(_en).title, 'Ada Lovelace');
      expect(
        _conversation(customerName: '  Ada  ').toSummary(_en).title,
        'Ada',
      );
    });

    test('then for the thread\'s subject', () {
      for (final String? blank in <String?>[null, '', '   ']) {
        expect(
          _conversation(
            customerName: blank,
            subject: 'Order #42',
          ).toSummary(_en).title,
          'Order #42',
        );
      }
    });

    test('then in the reader\'s own words, never the domain\'s English', () {
      final Conversation nameless = _conversation(customerName: null);

      expect(nameless.toSummary(_en).title, 'Unknown customer');
      expect(nameless.toSummary(_ar).title, 'عميل غير معروف');
    });

    test('a thread with no messages says so, in the reader\'s language', () {
      expect(
        _conversation(preview: null).toSummary(_en).preview,
        _en.noMessages,
      );
      expect(
        _conversation(preview: '   ').toSummary(_ar).preview,
        _ar.noMessages,
      );
      expect(_conversation().toSummary(_en).preview, 'See you then');
    });

    test('the time is the last message, or when the thread began', () {
      final DateTime at = testEpoch.add(const Duration(hours: 3));

      expect(
        _conversation(lastMessageAt: at).toSummary(_en).lastActivityAt,
        at,
      );
      expect(_conversation().toSummary(_en).lastActivityAt, testEpoch);
    });

    test('the count and the markers carry over as they are', () {
      final AppConversationSummary summary = _conversation(
        unreadCount: 3,
        isPinned: true,
        isMuted: true,
        avatarUrl: 'https://cdn.test/ada.png',
      ).toSummary(_en);

      expect(summary.id, 'c1');
      expect(summary.unreadCount, 3);
      expect(summary.isPinned, isTrue);
      expect(summary.isMuted, isTrue);
      expect(summary.avatarUrl, 'https://cdn.test/ada.png');
      // A blank URL is no picture, not a broken one.
      expect(_conversation(avatarUrl: ' ').toSummary(_en).avatarUrl, isNull);
    });
  });

  group('ConversationSyncState.connectionStatus', () {
    test('each phase says what the banner should', () {
      const Map<SyncPhase, AppConnectionStatus> expected =
          <SyncPhase, AppConnectionStatus>{
            SyncPhase.idle: AppConnectionStatus.current,
            SyncPhase.synchronized: AppConnectionStatus.current,
            SyncPhase.syncing: AppConnectionStatus.syncing,
            SyncPhase.stale: AppConnectionStatus.offline,
            SyncPhase.failed: AppConnectionStatus.failed,
          };

      for (final SyncPhase phase in SyncPhase.values) {
        expect(
          ConversationSyncState(phase: phase).connectionStatus,
          expected[phase],
          reason: phase.name,
        );
      }
    });
  });
}
