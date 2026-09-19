import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';
import 'field_scaffold.dart';
import 'field_surface.dart';

/// The system's text input.
///
/// Composed from [AppFieldScaffold] and [AppFieldSurface] rather than owning
/// its own label column and border: those two are shared with every other
/// control that has a label or an edge, which is what keeps a select, a
/// checkbox and a text field looking like one family.
///
/// The field itself is transparent, so it takes the colour of whatever surface
/// it was dropped onto.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hintText,
    this.description,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.leading,
    this.trailing,
    this.focusNode,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.textDirection,
    super.key,
  });

  /// A field that grows with what is typed into it.
  ///
  /// There is no `AppTextarea`: a textarea *is* a text field with more lines,
  /// and a second class would be a second set of borders to keep in step.
  const AppTextField.multiline({
    this.controller,
    this.label,
    this.hintText,
    this.description,
    this.errorText,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.onChanged,
    this.focusNode,
    this.minLines = 3,
    this.maxLines = 6,
    this.textCapitalization = TextCapitalization.sentences,
    super.key,
  }) : obscureText = false,
       keyboardType = TextInputType.multiline,
       textInputAction = null,
       autofillHints = null,
       onSubmitted = null,
       leading = null,
       trailing = null,
       inputFormatters = null,
       textDirection = null;

  final TextEditingController? controller;
  final String? label;
  final String? hintText;

  /// Helper text under the field. Hidden while [errorText] is showing.
  final String? description;

  final String? errorText;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Widget? leading;
  final Widget? trailing;
  final FocusNode? focusNode;
  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  /// When set, the typed text follows this direction regardless of the screen.
  /// Email, password and one-time codes stay left-to-right even in Arabic.
  final TextDirection? textDirection;

  bool get _invalid => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final TextStyle style = context.type.bodyMd;

    return AppFieldScaffold(
      label: label,
      description: description,
      errorText: errorText,
      child: AppFieldSurface(
        invalid: _invalid,
        enabled: enabled,
        child: Row(
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            if (leading != null) _adornment(colors, leading!),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                readOnly: readOnly,
                autofocus: autofocus,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                autofillHints: autofillHints,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                maxLines: obscureText ? 1 : maxLines,
                minLines: minLines,
                textCapitalization: textCapitalization,
                inputFormatters: inputFormatters,
                textDirection: textDirection,
                style: style,
                cursorColor: colors.primary,
                cursorWidth: 1.5,
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  hintText: hintText,
                  hintStyle: style.copyWith(color: colors.textMuted),
                  // The surface owns the border and the padding; the field
                  // draws nothing of its own or the two would fight.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsetsDirectional.symmetric(
                    vertical: TajeerSpacing.sm,
                  ),
                  // The message renders below, in the scaffold, so its
                  // typography comes from the system's scale.
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
              ),
            ),
            if (trailing != null) _adornment(colors, trailing!),
          ],
        ),
      ),
    );
  }

  Widget _adornment(TajeerColors colors, Widget child) => IconTheme(
    data: IconThemeData(color: colors.textMuted, size: 18),
    child: child,
  );
}
