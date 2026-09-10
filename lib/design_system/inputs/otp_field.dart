import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/theme.dart';
import 'field_scaffold.dart';

/// A one-time code, one box per digit.
///
/// **It pins itself to left-to-right, whatever the ambient direction.** An OTP
/// is a sequence of digits, not a sentence: the provider sends "482913" and the
/// first digit is the leftmost one in Arabic exactly as in English. Mirroring
/// the boxes would silently ask a member to type the code backwards, and it
/// would look completely correct while doing it.
///
/// One real `TextField` behind the boxes rather than one per digit: platform
/// autofill delivers the whole code at once, and six fields fighting over it
/// is how the SMS-autofill flow ends up filling only the first box.
class AppOtpField extends StatefulWidget {
  const AppOtpField({
    required this.length,
    this.controller,
    this.onChanged,
    this.onCompleted,
    this.label,
    this.errorText,
    this.autofocus = true,
    this.enabled = true,
    super.key,
  });

  final int length;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Fired once, when the last digit lands.
  final ValueChanged<String>? onCompleted;

  final String? label;
  final String? errorText;
  final bool autofocus;
  final bool enabled;

  @override
  State<AppOtpField> createState() => _AppOtpFieldState();
}

class _AppOtpFieldState extends State<AppOtpField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final bool _ownsController = widget.controller == null;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    final String value = _controller.text;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String value = _controller.text;
    final bool invalid =
        widget.errorText != null && widget.errorText!.isNotEmpty;

    return AppFieldScaffold(
      label: widget.label,
      errorText: widget.errorText,
      child: Stack(
        children: <Widget>[
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                for (int index = 0; index < widget.length; index++)
                  Expanded(
                    child: _Box(
                      digit: index < value.length ? value[index] : null,
                      active: _focusNode.hasFocus && index == value.length,
                      invalid: invalid,
                      enabled: widget.enabled,
                    ),
                  ),
              ],
            ),
          ),
          // The real field, invisible, on top: it owns the keyboard, the
          // selection and the platform's autofill, while the boxes are only
          // ever a rendering of its value.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                maxLength: widget.length,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                showCursor: false,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.digit,
    required this.active,
    required this.invalid,
    required this.enabled,
  });

  final String? digit;
  final bool active;
  final bool invalid;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color border = switch ((invalid, active)) {
      (true, _) => colors.dangerDefault,
      (false, true) => colors.focus,
      (false, false) => colors.border,
    };

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AnimatedContainer(
        duration: context.motion.fast,
        curve: context.motion.standard,
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: TajeerRadii.mdAll,
          border: Border.fromBorderSide(
            BorderSide(color: border, width: active || invalid ? 1.5 : 1),
          ),
        ),
        child: Text(
          digit ?? '',
          style: context.type.headlineMd.copyWith(
            // Digits line up in a row of boxes, so they get tabular figures.
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
