import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/login_controller.dart';

/// The sign-in form.
///
/// Built entirely from the design system. It used to hand-roll two things the
/// system now owns: a password reveal wired to a bare `GestureDetector`, and a
/// "keep me signed in" row wrapping a raw Material `Checkbox` just so its label
/// could be tapped. Both are [AppPasswordField] and [AppCheckbox] now, which
/// carry real 44px targets and correct semantics instead of re-deriving them
/// here — and RULE 35 now fails the build if either comes back.
class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

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
    final LoginState state = ref.watch(loginControllerProvider);
    final LoginController controller = ref.read(
      loginControllerProvider.notifier,
    );
    final AppStrings strings = ref.watch(appStringsProvider);
    final bool rtl = Directionality.of(context) == TextDirection.rtl;

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
            label: strings.identifierLabel,
            hintText: strings.identifierHint,
            errorText: state.errorFor('identifier'),
            enabled: !state.isSubmitting,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
            onChanged: (_) => controller.clearErrors(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            leading: const Icon(LucideIcons.mail),
          ),
          AppPasswordField(
            controller: _password,
            focusNode: _passwordFocus,
            label: strings.passwordLabel,
            errorText: state.errorFor('password'),
            enabled: !state.isSubmitting,
            textInputAction: TextInputAction.done,
            onChanged: (_) => controller.clearErrors(),
            onSubmitted: (_) => _submit(),
          ),
          // Maps to `loginSchema.remember`, which the backend uses to decide the
          // refresh token's lifetime — so it changes how long the session
          // survives, not merely whether a field is prefilled.
          AppCheckbox(
            value: state.remember,
            label: strings.rememberMe,
            enabled: !state.isSubmitting,
            onChanged: (bool value) => controller.setRemember(remember: value),
          ),
          AppButton(
            label: strings.signIn,
            onPressed: state.isSubmitting ? null : _submit,
            loading: state.isSubmitting,
            size: AppButtonSize.large,
            expand: true,
            // Forward is toward the end of the line, which is the left in
            // Arabic.
            trailing: Icon(
              rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
            ),
          ),
        ],
      ),
    );
  }
}
