import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/value_objects/login_phone_reader.dart';
import '../controllers/login_controller.dart';
import '../helpers/login_identifier_input_formatter.dart';
import 'login_identifier_leading.dart';

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
  void initState() {
    super.initState();
    _identifier.addListener(_identifierChanged);
  }

  void _identifierChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _identifier
      ..removeListener(_identifierChanged)
      ..dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    final String identifierText = _identifier.text;
    final bool asPhone = LoginPhoneReader.isPhoneShaped(identifierText);
    final bool asEmail = identifierText.contains('@');

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
            keyboardType: asPhone
                ? TextInputType.phone
                : (asEmail ? TextInputType.emailAddress : TextInputType.text),
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            autofillHints: const <String>[AutofillHints.username],
            inputFormatters: const <TextInputFormatter>[
              LoginIdentifierInputFormatter(),
            ],
            onChanged: (_) => controller.clearErrors(),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            leading: LoginIdentifierLeading(value: identifierText),
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
            trailing: Icon(
              rtl ? LucideIcons.arrowLeft : LucideIcons.arrowRight,
            ),
          ),
          if (providers.isNotEmpty)
            _SocialSignIn(providers: providers, busy: state.isSubmitting),
        ],
      ),
    );
  }
}

/// The providers this deployment offers.
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
                  glyph: AppSocialProviderMark(provider.toLowerCase()),
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
}
