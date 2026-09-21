import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../controllers/login_controller.dart';
import '../widgets/login_form.dart';

/// The sign-in screen.
///
/// Composed from the design system's auth family rather than laid out by hand:
/// the centring, scrolling, keyboard avoidance and width cap all belong to
/// [AppAuthLayout], so the next unauthenticated screen gets them for free.
///
/// What the reference design draws and this screen deliberately does not:
///
/// - **"Forgot password" and "Create an account".** There are no screens behind
///   either yet, for the same reason.
/// - **The soft decorative shapes.** The brief for this system rules out
///   decoration without a job.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final LoginBuildInfo buildInfo = ref.watch(loginBuildInfoProvider);
    final TajeerColors colors = context.colors;

    return AppScaffold(
      body: AppAuthLayout(
        topStart: const _BlogLink(),
        topEnd: const _LanguageSwitcher(),
        logo: const AppBrandLogo(variant: AppBrandLogoVariant.mark),
        header: AppAuthHeader(
          title: strings.signInTitle,
          description: strings.signInSubtitle,
        ),
        footer: Column(
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: colors.textMuted,
                ),
                Flexible(
                  child: Text(
                    strings.securityNotice,
                    textAlign: TextAlign.center,
                    style: context.type.caption.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${strings.appVersion} ${buildInfo.version} (${buildInfo.buildNumber})',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: context.type.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
        child: const LoginForm(),
      ),
    );
  }
}

/// The way out of this screen, in its top-start corner.
///
/// The blog is the only thing in this app somebody without an account may
/// read, and this is the only screen they ever see -- so without this button
/// it is reachable only by following a link from outside the app, which is
/// backwards for the one thing here written to be read *before* signing up.
///
/// Shaped like the language switcher opposite it, because the two are the same
/// kind of thing: controls belonging to the screen rather than to the form.
class _BlogLink extends ConsumerWidget {
  const _BlogLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);

    return AppButton(
      label: strings.blog,
      variant: AppButtonVariant.outline,
      leading: const Icon(LucideIcons.bookOpen),
      // Pushed, so the reader who was about to sign in still has this screen
      // underneath when they close the article.
      onPressed: () => unawaited(context.push(AppRoutes.blog)),
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
      /*
        The flag alone, and no globe in front of it. The trigger's job is to
        say which language is active, which a flag does at a glance and in less
        room than either name - and the sheet behind it still spells both out.
      */
      label: current.flag,
      variant: AppButtonVariant.outline,
      trailing: const Icon(LucideIcons.chevronDown),
      // The flag is decoration to a screen reader; the name is the answer.
      semanticLabel: '${strings.language}: ${current.nativeName}',
      onPressed: () => AppActionSheet.show(
        context: context,
        title: strings.language,
        actions: <AppAction>[
          // Each option in its own script, so somebody who cannot read the
          // current language can still find theirs.
          for (final AppLocale option in AppLocale.values)
            AppAction(
              label: option.flaggedName,
              onSelected: () =>
                  unawaited(ref.read(localeProvider.notifier).select(option)),
            ),
        ],
      ),
    );
  }
}
