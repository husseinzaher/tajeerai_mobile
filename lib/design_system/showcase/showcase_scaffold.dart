import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/bidi_text.dart';
import 'showcase_section.dart';

/// Renders one section's examples.
///
/// Kept separate from the shell so a test can pump a section on its own —
/// which is what the smoke test does, across every theme, direction and text
/// scale, without driving navigation.
class ShowcaseSectionView extends StatelessWidget {
  const ShowcaseSectionView({required this.section, super.key});

  final ShowcaseSection section;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return ColoredBox(
      color: colors.background,
      child: ListView(
        padding: const EdgeInsets.all(TajeerSpacing.md),
        children: <Widget>[
          // The documentation is English on an Arabic page too. Laid out in
          // the page's direction, a sentence's full stop and brackets take the
          // wrong end of the line; AppBidiText keeps the sentence's own
          // direction and still lines it up with the page.
          AppBidiText(
            section.title,
            style: context.type.headlineLg,
            alignToAmbient: true,
          ),
          if (section.description != null) ...<Widget>[
            const SizedBox(height: TajeerSpacing.xs),
            AppBidiText(
              section.description!,
              style: context.type.bodyMd.copyWith(color: colors.textMuted),
              alignToAmbient: true,
            ),
          ],
          const SizedBox(height: TajeerSpacing.lg),
          for (final ShowcaseExample example in section.examples)
            _Example(example: example),
        ],
      ),
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({required this.example});

  final ShowcaseExample example;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TajeerSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppBidiText(
            example.name,
            style: context.type.labelMd.copyWith(color: colors.textMuted),
            alignToAmbient: true,
          ),
          if (example.description != null) ...<Widget>[
            const SizedBox(height: TajeerSpacing.xs2),
            AppBidiText(
              example.description!,
              style: context.type.bodySm.copyWith(color: colors.textMuted),
              alignToAmbient: true,
            ),
          ],
          const SizedBox(height: TajeerSpacing.xs),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: TajeerRadii.lgAll,
              border: Border.fromBorderSide(
                BorderSide(color: colors.borderSubtle),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(TajeerSpacing.md),
              child: Builder(builder: example.builder),
            ),
          ),
        ],
      ),
    );
  }
}
