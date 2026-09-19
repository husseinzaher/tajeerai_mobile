import 'package:flutter/foundation.dart';

/// Which side of the thread a message is drawn on.
///
/// `incoming` and `outgoing`, not the domain's `inbound` and `outbound` — on
/// purpose. If the two vocabularies matched name for name, the next person
/// would "simplify" by deleting one, and the design system would be importing
/// the domain again. They answer different questions: the domain's is which
/// way a message travelled, this one is which side to draw it on.
enum AppMessageSide { incoming, outgoing }

/// What a message is, as far as drawing it goes.
enum AppMessageKind {
  text,
  image,
  video,
  audio,
  document,
  location,

  /// A line about the conversation rather than in it: an assignment, a handover.
  system,

  /// Something this build has no way to draw.
  unsupported,
}

/// What a message's delivery glyph says.
///
/// Not the domain's `MessageState`. That one serves the outbox — whether a
/// message is in flight, whether it may be retried — and this one decides which
/// glyph to draw. They diverge the first time the domain gains a state that
/// draws exactly like another.
enum AppMessageStatus {
  /// Incoming messages, which have no delivery of ours to report.
  none,
  queued,
  sending,
  notSent,
  sent,
  delivered,
  read,
  removed,
}

/// A file a message carries.
@immutable
class AppAttachmentData {
  const AppAttachmentData({
    this.url,
    this.localPath,
    this.posterPath,
    this.name,
    this.sizeBytes,
    this.mimeType,
  });

  final String? url;

  /// Set while an outgoing file has not left the device yet.
  final String? localPath;

  /// A generated still frame for video attachments.
  final String? posterPath;

  final String? name;
  final int? sizeBytes;
  final String? mimeType;

  @override
  bool operator ==(Object other) =>
      other is AppAttachmentData &&
      other.url == url &&
      other.localPath == localPath &&
      other.posterPath == posterPath &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.mimeType == mimeType;

  @override
  int get hashCode =>
      Object.hash(url, localPath, posterPath, name, sizeBytes, mimeType);
}

/// The message a reply quotes.
@immutable
class AppReplyData {
  const AppReplyData({
    required this.authorName,
    this.text,
    this.kind = AppMessageKind.text,
  });

  final String authorName;
  final String? text;
  final AppMessageKind kind;

  @override
  bool operator ==(Object other) =>
      other is AppReplyData &&
      other.authorName == authorName &&
      other.text == text &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(authorName, text, kind);
}

/// One reaction on a message: the emoji, how many chose it, and whether this
/// member is one of them.
@immutable
class AppReactionData {
  const AppReactionData({
    required this.emoji,
    required this.count,
    this.mine = false,
  });

  final String emoji;
  final int count;
  final bool mine;

  @override
  bool operator ==(Object other) =>
      other is AppReactionData &&
      other.emoji == emoji &&
      other.count == count &&
      other.mine == mine;

  @override
  int get hashCode => Object.hash(emoji, count, mine);
}

/// One message, as the thread draws it.
///
/// Presentation data, not the domain's `Message` — the same boundary the Inbox
/// works through with `AppConversationSummary`. The feature maps into this.
@immutable
class AppMessageData {
  const AppMessageData({
    required this.id,
    required this.side,
    required this.sentAt,
    this.kind = AppMessageKind.text,
    this.text,
    this.status = AppMessageStatus.none,
    this.authorId,
    this.authorName,
    this.isFromBot = false,
    this.attachment,
    this.replyTo,
    this.reactions = const <AppReactionData>[],
  });

  final String id;
  final AppMessageSide side;
  final DateTime sentAt;
  final AppMessageKind kind;

  /// The words, or a media message's caption.
  final String? text;

  final AppMessageStatus status;

  /// Who wrote it. Two messages from different authors never share a run.
  final String? authorId;

  /// Shown over the first bubble of a run, when the app chooses to name the
  /// author at all.
  final String? authorName;

  final bool isFromBot;
  final AppAttachmentData? attachment;
  final AppReplyData? replyTo;

  /// In the order to draw them.
  final List<AppReactionData> reactions;

  /// Whether the bubble offers a retry.
  bool get canRetry => status == AppMessageStatus.notSent;

  @override
  bool operator ==(Object other) =>
      other is AppMessageData &&
      other.id == id &&
      other.side == side &&
      other.sentAt == sentAt &&
      other.kind == kind &&
      other.text == text &&
      other.status == status &&
      other.authorId == authorId &&
      other.authorName == authorName &&
      other.isFromBot == isFromBot &&
      other.attachment == attachment &&
      other.replyTo == replyTo &&
      listEquals(other.reactions, reactions);

  @override
  int get hashCode => Object.hash(
    id,
    side,
    sentAt,
    kind,
    text,
    status,
    authorId,
    authorName,
    isFromBot,
    attachment,
    replyTo,
    Object.hashAll(reactions),
  );
}
