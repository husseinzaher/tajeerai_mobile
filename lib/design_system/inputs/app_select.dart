import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../overlays/app_bottom_sheet.dart';
import 'field_scaffold.dart';
import 'field_surface.dart';

/// One choice in an [AppSelect].
@immutable
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.description,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final Widget? leading;
  final bool enabled;
}

/// A single choice from a list, chosen in a sheet.
///
/// **A sheet, not a dropdown.** This is the deliberate divergence from the web
/// design system's select: a popover anchored to a 44px control on a phone
/// opens over the thing it belongs to, is a thumb-stretch away from the top of
/// the screen, and closes on the first stray scroll. A sheet comes from the
/// edge the thumb is already at, and can hold a description per row.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.placeholder,
    this.description,
    this.errorText,
    this.enabled = true,
    this.sheetTitle,
    super.key,
  });

  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String? label;
  final String? placeholder;
  final String? description;
  final String? errorText;
  final bool enabled;
  final String? sheetTitle;

  bool get _interactive => enabled && onChanged != null;

  AppSelectOption<T>? get _selected {
    for (final AppSelectOption<T> option in options) {
      if (option.value == value) {
        return option;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final AppSelectOption<T>? selected = _selected;

    return AppFieldScaffold(
      label: label,
      description: description,
      errorText: errorText,
      child: Semantics(
        button: true,
        enabled: _interactive,
        label: label,
        value: selected?.label,
        child: ExcludeSemantics(
          child: AppFieldSurface(
            invalid: errorText != null && errorText!.isNotEmpty,
            enabled: enabled,
            onTap: _interactive ? () => _open(context) : null,
            child: Row(
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                if (selected?.leading != null)
                  IconTheme(
                    data: IconThemeData(color: colors.textMuted, size: 18),
                    child: selected!.leading!,
                  ),
                Expanded(
                  child: Text(
                    selected?.label ?? placeholder ?? context.strings.select,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.bodyMd.copyWith(
                      color: selected == null
                          ? colors.textMuted
                          : colors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final T? chosen = await AppBottomSheet.show<T>(
      context: context,
      sheet: AppBottomSheet(
        title: sheetTitle ?? label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final AppSelectOption<T> option in options)
              _Row<T>(option: option, selected: option.value == value),
          ],
        ),
      ),
    );

    if (chosen != null) {
      onChanged?.call(chosen);
    }
  }
}

class _Row<T> extends StatelessWidget {
  const _Row({required this.option, required this.selected});

  final AppSelectOption<T> option;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Semantics(
      button: true,
      selected: selected,
      enabled: option.enabled,
      label: option.label,
      child: ExcludeSemantics(
        child: Opacity(
          opacity: option.enabled ? 1 : 0.5,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: option.enabled
                ? () => Navigator.of(context).pop(option.value)
                : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.sm,
                vertical: TajeerSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: selected ? colors.primarySoft : Colors.transparent,
                borderRadius: TajeerRadii.mdAll,
              ),
              child: Row(
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  if (option.leading != null)
                    IconTheme(
                      data: IconThemeData(color: colors.textMuted, size: 18),
                      child: option.leading!,
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
                  if (selected)
                    Icon(LucideIcons.check, size: 18, color: colors.focus),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
