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
    required this.offline,
    required this.reconnecting,
    required this.syncing,
    required this.showingSaved,
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

  // Connection.
  final String offline;
  final String reconnecting;
  final String syncing;
  final String showingSaved;

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
