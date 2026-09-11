import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/theme/theme.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_badge.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_capabilities.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_descriptor.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_glyph.dart';
import 'package:tajeerai_mobile/design_system/channels/channel_palette.dart';
import 'package:tajeerai_mobile/design_system/display/status_dot.dart';

import '../../../tool/tokens/token_manifest.dart';
import '../../support/widget_harness.dart';

double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

const AppChannelDescriptor _sales = AppChannelDescriptor(
  kind: AppChannelKind.whatsapp,
  label: 'WhatsApp',
  name: 'Sales',
  color: Color(0xFF3B82F6),
);

void main() {
  group('AppChannelCapabilities', () {
    test('a channel that says nothing supports nothing', () {
      const AppChannelCapabilities nothing = AppChannelCapabilities();

      expect(nothing.text, isFalse);
      expect(nothing.canAttach, isFalse);
      expect(AppChannelCapabilities.textOnly.text, isTrue);
      expect(AppChannelCapabilities.textOnly.canAttach, isFalse);
    });

    test('attaching follows pictures, video and files — never voice', () {
      expect(const AppChannelCapabilities(images: true).canAttach, isTrue);
      expect(const AppChannelCapabilities(video: true).canAttach, isTrue);
      expect(const AppChannelCapabilities(documents: true).canAttach, isTrue);
      expect(const AppChannelCapabilities(audio: true).canAttach, isFalse);
    });

    test('equality sees every flag', () {
      // Thirteen single-flag values must be thirteen different values. An
      // `==` that forgot a field makes two of them collapse into one here.
      const List<AppChannelCapabilities> single = <AppChannelCapabilities>[
        AppChannelCapabilities(text: true),
        AppChannelCapabilities(images: true),
        AppChannelCapabilities(video: true),
        AppChannelCapabilities(audio: true),
        AppChannelCapabilities(documents: true),
        AppChannelCapabilities(templates: true),
        AppChannelCapabilities(buttons: true),
        AppChannelCapabilities(lists: true),
        AppChannelCapabilities(reactions: true),
        AppChannelCapabilities(readReceipts: true),
        AppChannelCapabilities(typingIndicator: true),
        AppChannelCapabilities(location: true),
        AppChannelCapabilities(replies: true),
      ];

      expect(single.toSet(), hasLength(single.length));
      expect(
        AppChannelCapabilities.textOnly,
        const AppChannelCapabilities(text: true),
      );
      expect(
        AppChannelCapabilities.textOnly.hashCode,
        const AppChannelCapabilities(text: true).hashCode,
      );
    });
  });

  group('AppChannelDescriptor', () {
    test('its title names the kind, then which one', () {
      expect(_sales.title, 'WhatsApp · Sales');
      expect(
        const AppChannelDescriptor(
          kind: AppChannelKind.sms,
          label: 'SMS',
        ).title,
        'SMS',
      );
      expect(
        const AppChannelDescriptor(
          kind: AppChannelKind.sms,
          label: 'SMS',
          name: '',
        ).title,
        'SMS',
      );
    });

    test('two descriptions of the same channel are equal', () {
      const AppChannelDescriptor same = AppChannelDescriptor(
        kind: AppChannelKind.whatsapp,
        label: 'WhatsApp',
        name: 'Sales',
        color: Color(0xFF3B82F6),
      );

      expect(same, _sales);
      expect(same.hashCode, _sales.hashCode);
      expect(
        _sales,
        isNot(
          const AppChannelDescriptor(
            kind: AppChannelKind.whatsapp,
            label: 'WhatsApp',
            name: 'Sales',
            color: Color(0xFF3B82F6),
            capabilities: AppChannelCapabilities.textOnly,
          ),
        ),
      );
    });
  });

  group('AppChannelGlyph', () {
    testWidgets(
      'each kind is its own glyph in its own colour, in both themes',
      (WidgetTester tester) async {
        for (final AppChannelKind kind in AppChannelKind.values) {
          await pumpInBothThemes(tester, AppChannelGlyph(kind: kind), (
            WidgetTester tester,
            Brightness brightness,
          ) async {
            final Icon icon = tester.widget<Icon>(find.byType(Icon));
            final TajeerChannelColors channels = brightness == Brightness.dark
                ? TajeerChannelColors.dark
                : TajeerChannelColors.light;

            expect(icon.icon, AppChannelGlyph.iconFor(kind), reason: kind.name);
            expect(
              icon.color,
              AppChannelGlyph.colorsFor(channels, kind).$1,
              reason: '${kind.name} in ${brightness.name}',
            );
          });
        }
      },
    );

    test('the kinds that share a glyph never share a colour', () {
      const List<AppChannelKind> sharing = <AppChannelKind>[
        AppChannelKind.instagram,
        AppChannelKind.messenger,
        AppChannelKind.liveChat,
      ];

      for (final TajeerChannelColors channels in <TajeerChannelColors>[
        TajeerChannelColors.light,
        TajeerChannelColors.dark,
      ]) {
        expect(
          sharing
              .map((AppChannelKind kind) => AppChannelGlyph.iconFor(kind))
              .toSet(),
          hasLength(1),
        );
        expect(
          sharing
              .map(
                (AppChannelKind kind) =>
                    AppChannelGlyph.colorsFor(channels, kind).$1,
              )
              .toSet(),
          hasLength(sharing.length),
        );
      }
    });

    testWidgets('contained, it sits on its wash inside a cutout ring', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppChannelGlyph(
              kind: AppChannelKind.whatsapp,
              contained: true,
            ),
          ),
        ),
      );

      final BoxDecoration decoration =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(AppChannelGlyph),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      final BuildContext context = tester.element(find.byType(AppChannelGlyph));

      expect(decoration.color, context.channels.whatsappSoft);
      expect((decoration.border! as Border).top.color, context.colors.surface);
    });

    testWidgets('it speaks only when nothing beside it names the channel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(child: AppChannelGlyph(kind: AppChannelKind.email)),
        ),
      );
      expect(find.bySemanticsLabel('Email'), findsNothing);

      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppChannelGlyph(
              kind: AppChannelKind.email,
              semanticLabel: 'Email',
            ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Email'), findsOneWidget);
    });
  });

  group('AppChannelBadge', () {
    testWidgets('reads as one phrase to a screen reader', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(const Center(child: AppChannelBadge(channel: _sales))),
      );

      expect(find.bySemanticsLabel('WhatsApp · Sales'), findsOneWidget);
    });

    testWidgets('draws a dot only when there is a colour to show', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(const Center(child: AppChannelBadge(channel: _sales))),
      );
      expect(find.byType(AppStatusDot), findsOneWidget);

      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppChannelBadge(
              channel: AppChannelDescriptor(
                kind: AppChannelKind.sms,
                label: 'SMS',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(AppStatusDot), findsNothing);
    });

    testWidgets('the text stays ink; the colour is in the dot and the tint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: AppChannelBadge(
              channel: _sales,
              emphasis: AppChannelBadgeEmphasis.pill,
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(AppChannelBadge));
      final BoxDecoration pill =
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: find.byType(AppChannelBadge),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;

      expect(
        tester.widget<Text>(find.text('WhatsApp · Sales')).style?.color,
        context.colors.textPrimary,
      );
      expect(
        pill.color,
        AppChannelBadge.tintFor(_sales.color!, context.colors.surface),
      );
    });

    testWidgets('the glyph leads, from the start edge in both directions', (
      WidgetTester tester,
    ) async {
      await pumpInBothDirections(
        tester,
        const Center(child: AppChannelBadge(channel: _sales)),
        (WidgetTester tester, TextDirection direction) async {
          final double glyph = tester
              .getCenter(find.byType(AppChannelGlyph))
              .dx;
          final double text = tester
              .getCenter(find.text('WhatsApp · Sales'))
              .dx;

          expect(
            glyph,
            direction == TextDirection.rtl ? greaterThan(text) : lessThan(text),
          );
        },
      );
    });

    testWidgets('a long name ends in an ellipsis, not an overflow', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(
          const Center(
            child: SizedBox(
              width: 160,
              child: AppChannelBadge(
                channel: AppChannelDescriptor(
                  kind: AppChannelKind.whatsapp,
                  label: 'WhatsApp',
                  name: 'The Riyadh sales line, second number',
                  color: Color(0xFFA96CAF),
                ),
                emphasis: AppChannelBadgeEmphasis.pill,
              ),
            ),
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('ink keeps body-text contrast on every tint, preset and theme', () {
      for (final String presetName in TokenManifest.presets) {
        for (final Brightness brightness in Brightness.values) {
          final TajeerColors colors = TajeerPalette.of(
            TajeerPreset.fromName(presetName),
            brightness,
          ).colors;

          for (int slot = 0; slot < AppChannelPalette.colors.length; slot++) {
            final Color tint = AppChannelBadge.tintFor(
              AppChannelPalette.colors[slot],
              colors.surface,
            );
            final double ratio = _contrast(colors.textPrimary, tint);

            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$presetName/${brightness.name} textPrimary on the slot '
                  '$slot tint is ${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
    });
  });
}
