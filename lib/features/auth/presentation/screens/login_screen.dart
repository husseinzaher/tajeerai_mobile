import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../widgets/login_form.dart';

/// The sign-in screen.
///
/// Composed from the design system's auth family rather than laid out by hand:
/// the centring, scrolling, keyboard avoidance and width cap all belong to
/// [AppAuthLayout], so the next unauthenticated screen gets them for free.
///
/// What the reference design draws and this screen deliberately does not:
///
/// - **Social sign-in.** Mobile has no OAuth flow, and a provider button that
///   does nothing is worse than an absent one. `AppSocialButton` exists and is
///   documented in the showcase for the day that flow does.
/// - **"Forgot password" and "Create an account".** There are no screens behind
///   either yet, for the same reason.
/// - **The soft decorative shapes.** The brief for this system rules out
///   decoration without a job.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final TajeerColors colors = context.colors;

    return AppScaffold(
      body: AppAuthLayout(
        topEnd: const _LanguageSwitcher(),
        logo: const AppBrandLogo(variant: AppBrandLogoVariant.mark),
        header: AppAuthHeader(
          title: strings.signInTitle,
          description: strings.signInSubtitle,
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            Icon(LucideIcons.shieldCheck, size: 16, color: colors.textMuted),
            Flexible(
              child: Text(
                strings.securityNotice,
                textAlign: TextAlign.center,
                style: context.type.caption.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
        child: const LoginForm(),
      ),
    );
  }
}

/// The language control in the screen's top-end corner.
///
/// Not a component: an [AppButton] that opens an [AppActionSheet], both from the
/// design system. It lives on this screen because choosing a language is the
/// one setting somebody may need before they can read anything else here.
class _LanguageSwitcher extends ConsumerWidget {
  const _LanguageSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocale current = ref.watch(localeProvider);
    final AppStrings strings = ref.watch(appStringsProvider);

    return AppButton(
      label: current.nativeName,
      variant: AppButtonVariant.outline,
      leading: const Icon(LucideIcons.globe),
      trailing: const Icon(LucideIcons.chevronDown),
      semanticLabel: '${strings.language}: ${current.nativeName}',
      onPressed: () => AppActionSheet.show(
        context: context,
        title: strings.language,
        actions: <AppAction>[
          // Each option in its own script, so somebody who cannot read the
          // current language can still find theirs.
          for (final AppLocale option in AppLocale.values)
            AppAction(
              label: option.nativeName,
              onSelected: () =>
                  unawaited(ref.read(localeProvider.notifier).select(option)),
            ),
        ],
      ),
    );
  }
}
