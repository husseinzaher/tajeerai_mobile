import 'package:flutter/foundation.dart';

import 'message_data.dart';

/// One thing the timeline draws.
sealed class AppTimelineEntry {
  const AppTimelineEntry();
}

/// The start of a day: "Today", "Yesterday", or a date.
final class AppTimelineDay extends AppTimelineEntry {
  const AppTimelineDay(this.day);

  /// Local midnight.
  final DateTime day;

  @override
  bool operator ==(Object other) => other is AppTimelineDay && other.day == day;

  @override
  int get hashCode => day.hashCode;
}

/// Where the unread messages begin.
final class AppTimelineUnread extends AppTimelineEntry {
  const AppTimelineUnread(this.count);

  final int count;

  @override
  bool operator ==(Object other) =>
      other is AppTimelineUnread && other.count == count;

  @override
  int get hashCode => count.hashCode;
}

/// One message, and where it sits in a run from the same author.
@immutable
final class AppTimelineMessage extends AppTimelineEntry {
  const AppTimelineMessage(
    this.message, {
    required this.startsRun,
    required this.endsRun,
  });

  final AppMessageData message;
  final bool startsRun;
  final bool endsRun;

  @override
  bool operator ==(Object other) =>
      other is AppTimelineMessage &&
      other.message == message &&
      other.startsRun == startsRun &&
      other.endsRun == endsRun;

  @override
  int get hashCode => Object.hash(message, startsRun, endsRun);
}

/// Turns a thread's messages into what the timeline draws: day headings, the
/// unread marker, and runs.
///
/// Pure, on purpose. Day boundaries, runs and the unread marker are the subtle
/// part of a message list, and here they are tested without pumping a widget.
abstract final class AppTimelineBuilder {
  /// Messages from one author, on one side, closer together than this, draw as
  /// one run.
  static const Duration runWindow = Duration(minutes: 5);

  /// [messages] must be oldest first. [unreadCount] counts the newest incoming
  /// messages that are unread; the marker goes before the oldest of them.
  static List<AppTimelineEntry> build(
    List<AppMessageData> messages, {
    int unreadCount = 0,
    Duration window = runWindow,
  }) {
    final int? firstUnread = _firstUnread(messages, unreadCount);
    final List<AppTimelineEntry> entries = <AppTimelineEntry>[];

    for (int index = 0; index < messages.length; index++) {
      final AppMessageData message = messages[index];
      final AppMessageData? previous = index > 0 ? messages[index - 1] : null;
      final AppMessageData? next = index + 1 < messages.length
          ? messages[index + 1]
          : null;

      if (previous == null || _day(previous.sentAt) != _day(message.sentAt)) {
        entries.add(AppTimelineDay(_day(message.sentAt)));
      }
      if (index == firstUnread) {
        entries.add(AppTimelineUnread(unreadCount));
      }

      entries.add(
        AppTimelineMessage(
          message,
          // The unread marker breaks a run: the member has to see where the
          // new part starts, even inside one author's burst.
          startsRun:
              previous == null ||
              index == firstUnread ||
              !_joins(previous, message, window),
          endsRun:
              next == null ||
              index + 1 == firstUnread ||
              !_joins(message, next, window),
        ),
      );
    }

    return entries;
  }

  static bool _joins(AppMessageData a, AppMessageData b, Duration window) =>
      a.kind != AppMessageKind.system &&
      b.kind != AppMessageKind.system &&
      a.side == b.side &&
      a.authorId == b.authorId &&
      a.authorName == b.authorName &&
      a.isFromBot == b.isFromBot &&
      _day(a.sentAt) == _day(b.sentAt) &&
      b.sentAt.difference(a.sentAt).abs() <= window;

  static int? _firstUnread(List<AppMessageData> messages, int unreadCount) {
    if (unreadCount <= 0) {
      return null;
    }

    int? oldest;
    int seen = 0;
    for (int index = messages.length - 1; index >= 0; index--) {
      final AppMessageData message = messages[index];
      if (message.side != AppMessageSide.incoming ||
          message.kind == AppMessageKind.system) {
        continue;
      }
      oldest = index;
      seen++;
      if (seen == unreadCount) {
        break;
      }
    }
    // Fewer incoming messages on the device than the count: every one of them
    // is unread, so the marker sits before the oldest.
    return oldest;
  }

  /// Calendar days in local time: 23:59 and 00:01 are different days.
  static DateTime _day(DateTime at) {
    final DateTime local = at.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
