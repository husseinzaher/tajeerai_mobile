import 'package:flutter/foundation.dart';

/// The strings the design system renders on its own behalf.
///
/// The dividing line, and it is the whole design: **anything a consumer can
/// pass stays a prop; only what a component has no way to receive lives here.**
/// A button's label is a parameter. The word "Cancel" on a confirmation dialog
/// the component builds itself is not — nobody is holding a reference to it.
///
/// Nothing about a customer, a plan, an order or a conversation will ever
/// appear in this file. Those belong to the app's own copy.
///
/// Plain strings rather than functions, so the tables read as translation
/// tables and a translator can edit them; the two that take a number go
/// through [interpolate].
@immutable
class AppMessages {
  const AppMessages({
    required this.close,
    required this.loading,
    required this.more,
    required this.dismiss,
    required this.cancel,
    required this.confirm,
    required this.back,
    required this.menu,
    required this.search,
    required this.clearSearch,
    required this.noMatches,
    required this.select,
    required this.selectedCount,
    required this.showPassword,
    required this.hidePassword,
    required this.required,
    required this.optional,
    required this.tryAgain,
    required this.somethingWentWrong,
    required this.retry,
    required this.discard,
    required this.send,
    required this.attach,
    required this.recordVoice,
    required this.typing,
    required this.typingName,
    required this.photo,
    required this.video,
    required this.voiceMessage,
    required this.document,
    required this.location,
    required this.unsupportedMessage,
    required this.bot,
    required this.copy,
    required this.copied,
    required this.reply,
    required this.replyingTo,
    required this.remove,
    required this.play,
    required this.pause,
    required this.recording,
    required this.slideToCancel,
    required this.readOnly,
    required this.youReacted,
    required this.suggestedReplies,
    required this.today,
    required this.yesterday,
    required this.queued,
    required this.sending,
    required this.notSent,
    required this.sent,
    required this.delivered,
    required this.readReceipt,
    required this.removed,
    required this.unreadCount,
    required this.failedCount,
    required this.pinned,
    required this.muted,
    required this.sendingCount,
    required this.notSentCount,
    required this.offline,
    required this.reconnecting,
    required this.syncing,
    required this.showingSaved,
    required this.syncFailed,
  });

  // Chrome.
  final String close;
  final String loading;
  final String more;
  final String dismiss;
  final String cancel;
  final String confirm;
  final String back;
  final String menu;

  // Search and selection.
  final String search;
  final String clearSearch;
  final String noMatches;
  final String select;

  /// Takes `{count}` — what a toolbar in selection mode says.
  final String selectedCount;

  // Fields.
  final String showPassword;
  final String hidePassword;
  final String required;
  final String optional;

  // Failure.
  final String tryAgain;
  final String somethingWentWrong;
  final String retry;
  final String discard;

  // Messaging.
  final String send;
  final String attach;
  final String recordVoice;
  final String typing;

  /// Takes `{name}`.
  final String typingName;

  /// What a media message is, while its preview is not drawn.
  final String photo;
  final String video;
  final String voiceMessage;
  final String document;
  final String location;
  final String unsupportedMessage;

  /// Who wrote a message the assistant sent.
  final String bot;

  // Composing and acting on a message.
  final String copy;
  final String copied;
  final String reply;

  /// Takes `{name}`.
  final String replyingTo;

  final String remove;
  final String play;
  final String pause;
  final String recording;
  final String slideToCancel;

  /// Why a composer is not there: the conversation takes no new messages.
  final String readOnly;

  final String youReacted;
  final String suggestedReplies;
  final String today;
  final String yesterday;

  /// Delivery states. `readReceipt` rather than `read`, because `read` is a
  /// reserved-feeling name next to `required` and reads as a verb here.
  final String queued;
  final String sending;
  final String notSent;
  final String sent;
  final String delivered;
  final String readReceipt;
  final String removed;

  /// Takes `{count}`.
  final String unreadCount;

  /// How many messages in a thread did not go out. `{count}`.
  final String failedCount;

  /// A row kept at the top, and a row whose notifications are off.
  final String pinned;
  final String muted;

  /// Take `{count}`: changes still on their way out, and changes that gave up.
  final String sendingCount;
  final String notSentCount;

  // Connection.
  final String offline;
  final String reconnecting;
  final String syncing;
  final String showingSaved;

  /// The last catch-up failed, said where there is no room for the banner's
  /// longer way of putting it.
  final String syncFailed;

  /// Fills `{name}` placeholders.
  ///
  /// An unmatched placeholder is left standing rather than blanked: a visible
  /// `{count}` is a bug report, and an empty space is a mystery.
  static String interpolate(String template, Map<String, Object?> values) {
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (Match match) {
      final Object? value = values[match.group(1)];
      return value == null ? match.group(0)! : '$value';
    });
  }
}
