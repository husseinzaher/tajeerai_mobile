import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/caller_id/domain/entities/caller_id_settings.dart';

void main() {
  group('CallerIdSettings', () {
    test('defaults keep caller id disabled until the member turns it on', () {
      const CallerIdSettings settings = CallerIdSettings();

      expect(settings.enabled, isFalse);
      expect(settings.showIncoming, isTrue);
      expect(settings.showOutgoing, isTrue);
      expect(settings.autoDismissSeconds, 15);
    });

    test('shouldShowFor respects direction and unknown-only filters', () {
      const CallerIdSettings settings = CallerIdSettings(
        enabled: true,
        showIncoming: true,
        showOutgoing: false,
        showOnlyUnknown: true,
      );

      expect(settings.shouldShowFor(isIncoming: true, isKnownContact: false), isTrue);
      expect(settings.shouldShowFor(isIncoming: true, isKnownContact: true), isFalse);
      expect(settings.shouldShowFor(isIncoming: false, isKnownContact: false), isFalse);
    });

    test('round-trips through json without losing values', () {
      const CallerIdSettings original = CallerIdSettings(
        enabled: true,
        showIncoming: false,
        showOutgoing: true,
        showOnlyUnknown: true,
        autoDismissSeconds: 30,
        cardPosition: CallerCardPosition.bottom,
        cardSize: CallerCardLayout.full,
      );

      final CallerIdSettings restored = CallerIdSettings.fromJson(original.toJson());

      expect(restored.enabled, original.enabled);
      expect(restored.showIncoming, original.showIncoming);
      expect(restored.showOutgoing, original.showOutgoing);
      expect(restored.showOnlyUnknown, original.showOnlyUnknown);
      expect(restored.autoDismissSeconds, original.autoDismissSeconds);
      expect(restored.cardPosition, original.cardPosition);
      expect(restored.cardSize, original.cardSize);
    });
  });
}
