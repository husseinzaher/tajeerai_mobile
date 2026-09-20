import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/design_system.dart';

import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../router/routes.dart';
import '../../infrastructure/device/platform_info.dart';
import '../bootstrap/dependencies.dart';
import '../localization/locale_manager.dart';
import '../localization/translations/app_strings.dart';
import '../theme/theme.dart';
import '../theme/theme_mode_manager.dart';

/// The member's own settings: who they are signed in as, how the app looks and
/// reads, which build this is, and the way out.
///
/// Composition in `app/`, like the shell: it joins the session to the
/// device's own choices, and no feature owns either. A feature that needs a
/// place here contributes a section rather than this screen reaching into it.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Session? session = ref.watch(authControllerProvider).session;
    final AppThemeMode mode = ref.watch(themeSelectionProvider).mode;
    final AppLocale locale = ref.watch(localeProvider);
    final PlatformInfo platform = ref.watch(platformInfoProvider);

    final List<Widget> sections = <Widget>[
      if (session == null)
        const AppProfileHeader.placeholder()
      else ...<Widget>[
        AppProfileHeader(
          name: session.user.name,
          subtitle: session.workspace?.name,
          avatarUrl: session.user.avatarUrl,
          badges: <Widget>[
            AppBadge(
              label: strings.roleName(session.user.role),
              variant: AppBadgeVariant.secondary,
            ),
          ],
        ),
        AppListSection(
          title: strings.account,
          children: <Widget>[
            AppDetailRow(
              label: strings.email,
              value: session.user.email,
              icon: LucideIcons.mail,
              identifier: true,
              copyable: true,
            ),
            // Left out rather than shown empty: "Phone: —" is a question the
            // member cannot answer from here.
            if (session.user.phone case final String phone
                when phone.isNotEmpty)
              AppDetailRow(
                label: strings.phone,
                value: phone,
                icon: LucideIcons.phone,
                identifier: true,
                copyable: true,
              ),
            if (session.workspace case final Workspace workspace)
              AppDetailRow(
                label: strings.workspace,
                value: workspace.name,
                icon: LucideIcons.store,
              ),
          ],
        ),
      ],
      if (platform.operatingSystem == 'android')
        AppListSection(
          title: strings.callerIdTitle,
          children: <Widget>[
            AppListItem(
              title: Text(strings.callerIdTitle),
              subtitle: Text(strings.callerIdSubtitle),
              leading: const Icon(LucideIcons.phoneIncoming),
              onTap: () => context.push(AppRoutes.callerIdSettingsPath()),
            ),
          ],
        ),
      AppListSection(
        title: strings.appearance,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.sm),
            child: AppSegmentedControl<AppThemeMode>(
              options: <AppThemeMode, String>{
                AppThemeMode.system: strings.themeSystem,
                AppThemeMode.light: strings.themeLight,
                AppThemeMode.dark: strings.themeDark,
              },
              value: mode,
              onChanged: (AppThemeMode next) => unawaited(
                ref.read(themeSelectionProvider.notifier).selectMode(next),
              ),
            ),
          ),
        ],
      ),
      AppListSection(
        title: strings.language,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.sm),
            // Each language in its own script, so somebody who cannot read
            // the current one can still find theirs.
            child: AppSegmentedControl<AppLocale>(
              options: <AppLocale, String>{
                for (final AppLocale option in AppLocale.values)
                  option: option.nativeName,
              },
              value: locale,
              onChanged: (AppLocale next) =>
                  unawaited(ref.read(localeProvider.notifier).select(next)),
            ),
          ),
        ],
      ),
      AppListSection(
        title: strings.about,
        children: <Widget>[
          AppDetailRow(
            label: strings.appVersion,
            value: '${platform.appVersion} (${platform.buildNumber})',
            icon: LucideIcons.info,
            identifier: true,
          ),
        ],
      ),
      AppButton(
        label: strings.signOut,
        variant: AppButtonVariant.destructive,
        leading: const Icon(LucideIcons.logOut),
        expand: true,
        onPressed: () => unawaited(_signOut(context, ref, strings)),
      ),
    ];

    return AppScaffold(
      // The menu button is implied by the signed-in shell's drawer.
      toolbar: AppToolbar(title: strings.settings, centerTitle: true),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          TajeerSpacing.md,
          0,
          TajeerSpacing.md,
          TajeerSpacing.xl,
        ),
        itemCount: sections.length,
        itemBuilder: (BuildContext context, int index) => sections[index],
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(height: TajeerSpacing.lg),
      ),
    );
  }

  /// Asks first: signing out also drops what this device has not sent yet.
  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    // Read before the dialog: the screen may be gone by the time it closes.
    final AuthController auth = ref.read(authControllerProvider.notifier);

    final bool confirmed = await AppDialog.confirm(
      context: context,
      title: strings.signOutConfirmTitle,
      message: strings.signOutConfirmMessage,
      confirmLabel: strings.signOut,
      destructive: true,
    );

    if (confirmed) await auth.signOut();
  }
}
