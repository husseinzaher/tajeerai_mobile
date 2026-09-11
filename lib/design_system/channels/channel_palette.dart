import 'dart:ui';

/// The colours a channel *instance* takes when nobody picked one.
///
/// A mirror of the backend's `CHANNEL_COLOR_PALETTE` and `autoChannelColor`
/// (`backend/src/modules/channel/contracts/channel-color.ts`): the same ten
/// colours in the same order, and the same hash over the id. It has to match
/// exactly, or one channel is green on the web and pink on a phone, and "Sales
/// is always the green one" — the only reason the palette exists — stops being
/// true. Change the two together.
///
/// **Not a token.** `design/tokens.json` holds what this app decides; this list
/// is decided by the backend and copied here, like a protocol constant. Putting
/// it in the token file would make it look like mobile's to change.
///
/// **Prefer the server's colour.** The API sends each channel's resolved
/// colour, including a merchant's own choice, which no hash can know. This is
/// the fallback for a channel the device knows only by its id.
///
/// Not the named identities in `context.channels`, either. Those say which
/// *kind* a channel is — WhatsApp is green. These tell apart which *one* of a
/// workspace's several numbers it is.
abstract final class AppChannelPalette {
  static const List<Color> colors = <Color>[
    Color(0xFFF97316), // orange
    Color(0xFFA96CAF), // mauve
    Color(0xFF84CC16), // lime
    Color(0xFF06B6D4), // cyan
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFFD946EF), // fuchsia
    Color(0xFFEC4899), // pink
    Color(0xFF64748B), // slate
    Color(0xFF0D9488), // teal
  ];

  /// The palette index for [channelId].
  ///
  /// Walks runes, not UTF-16 code units: the backend iterates the id with
  /// `for…of`, which yields whole code points, so an id outside the Basic
  /// Multilingual Plane would land on a different slot if this walked units.
  static int slotFor(String channelId) {
    int hash = 0;
    for (final int rune in channelId.runes) {
      hash = (hash * 31 + rune) % 1000003;
    }
    return hash % colors.length;
  }

  static Color autoColorFor(String channelId) => colors[slotFor(channelId)];

  /// The merchant's choice when there is one, the automatic colour otherwise —
  /// the backend's `resolveChannelColor`, on the device.
  static Color resolve(String channelId, {Color? chosen}) =>
      chosen ?? autoColorFor(channelId);
}
