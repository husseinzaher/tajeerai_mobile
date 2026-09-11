import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_palette.dart';

/// The mirror of `backend/src/modules/channel/contracts/channel-color.ts`.
///
/// Nothing here reads the backend's file: a submodule checkout does not have
/// it, and a test that skips itself when a sibling directory is missing is the
/// test this codebase already deleted once. The backend's spec pins the same
/// ids to the same slots instead, so the two sides fail in step.
void main() {
  test('the ten colours are the backend\'s, in the backend\'s order', () {
    expect(
      AppChannelPalette.colors.map((Color color) => color.toARGB32()),
      <int>[
        0xFFF97316, // orange
        0xFFA96CAF, // mauve
        0xFF84CC16, // lime
        0xFF06B6D4, // cyan
        0xFF3B82F6, // blue
        0xFF8B5CF6, // violet
        0xFFD946EF, // fuchsia
        0xFFEC4899, // pink
        0xFF64748B, // slate
        0xFF0D9488, // teal
      ],
    );
  });

  test('every id lands on the slot the backend puts it in', () {
    // Produced by running the backend's own `autoChannelColor`, and pinned by
    // its spec under "lands known ids on the slots the mobile mirror expects".
    const Map<String, int> slots = <String, int>{
      '11111111-1111-4111-8111-111111111111': 5,
      '22222222-2222-4222-8222-222222222222': 4,
      '33333333-3333-4333-8333-333333333333': 3,
      '44444444-4444-4444-8444-444444444444': 2,
      '55555555-5555-4555-8555-555555555555': 1,
      '9b2f6c1e-0d4a-4f7b-9e3c-6a1d2b3c4d5e': 2,
      // Arabic, and a character outside the Basic Multilingual Plane: the
      // backend walks code points, and so must this.
      'قناة-المبيعات': 6,
      'sales-📱': 6,
      '': 0,
    };

    slots.forEach((String id, int slot) {
      expect(AppChannelPalette.slotFor(id), slot, reason: id);
      expect(
        AppChannelPalette.autoColorFor(id),
        AppChannelPalette.colors[slot],
      );
    });
  });

  test('a merchant\'s choice wins over the automatic colour', () {
    const String id = '22222222-2222-4222-8222-222222222222';
    const Color chosen = Color(0xFF111111);

    expect(AppChannelPalette.resolve(id, chosen: chosen), chosen);
    expect(AppChannelPalette.resolve(id), AppChannelPalette.autoColorFor(id));
  });
}
