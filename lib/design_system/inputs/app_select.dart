import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../localization/ds_localization.dart';
import '../overlays/app_bottom_sheet.dart';
import 'search_field.dart';
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
    this.searchable = false,
    this.searchHint,
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

  /// Puts a search field at the top of the sheet.
  ///
  /// Worth turning on somewhere around eight options — the point at which a
  /// list stops being something you scan and starts being something you hunt
  /// through. Left to the caller rather than switched on by a length
  /// threshold: a list of six countries and a list of six statuses are not the
  /// same kind of list, and only the caller knows which it has.
  final bool searchable;

  final String? searchHint;
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
        child: _Options<T>(
          options: options,
          value: value,
          searchable: searchable,
          searchHint: searchHint,
        ),
      ),
    );

    if (chosen != null) {
      onChanged?.call(chosen);
    }
  }
}

/// The sheet's body: the list, and the search field when there is one.
///
/// Stateful because the query is local to the sheet — it dies with it, and
/// nothing above needs to know it was ever typed.
class _Options<T> extends StatefulWidget {
  const _Options({
    required this.options,
    required this.value,
    required this.searchable,
    required this.searchHint,
  });

  final List<AppSelectOption<T>> options;
  final T? value;
  final bool searchable;
  final String? searchHint;

  @override
  State<_Options<T>> createState() => _OptionsState<T>();
}

class _OptionsState<T> extends State<_Options<T>> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<AppSelectOption<T>> get _matches {
    final String query = foldForSearch(_query.text);
    if (query.isEmpty) {
      return widget.options;
    }
    return widget.options
        .where(
          (AppSelectOption<T> option) =>
              foldForSearch(option.label).contains(query) ||
              foldForSearch(option.description ?? '').contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<T>> matches = _matches;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (widget.searchable)
          AppSearchField(
            controller: _query,
            hintText: widget.searchHint ?? context.strings.search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
        if (matches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.lg),
            child: Text(
              context.strings.noMatches,
              textAlign: TextAlign.center,
              style: context.type.bodyMd.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          )
        else
          // Scrollable and height-capped: a searchable list is long by
          // definition, and a sheet that grows past the screen cannot be
          // dismissed by dragging it.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: matches.length,
              itemBuilder: (BuildContext context, int index) => _Row<T>(
                option: matches[index],
                selected: matches[index].value == widget.value,
              ),
            ),
          ),
      ],
    );
  }
}

/// Normalises a string for matching.
///
/// A plain `contains` is wrong for Arabic in two ways that matter every day.
/// The alef carries four written forms — أ إ آ ا — and which one somebody
/// types is not a reliable signal about which one is stored; the same is true
/// of ى/ي and ة/ه. And harakat are optional diacritics: a name written with
/// them will never be found by a query typed without them, which is how people
/// actually type.
///
/// So both sides are folded to one form before comparing. Kept private to this
/// file until a second component needs it — the Inbox's own search is the
/// likely one, and the right time to give it a home is when it has two callers,
/// not one.
String foldForSearch(String value) {
  final StringBuffer folded = StringBuffer();

  for (final int rune in value.toLowerCase().runes) {
    // Harakat and tatweel: presentation, never identity.
    if ((rune >= 0x064B && rune <= 0x065F) ||
        rune == 0x0640 ||
        rune == 0x0670) {
      continue;
    }
    folded.writeCharCode(switch (rune) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ -> ا
      0x0649 => 0x064A, // ى -> ي
      0x0629 => 0x0647, // ة -> ه
      0x06CC => 0x064A, // Farsi yeh -> Arabic yeh
      0x06A9 => 0x0643, // Farsi keheh -> Arabic kaf
      _ => rune,
    });
  }

  return folded.toString().trim();
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
