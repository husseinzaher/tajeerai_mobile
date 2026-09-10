import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';

/// The system's text input, with the label/description/error scaffolding
/// `field.tsx` wraps it in.
///
/// `input.tsx` is `h-9 rounded-md border border-input bg-transparent px-3`,
/// focus is a 1px `ring` rather than a thicker border, and the field is
/// transparent so it takes the colour of whatever surface it sits on. The
/// error state recolours the border and the ring to `destructive`, which is
/// what `form.tsx` does through `aria-invalid`.
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hintText,
    this.description,
    this.errorText,
    this.obscureText = false,
    this.enabled = true,
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
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;

  /// Helper text under the field. Hidden while [errorText] is showing -- two
  /// stacked messages is how a form starts shouting.
  final String? description;

  final String? errorText;
  final bool obscureText;
  final bool enabled;
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

  bool get _invalid => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final baseStyle = TextStyle(
      fontFamily: TajeerTypography.sansFamily,
      fontFamilyFallback: TajeerTypography.sansFallback,
      // `text-base md:text-sm`: 16 on a phone. Below 16 iOS zooms the field on
      // focus, so the mobile step is the one to keep.
      color: colors.textPrimary,
    );

    final borderColor = _invalid ? colors.dangerDefault : colors.border;
    final ringColor = _invalid ? colors.dangerDefault : colors.focus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      // `space-y-2` between label, control and message.
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (label != null)
          Text(
            label!,
            style: context.text.labelLarge?.copyWith(
              color: _invalid ? colors.dangerDefault : colors.textPrimary,
            ),
          ),
        Opacity(
          // `disabled:opacity-50`.
          opacity: enabled ? 1 : 0.5,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
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
            style: baseStyle,
            cursorColor: colors.primary,
            cursorWidth: 1.5,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              hintText: hintText,
              hintStyle: baseStyle.copyWith(color: colors.textMuted),
              // `px-3` with the height coming from the content box rather than
              // a fixed `h-9`, so a multiline field grows.
              contentPadding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.sm,
                vertical: TajeerSpacing.xs,
              ),
              prefixIcon: leading == null
                  ? null
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: TajeerSpacing.sm,
                        end: TajeerSpacing.xs,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: colors.textMuted, size: 16),
                        child: leading!,
                      ),
                    ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: TajeerSpacing.xs,
                        end: TajeerSpacing.sm,
                      ),
                      child: IconTheme(
                        data: IconThemeData(color: colors.textMuted, size: 16),
                        child: trailing!,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              constraints: const BoxConstraints(minHeight: 36), // `h-9`
              border: _border(borderColor),
              enabledBorder: _border(borderColor),
              disabledBorder: _border(borderColor),
              // `focus-visible:ring-1` -- one pixel, not a heavier border.
              focusedBorder: _border(ringColor, width: 2),
              errorBorder: _border(colors.dangerDefault),
              focusedErrorBorder: _border(colors.dangerDefault, width: 2),
              // The message renders below rather than inside the decoration,
              // so its typography comes from the system's scale.
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            ),
          ),
        ),
        if (_invalid)
          Text(
            errorText!,
            style: context.text.bodySmall?.copyWith(
              color: colors.dangerDefault,
            ),
          )
        else if (description != null)
          Text(
            description!,
            style: context.text.bodySmall?.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: TajeerRadii.mdAll,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
