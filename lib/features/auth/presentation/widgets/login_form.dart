import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../../../app/theme/theme.dart';
import '../controllers/login_controller.dart';

/// The sign-in form.
///
/// Built entirely from the design system -- [AppTextField], [AppButton],
/// [AppInlineError]. No colour, radius or spacing literal appears below; every
/// value comes from a token, which is what makes the screen correct in dark
/// mode without a second implementation.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Unfocus first so the keyboard does not sit over the error the user is
    // about to be shown.
    FocusScope.of(context).unfocus();

    await ref
        .read(loginControllerProvider.notifier)
        .submit(identifier: _identifier.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          if (state.errorMessage != null)
            AppInlineError(message: state.errorMessage!),
          AppTextField(
            controller: _identifier,
            label: 'Email or phone',
            hintText: 'you@example.com',
            errorText: state.errorFor('identifier'),
            enabled: !state.isSubmitting,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
            onChanged: (_) => controller.clearErrors(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            leading: const Icon(LucideIcons.atSign),
          ),
          AppTextField(
            controller: _password,
            focusNode: _passwordFocus,
            label: 'Password',
            obscureText: _obscure,
            errorText: state.errorFor('password'),
            enabled: !state.isSubmitting,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.password],
            onChanged: (_) => controller.clearErrors(),
            onSubmitted: (_) => _submit(),
            leading: const Icon(LucideIcons.lockKeyhole),
            trailing: GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: _obscure ? 'Show password' : 'Hide password',
                child: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff),
              ),
            ),
          ),
          _RememberRow(
            value: state.remember,
            enabled: !state.isSubmitting,
            onChanged: (value) => controller.setRemember(remember: value),
          ),
          AppButton(
            label: 'Sign in',
            onPressed: state.isSubmitting ? null : _submit,
            loading: state.isSubmitting,
            size: AppButtonSize.large,
            expand: true,
          ),
        ],
      ),
    );
  }
}

/// The "keep me signed in" row.
///
/// Maps to `loginSchema.remember`, which the backend uses to decide the
/// refresh token's lifetime -- so it changes how long the session survives,
/// not merely whether a field is prefilled.
class _RememberRow extends StatelessWidget {
  const _RememberRow({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: <Widget>[
        // The whole row is the target, not just the 20px box -- a checkbox is
        // below the comfortable touch minimum on its own.
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(!value) : null,
            child: Row(
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                Checkbox(
                  value: value,
                  onChanged: enabled
                      ? (next) => onChanged(next ?? false)
                      : null,
                  activeColor: colors.primary,
                  checkColor: colors.primaryForeground,
                  side: BorderSide(color: colors.border),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Text(
                  'Keep me signed in',
                  style: context.text.bodyMedium?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
