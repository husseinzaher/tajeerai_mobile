import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../showcase_section.dart';

/// The tokens, drawn from the same maps the components read.
///
/// The colour grid iterates `TajeerColors.asMap`, which is generated, so a
/// token added to `design/tokens.json` appears here without anybody
/// remembering to add it. A hand-listed grid is a grid that is missing the
/// newest colour.
ShowcaseSection foundationsSection() => ShowcaseSection(
  title: 'Foundations',
  icon: LucideIcons.palette,
  description:
      'Every value here comes from design/tokens.json. Nothing on this page is '
      'written twice.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Palette',
      description:
          'The active preset, in the active appearance. Switch either with the '
          'controls above and every swatch follows.',
      builder: (BuildContext context) => _Swatches(context.colors.asMap),
    ),
    ShowcaseExample(
      name: 'Channels',
      description:
          'Shared by every preset: a channel identity does not change because '
          'the app changed accent. None of them is the brand colour.',
      builder: (BuildContext context) => _Swatches(context.channels.asMap),
    ),
    ShowcaseExample(
      name: 'Type scale',
      description:
          'Fourteen steps, tuned for Arabic: more leading than a Latin scale, '
          'and zero tracking on every step because the script joins.',
      builder: (BuildContext context) => const _TypeScale(),
    ),
    ShowcaseExample(
      name: 'Spacing',
      builder: (BuildContext context) => const _Scale(
        values: <String, double>{
          '2xs': TajeerSpacing.xs2,
          'xs': TajeerSpacing.xs,
          'sm': TajeerSpacing.sm,
          'md': TajeerSpacing.md,
          'lg': TajeerSpacing.lg,
          'xl': TajeerSpacing.xl,
          '2xl': TajeerSpacing.xl2,
          '3xl': TajeerSpacing.xl3,
          '4xl': TajeerSpacing.xl4,
        },
      ),
    ),
    ShowcaseExample(
      name: 'Radii',
      builder: (BuildContext context) => const _Radii(),
    ),
    ShowcaseExample(
      name: 'Elevation',
      description:
          'Each level is a tone, a hairline and a shadow together. In light the '
          'tone holds and the shadow carries the level; in dark the shadow is '
          'nearly invisible and the tone carries it.',
      builder: (BuildContext context) => const _Elevation(),
    ),
  ],
);

class _Swatches extends StatelessWidget {
  const _Swatches(this.colors);

  final Map<String, Color> colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TajeerSpacing.xs,
      runSpacing: TajeerSpacing.xs,
      children: <Widget>[
        for (final MapEntry<String, Color> entry in colors.entries)
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: TajeerRadii.smAll,
                    border: Border.fromBorderSide(
                      BorderSide(color: context.colors.borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: TajeerSpacing.xs2),
                Text(
                  entry.key,
                  style: context.type.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final TajeerTypeScale type = context.type;
    final Map<String, TextStyle> steps = <String, TextStyle>{
      'display': type.display,
      'headlineXl': type.headlineXl,
      'headlineLg': type.headlineLg,
      'headlineMd': type.headlineMd,
      'titleLg': type.titleLg,
      'titleMd': type.titleMd,
      'titleSm': type.titleSm,
      'bodyLg': type.bodyLg,
      'bodyMd': type.bodyMd,
      'bodySm': type.bodySm,
      'labelLg': type.labelLg,
      'labelMd': type.labelMd,
      'labelSm': type.labelSm,
      'caption': type.caption,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        for (final MapEntry<String, TextStyle> step in steps.entries)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${step.key} · ${step.value.fontSize?.toStringAsFixed(0)}',
                style: context.type.caption.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              Text('تواصل. إدارة. نمو. — Aa', style: step.value),
            ],
          ),
      ],
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.values});

  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        for (final MapEntry<String, double> entry in values.entries)
          Row(
            spacing: TajeerSpacing.sm,
            children: <Widget>[
              SizedBox(
                width: 64,
                child: Text(
                  '${entry.key} · ${entry.value.toStringAsFixed(0)}',
                  style: context.type.caption,
                ),
              ),
              Container(
                width: entry.value,
                height: 12,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: TajeerRadii.xsAll,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Radii extends StatelessWidget {
  const _Radii();

  @override
  Widget build(BuildContext context) {
    const Map<String, BorderRadius> radii = <String, BorderRadius>{
      'xs': TajeerRadii.xsAll,
      'sm': TajeerRadii.smAll,
      'md': TajeerRadii.mdAll,
      'lg': TajeerRadii.lgAll,
      'xl': TajeerRadii.xlAll,
      '2xl': TajeerRadii.xl2All,
      'full': TajeerRadii.fullAll,
    };

    return Wrap(
      spacing: TajeerSpacing.xs,
      runSpacing: TajeerSpacing.xs,
      children: <Widget>[
        for (final MapEntry<String, BorderRadius> entry in radii.entries)
          Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.colors.primarySoft,
                  borderRadius: entry.value,
                  border: Border.fromBorderSide(
                    BorderSide(color: context.colors.primaryBorder),
                  ),
                ),
              ),
              const SizedBox(height: TajeerSpacing.xs2),
              Text(entry.key, style: context.type.caption),
            ],
          ),
      ],
    );
  }
}

class _Elevation extends StatelessWidget {
  const _Elevation();

  @override
  Widget build(BuildContext context) {
    final TajeerElevations elevations = context.elevation;
    final Map<String, TajeerElevation> levels = <String, TajeerElevation>{
      'none': elevations.none,
      'subtle': elevations.subtle,
      'card': elevations.card,
      'floating': elevations.floating,
      'popover': elevations.popover,
      'modal': elevations.modal,
    };

    return Wrap(
      spacing: TajeerSpacing.md,
      runSpacing: TajeerSpacing.md,
      children: <Widget>[
        for (final MapEntry<String, TajeerElevation> entry in levels.entries)
          Container(
            width: 96,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: entry.value.tone,
              borderRadius: TajeerRadii.lgAll,
              border: Border.fromBorderSide(
                BorderSide(color: entry.value.hairline),
              ),
              boxShadow: entry.value.shadow,
            ),
            child: Text(entry.key, style: context.type.caption),
          ),
      ],
    );
  }
}
