import 'dart:async';

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
    final List<String> providers =
        ref.watch(socialProvidersProvider).value ?? const <String>[];
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
            textDirection: TextDirection.ltr,
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
            textDirection: TextDirection.ltr,
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
          // Included only when there is something to draw. An empty child
          // still costs one of the column's gaps, which is a stripe of dead
          // space under the button on every deployment that offers no
          // provider.
          if (providers.isNotEmpty)
            _SocialSignIn(providers: providers, busy: state.isSubmitting),
        ],
      ),
    );
  }
}

/// The providers this deployment offers.
///
/// Only built when there is at least one - a fresh deployment names none,
/// which is why the list is asked for rather than assumed.
class _SocialSignIn extends ConsumerWidget {
  const _SocialSignIn({required this.providers, required this.busy});

  final List<String> providers;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);

    return Column(
      spacing: TajeerSpacing.md,
      children: <Widget>[
        AppLabelledSeparator(label: strings.continueWith),
        Row(
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            for (final String provider in providers)
              Expanded(
                child: AppSocialButton(
                  glyph: _glyphFor(strings.socialProviderName(provider)),
                  label: strings.socialProviderName(provider),
                  onPressed: busy
                      ? null
                      : () => unawaited(
                          ref
                              .read(loginControllerProvider.notifier)
                              .signInWith(provider),
                        ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// The provider's initial, until its real mark exists.
  ///
  /// **Deliberately a letter and not a lookalike.** `AppSocialButton` draws
  /// its glyph and nothing else - the label is only its accessible name - so
  /// two providers need two distinguishable marks or they are the same button
  /// twice. Lucide carries no brand icons, and Google's branding rules require
  /// their own "G" on a button that offers Google, so drawing something merely
  /// round and colourful would be worse than plainly provisional. The official
  /// marks are an asset task; this reads correctly in both languages in the
  /// meantime.
  static Widget _glyphFor(String name) {
    final String initial = name.isEmpty
        ? '?'
        : String.fromCharCodes(name.runes.take(1)).toUpperCase();

    return Builder(
      builder: (BuildContext context) => Text(
        initial,
        style: context.type.titleMd.copyWith(color: context.colors.textPrimary),
      ),
    );
  }
}
