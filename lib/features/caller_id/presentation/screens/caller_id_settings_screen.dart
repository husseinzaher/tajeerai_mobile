import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/caller_id_settings.dart';
import '../controllers/caller_id_settings_controller.dart';

/// Caller ID / Call Card settings and onboarding.
class CallerIdSettingsScreen extends ConsumerWidget {
  const CallerIdSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final CallerIdSettingsViewState state = ref.watch(
      callerIdSettingsControllerProvider,
    );
    final CallerIdSettingsController controller = ref.read(
      callerIdSettingsControllerProvider.notifier,
    );

    return AppScaffold(
      toolbar: AppToolbar(title: strings.callerIdTitle, showBack: true),
      body: state.isLoading
          ? const AppLoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TajeerSpacing.md,
                0,
                TajeerSpacing.md,
                TajeerSpacing.xl,
              ),
              children: <Widget>[
                AppListSection(
                  title: strings.callerIdRequirements,
                  children: <Widget>[
                    _RequirementRow(
                      label: strings.callerIdEnabled,
                      enabled: state.settings.enabled,
                    ),
                    _RequirementRow(
                      label: strings.callerIdCallScreening,
                      enabled: state.permissions.callScreeningRoleHeld,
                    ),
                    _RequirementRow(
                      label: strings.callerIdOverlay,
                      enabled: state.permissions.canDrawOverlays,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(TajeerSpacing.sm),
                      child: Column(
                        spacing: TajeerSpacing.sm,
                        children: <Widget>[
                          AppButton(
                            label: strings.callerIdEnable,
                            expand: true,
                            onPressed: state.isSaving
                                ? null
                                : () => controller.updateSettings(
                                    state.settings.copyWith(enabled: true),
                                  ),
                          ),
                          AppButton(
                            label: strings.callerIdEnableScreening,
                            variant: AppButtonVariant.outline,
                            expand: true,
                            onPressed: state.isSaving
                                ? null
                                : () => unawaited(
                                    controller.requestCallScreeningRole(),
                                  ),
                          ),
                          AppButton(
                            label: strings.callerIdOpenOverlaySettings,
                            variant: AppButtonVariant.outline,
                            expand: true,
                            onPressed: () =>
                                unawaited(controller.openOverlaySettings()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                AppListSection(
                  title: strings.callerIdGeneral,
                  children: <Widget>[
                    AppSwitch(
                      value: state.settings.enabled,
                      label: strings.callerIdEnabled,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(enabled: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.showIncoming,
                      label: strings.callerIdShowIncoming,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(showIncoming: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.showOutgoing,
                      label: strings.callerIdShowOutgoing,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(showOutgoing: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.showOnlyUnknown,
                      label: strings.callerIdUnknownOnly,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(showOnlyUnknown: value),
                      ),
                    ),
                  ],
                ),
                AppListSection(
                  title: strings.callerIdAppearance,
                  children: <Widget>[
                    AppCallerCard(
                      data: AppCallerCardData(
                        phoneNumber: '+966501234567',
                        directionLabel: strings.callerIdIncomingPreview,
                        displayName: strings.callerIdPreviewName,
                        businessName: strings.callerIdPreviewBusiness,
                        tags: <String>[strings.callerIdPreviewTag],
                        compact: state.settings.cardSize == CallerCardLayout.compact,
                        showAvatar: state.settings.showAvatar,
                        showCallerName: state.settings.showCallerName,
                        showPhoneNumber: state.settings.showPhoneNumber,
                        showTags: state.settings.showTags,
                        showSpamStatus: state.settings.showSpamStatus,
                        showBusinessInfo: state.settings.showBusinessInfo,
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.showAvatar,
                      label: strings.callerIdShowAvatar,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(showAvatar: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.animationEnabled,
                      label: strings.callerIdAnimation,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(animationEnabled: value),
                      ),
                    ),
                  ],
                ),
                AppListSection(
                  title: strings.callerIdBehavior,
                  children: <Widget>[
                    AppDetailRow(
                      label: strings.callerIdAutoDismiss,
                      value: '${state.settings.autoDismissSeconds}s',
                      icon: LucideIcons.timer,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TajeerSpacing.sm,
                      ),
                      child: AppSegmentedControl<int>(
                        options: const <int, String>{10: '10s', 15: '15s', 30: '30s'},
                        value: state.settings.autoDismissSeconds,
                        onChanged: (int value) => controller.updateSettings(
                          state.settings.copyWith(autoDismissSeconds: value),
                        ),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.dismissOnTap,
                      label: strings.callerIdDismissOnTap,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(dismissOnTap: value),
                      ),
                    ),
                  ],
                ),
                AppListSection(
                  title: strings.callerIdData,
                  children: <Widget>[
                    AppSwitch(
                      value: state.settings.localLookupEnabled,
                      label: strings.callerIdLocalLookup,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(localLookupEnabled: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.serverLookupEnabled,
                      label: strings.callerIdServerLookup,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(serverLookupEnabled: value),
                      ),
                    ),
                    AppSwitch(
                      value: state.settings.useCachedData,
                      label: strings.callerIdUseCache,
                      onChanged: (bool value) => controller.updateSettings(
                        state.settings.copyWith(useCachedData: value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppDetailRow(
      label: label,
      value: enabled ? '✓' : '—',
      icon: enabled ? LucideIcons.circleCheck : LucideIcons.circle,
    );
  }
}
