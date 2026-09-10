import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'field_scaffold.dart';

/// One choice in an [AppRadioGroup].
@immutable
class AppRadioOption<T> {
  const AppRadioOption({
    required this.value,
    required this.label,
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final bool enabled;
}

/// A set of mutually exclusive choices.
///
/// The group is the widget, not the individual radio, because a lone radio has
/// no meaning: "exclusive" is a property of the set. It is also what lets the
/// group announce `inMutuallyExclusiveGroup` to a screen reader, which a row of
/// unrelated toggles cannot.
class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final List<AppRadioOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppFieldScaffold(
      label: label,
      errorText: errorText,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AppRadioOption<T> option in options)
            _Option<T>(
              option: option,
              selected: option.value == value,
              enabled: enabled && option.enabled && onChanged != null,
              onTap: () => onChanged?.call(option.value),
            ),
        ],
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AppRadioOption<T> option;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: enabled,
      label: option.label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  AnimatedContainer(
                    duration: context.motion.fast,
                    curve: context.motion.standard,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: selected
                              ? colors.primaryBorder
                              : colors.borderStrong,
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: context.motion.fast,
                        curve: context.motion.standard,
                        width: selected ? 12 : 0,
                        height: selected ? 12 : 0,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(option.label, style: context.type.bodyMd),
                        if (option.description != null)
                          Text(
                            option.description!,
                            style: context.type.bodySm.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
