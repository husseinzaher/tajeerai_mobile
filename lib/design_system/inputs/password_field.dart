import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../localization/ds_localization.dart';
import 'app_text_field.dart';

/// A password field that owns its own reveal toggle.
///
/// The toggle is not decoration: on a phone, typing a long password blind is
/// the single most common reason somebody gives up on a sign-in screen. It
/// carries a real semantic label that changes with the state, because a screen
/// reader announcing "show password" on a field that is already showing is
/// worse than no label.
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    this.controller,
    this.label,
    this.hintText,
    this.description,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHint = AutofillHints.password,
    this.textDirection,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? description;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  /// `AutofillHints.newPassword` on a sign-up form, so the platform offers to
  /// generate one instead of filling the old one in.
  final String autofillHint;

  /// See [AppTextField.textDirection].
  final TextDirection? textDirection;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final String label = _obscured
        ? context.strings.showPassword
        : context.strings.hidePassword;

    return AppTextField(
      controller: widget.controller,
      label: widget.label,
      hintText: widget.hintText,
      description: widget.description,
      errorText: widget.errorText,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      autofillHints: <String>[widget.autofillHint],
      textDirection: widget.textDirection,
      leading: const Icon(LucideIcons.lock),
      trailing: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled
              ? () => setState(() => _obscured = !_obscured)
              : null,
          // A real target rather than a glyph-sized one: an 18px icon is an
          // 18px tap area, and this one sits beside the text cursor, where a
          // miss types into the field instead.
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Icon(_obscured ? LucideIcons.eye : LucideIcons.eyeOff),
            ),
          ),
        ),
      ),
    );
  }
}
