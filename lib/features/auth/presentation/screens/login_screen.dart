import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../design_system/layouts/app_scaffold.dart';
import '../../../../design_system/layouts/responsive.dart';
import '../widgets/login_form.dart';

/// The sign-in screen.
///
/// Centred and width-capped rather than stretched: on a tablet a form that
/// runs the full width of the display is unusable, and the web's own auth
/// pages cap the same way.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(TajeerSpacing.x6),
            child: ConstrainedBox(
              // `max-w-sm`, the width the web's auth card uses.
              constraints: BoxConstraints(
                maxWidth: Breakpoint.of(context) == Breakpoint.compact
                    ? double.infinity
                    : 384,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TajeerSpacing.x8,
                children: <Widget>[_Header(), LoginForm()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.x2,
      children: <Widget>[
        Text('Sign in', style: context.text.displaySmall),
        Text(
          'Use your Tajeer AI workspace account.',
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
