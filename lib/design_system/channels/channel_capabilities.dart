import 'package:flutter/foundation.dart';

/// What a channel can carry.
///
/// One flag per entry in the backend's capability list
/// (`backend/src/modules/channel/contracts/capabilities.ts`), and that file's
/// own rule is the reason this type exists: branch on what a channel can do,
/// never on which channel it is. A composer offers an attachment because
/// [canAttach] is true, not because the thread is on WhatsApp, so an SMS thread
/// gets a text-only composer without an `if (sms)` anywhere.
///
/// Everything defaults to false. A channel that has not said what it supports
/// is treated as supporting nothing: a hidden control is a small loss, and a
/// control whose message never arrives is a broken promise.
@immutable
class AppChannelCapabilities {
  const AppChannelCapabilities({
    this.text = false,
    this.images = false,
    this.video = false,
    this.audio = false,
    this.documents = false,
    this.templates = false,
    this.buttons = false,
    this.lists = false,
    this.reactions = false,
    this.readReceipts = false,
    this.typingIndicator = false,
    this.location = false,
    this.replies = false,
  });

  /// Text and nothing else — what an SMS channel carries.
  static const AppChannelCapabilities textOnly = AppChannelCapabilities(
    text: true,
  );

  final bool text;
  final bool images;
  final bool video;

  /// A voice note. The composer's microphone follows this flag.
  final bool audio;

  final bool documents;

  /// A message approved in advance by the provider.
  final bool templates;

  final bool buttons;
  final bool lists;
  final bool reactions;
  final bool readReceipts;
  final bool typingIndicator;
  final bool location;

  /// Quoting a message in the answer to it.
  final bool replies;

  /// Whether the composer offers an attachment at all: a picture, a video or a
  /// file. A voice note is not an attachment here; it has its own control.
  bool get canAttach => images || video || documents;

  @override
  bool operator ==(Object other) =>
      other is AppChannelCapabilities &&
      other.text == text &&
      other.images == images &&
      other.video == video &&
      other.audio == audio &&
      other.documents == documents &&
      other.templates == templates &&
      other.buttons == buttons &&
      other.lists == lists &&
      other.reactions == reactions &&
      other.readReceipts == readReceipts &&
      other.typingIndicator == typingIndicator &&
      other.location == location &&
      other.replies == replies;

  @override
  int get hashCode => Object.hash(
    text,
    images,
    video,
    audio,
    documents,
    templates,
    buttons,
    lists,
    reactions,
    readReceipts,
    typingIndicator,
    location,
    replies,
  );
}
