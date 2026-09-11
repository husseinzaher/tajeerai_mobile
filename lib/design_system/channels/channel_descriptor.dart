import 'package:flutter/widgets.dart';

import 'channel_capabilities.dart';

/// Which kind of channel something arrived on, as far as drawing it goes.
///
/// Six, not the backend's seven channel types. WhatsApp through the Cloud API
/// and WhatsApp through a linked phone are two transports for one identity a
/// member recognises, and the design system draws identities. Which transport
/// a channel uses is the feature's business: it maps the backend's type onto
/// one of these.
enum AppChannelKind { whatsapp, sms, email, instagram, messenger, liveChat }

/// One channel, described for drawing: its kind, what it is called, its
/// colour, and what it can carry.
///
/// Plain data a feature builds from its own channel records, the way
/// `AppNavDestination` is built from routes. The design system never learns
/// what a channel looks like on the server.
@immutable
class AppChannelDescriptor {
  const AppChannelDescriptor({
    required this.kind,
    required this.label,
    this.name,
    this.color,
    this.capabilities = const AppChannelCapabilities(),
  });

  final AppChannelKind kind;

  /// The kind's name in the reader's language — "WhatsApp", "واتساب". Passed
  /// in, because product copy belongs to the app and not to the design system.
  final String label;

  /// Which one of several — "Sales", "سيرفر السعودية". Absent when the
  /// workspace has one channel of this kind, or the member may not see names.
  final String? name;

  /// The instance colour: the server's resolved colour, or
  /// `AppChannelPalette.autoColorFor` for a channel known only by its id.
  /// Null draws no dot, rather than a grey one that means nothing.
  final Color? color;

  final AppChannelCapabilities capabilities;

  /// "WhatsApp · Sales", or the label alone when there is no name to add.
  String get title {
    final String? instance = name;
    return instance == null || instance.isEmpty ? label : '$label · $instance';
  }

  @override
  bool operator ==(Object other) =>
      other is AppChannelDescriptor &&
      other.kind == kind &&
      other.label == label &&
      other.name == name &&
      other.color == color &&
      other.capabilities == capabilities;

  @override
  int get hashCode => Object.hash(kind, label, name, color, capabilities);
}
