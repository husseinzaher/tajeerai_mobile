import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/theme_mode_manager.dart';
import '../../../../app/bootstrap/dependencies.dart';
import '../../../../design_system/design_system.dart';
import '../../application/ports/caller_id_platform_port.dart';
import '../../domain/entities/caller_id_settings.dart';
import '../controllers/caller_id_settings_controller.dart';

/// Caller ID: what the card will look like, whether it can appear, and how.
///
/// ## The order is the argument
///
/// 1. **The card itself**, live, on a stage that mirrors the position and size
///    chosen below. Settings about a thing nobody can see are abstract; a
///    preview that moves when a toggle moves is not.
/// 2. **One master switch**, with the state spelled out beside the preview:
///    ready, needs setup, or off. Everything below dims when it is off, so the
///    screen says "nothing here applies" rather than offering twenty controls
///    that do nothing.
/// 3. **Setup steps**, only while one is missing. Each row carries its own
///    action, so there is never a stack of three buttons the reader has to map
///    back to three rows. Granted steps show a tick and no button; once all
///    are granted the section leaves.
/// 4. Then the preferences, grouped by the question they answer: when, how it
///    looks, how it behaves, where the data comes from. Every switch has a
///    one-line description, because "Local lookup" on its own is a term, not a
///    choice.
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
    final CallerIdSettings settings = state.settings;
    final bool on = settings.enabled;

    void update(CallerIdSettings next) =>
        unawaited(controller.updateSettings(next));

    return AppScaffold(
      toolbar: AppToolbar(title: strings.callerIdTitle, showBack: true),
      body: state.isLoading
          ? const AppLoadingState()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                TajeerSpacing.md,
                TajeerSpacing.sm,
                TajeerSpacing.md,
                TajeerSpacing.xl2,
              ),
              children: <Widget>[
                _PreviewStage(
                  settings: settings,
                  strings: strings,
                  preset: ref.watch(themeSelectionProvider).preset,
                  // The member's own photo stands in for the caller's: a real
                  // picture shows what the card looks like with one, and it
                  // is the one photo this screen is sure to have. Through the
                  // auth feature's contract, never its controller.
                  avatarUrl: ref
                      .read(sessionCapabilityProvider)
                      .currentSession
                      ?.user
                      .avatarUrl,
                ),
                const SizedBox(height: TajeerSpacing.md),
                _StatusCard(
                  settings: settings,
                  permissions: state.permissions,
                  strings: strings,
                  saving: state.isSaving,
                  onToggle: (bool value) =>
                      update(settings.copyWith(enabled: value)),
                ),
                if (!state.permissions.isReady) ...<Widget>[
                  const SizedBox(height: TajeerSpacing.lg),
                  _SetupSteps(
                    permissions: state.permissions,
                    strings: strings,
                    controller: controller,
                  ),
                ],
                const SizedBox(height: TajeerSpacing.lg),
                AppListSection(
                  title: strings.callerIdCalls,
                  children: <Widget>[
                    AppSwitch(
                      value: settings.showIncoming,
                      enabled: on,
                      label: strings.callerIdShowIncoming,
                      description: strings.callerIdShowIncomingDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showIncoming: value)),
                    ),
                    AppSwitch(
                      value: settings.showOutgoing,
                      enabled: on,
                      label: strings.callerIdShowOutgoing,
                      description: strings.callerIdShowOutgoingDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showOutgoing: value)),
                    ),
                    AppSwitch(
                      value: settings.showContacts,
                      enabled: on,
                      label: strings.callerIdShowContacts,
                      description: strings.callerIdShowContactsDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showContacts: value)),
                    ),
                    AppSwitch(
                      value: settings.showOnlyUnknown,
                      enabled: on,
                      label: strings.callerIdUnknownOnly,
                      description: strings.callerIdUnknownOnlyDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showOnlyUnknown: value)),
                    ),
                  ],
                ),
                const SizedBox(height: TajeerSpacing.lg),
                AppListSection(
                  title: strings.callerIdAppearance,
                  children: <Widget>[
                    _ChoiceRow<CallerCardPosition>(
                      label: strings.callerIdCardPosition,
                      enabled: on,
                      options: <CallerCardPosition, String>{
                        CallerCardPosition.top: strings.callerIdPositionTop,
                        CallerCardPosition.center:
                            strings.callerIdPositionCenter,
                        CallerCardPosition.bottom:
                            strings.callerIdPositionBottom,
                      },
                      value: settings.cardPosition,
                      onChanged: (CallerCardPosition value) =>
                          update(settings.copyWith(cardPosition: value)),
                    ),
                    _ChoiceRow<CallerCardLayout>(
                      label: strings.callerIdCardSize,
                      enabled: on,
                      options: <CallerCardLayout, String>{
                        CallerCardLayout.compact: strings.callerIdSizeCompact,
                        CallerCardLayout.full: strings.callerIdSizeFull,
                      },
                      value: settings.cardSize,
                      onChanged: (CallerCardLayout value) =>
                          update(settings.copyWith(cardSize: value)),
                    ),
                    AppSwitch(
                      value: settings.showAvatar,
                      enabled: on,
                      label: strings.callerIdShowAvatar,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showAvatar: value)),
                    ),
                    AppSwitch(
                      value: settings.showPhoneNumber,
                      enabled: on,
                      label: strings.callerIdShowPhoneNumber,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showPhoneNumber: value)),
                    ),
                    AppSwitch(
                      value: settings.showBusinessInfo,
                      enabled: on,
                      label: strings.callerIdShowBusinessInfo,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showBusinessInfo: value)),
                    ),
                    AppSwitch(
                      value: settings.showTags,
                      enabled: on,
                      label: strings.callerIdShowTags,
                      onChanged: (bool value) =>
                          update(settings.copyWith(showTags: value)),
                    ),
                    AppSwitch(
                      value: settings.animationEnabled,
                      enabled: on,
                      label: strings.callerIdAnimation,
                      onChanged: (bool value) =>
                          update(settings.copyWith(animationEnabled: value)),
                    ),
                  ],
                ),
                const SizedBox(height: TajeerSpacing.lg),
                AppListSection(
                  title: strings.callerIdBehavior,
                  children: <Widget>[
                    _ChoiceRow<int>(
                      label: strings.callerIdAutoDismiss,
                      description: strings.callerIdAutoDismissDescription,
                      enabled: on,
                      // Zero is "never": the card stays until it is closed by
                      // hand, which is what the X in its corner is for.
                      options: <int, String>{
                        for (final int seconds in const <int>[10, 15, 30])
                          seconds: '$seconds ${strings.callerIdSecondsUnit}',
                        0: strings.callerIdNeverDismiss,
                      },
                      value: settings.autoDismissSeconds,
                      onChanged: (int value) =>
                          update(settings.copyWith(autoDismissSeconds: value)),
                    ),
                    AppSwitch(
                      value: settings.dismissOnTap,
                      enabled: on,
                      label: strings.callerIdDismissOnTap,
                      description: strings.callerIdDismissOnTapDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(dismissOnTap: value)),
                    ),
                  ],
                ),
                const SizedBox(height: TajeerSpacing.lg),
                AppListSection(
                  title: strings.callerIdData,
                  children: <Widget>[
                    AppSwitch(
                      value: settings.localLookupEnabled,
                      enabled: on,
                      label: strings.callerIdLocalLookup,
                      description: strings.callerIdLocalLookupDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(localLookupEnabled: value)),
                    ),
                    AppSwitch(
                      value: settings.serverLookupEnabled,
                      enabled: on,
                      label: strings.callerIdServerLookup,
                      description: strings.callerIdServerLookupDescription,
                      onChanged: (bool value) => update(
                        settings.copyWith(serverLookupEnabled: value),
                      ),
                    ),
                    AppSwitch(
                      value: settings.useCachedData,
                      enabled: on,
                      label: strings.callerIdUseCache,
                      description: strings.callerIdUseCacheDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(useCachedData: value)),
                    ),
                    AppSwitch(
                      value: settings.logCallsToServer,
                      enabled: on,
                      label: strings.callerIdLogCalls,
                      description: strings.callerIdLogCallsDescription,
                      onChanged: (bool value) =>
                          update(settings.copyWith(logCallsToServer: value)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// The card as it will appear, on a stage shaped like the call screen.
///
/// Drawn under the **dark** theme of the member's preset whatever the app is
/// showing, because that is what the real card is: one dark glass surface
/// over a call screen. The stage is a fixed height so the card can sit at the
/// top, the centre or the bottom of it the way the position setting says,
/// and the whole thing dims when Caller ID is off - a preview at full
/// strength of a card that will not appear is a promise the screen cannot
/// keep. A second control shows the card as it looks once the call is over.
class _PreviewStage extends StatefulWidget {
  const _PreviewStage({
    required this.settings,
    required this.strings,
    required this.preset,
    this.avatarUrl,
  });

  final CallerIdSettings settings;
  final AppStrings strings;
  final TajeerPreset preset;
  final String? avatarUrl;

  @override
  State<_PreviewStage> createState() => _PreviewStageState();
}

class _PreviewStageState extends State<_PreviewStage> {
  bool _afterCall = false;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final CallerIdSettings settings = widget.settings;
    final AppStrings strings = widget.strings;

    final AlignmentGeometry alignment = switch (settings.cardPosition) {
      CallerCardPosition.top => Alignment.topCenter,
      CallerCardPosition.center => Alignment.center,
      CallerCardPosition.bottom => Alignment.bottomCenter,
    };

    final AppCallerCardData data = AppCallerCardData(
      phoneNumber: '+966 50 123 4567',
      directionLabel: strings.callerIdIncomingPreview,
      brandLabel: strings.callerIdBrand,
      displayName: strings.callerIdPreviewName,
      avatarUrl: widget.avatarUrl,
      businessName: strings.callerIdPreviewBusiness,
      tags: <String>[strings.callerIdPreviewTag],
      facts: <AppCallerCardFact>[
        AppCallerCardFact(
          label: strings.callerIdLastOrder,
          value: strings.callerIdPreviewOrder,
        ),
        AppCallerCardFact(
          label: strings.callerIdAddress,
          value: strings.callerIdPreviewAddress,
        ),
        AppCallerCardFact(
          label: strings.callerIdLastNote,
          value: strings.callerIdPreviewNote,
        ),
      ],
      summary: _afterCall
          ? AppCallerCardSummary(
              statusLabel: strings.callerIdMissedCall,
              statusIcon: LucideIcons.phoneMissed,
              tone: AppCallerCardTone.danger,
              callBackLabel: strings.callerIdCallBack,
              messageLabel: strings.callerIdMessage,
              customerLabel: strings.callerIdOpenCustomer,
              onCallBack: () {},
              onMessage: () {},
              onOpenCustomer: () {},
            )
          : null,
      compact: settings.cardSize == CallerCardLayout.compact,
      showAvatar: settings.showAvatar,
      showCallerName: settings.showCallerName,
      showPhoneNumber: settings.showPhoneNumber,
      showTags: settings.showTags,
      showSpamStatus: settings.showSpamStatus,
      showBusinessInfo: settings.showBusinessInfo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(start: TajeerSpacing.md),
          child: Text(
            strings.callerIdPreview,
            style: context.type.labelSm.copyWith(color: colors.textMuted),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: settings.enabled ? 1 : 0.45,
          child: Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(TajeerSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: TajeerRadii.xlAll,
              border: Border.all(color: colors.borderSubtle),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: alignment,
              // The real card is always dark: the preview borrows the dark
              // theme of the member's preset rather than the app's current one.
              child: Theme(
                data: AppTheme.dark(preset: widget.preset),
                child: Builder(
                  builder: (BuildContext dark) =>
                      AppCallerCard(data: data, onClose: () {}),
                ),
              ),
            ),
          ),
        ),
        AppSegmentedControl<bool>(
          options: <bool, String>{
            false: strings.callerIdPreviewDuring,
            true: strings.callerIdPreviewAfter,
          },
          value: _afterCall,
          onChanged: (bool value) => setState(() => _afterCall = value),
        ),
      ],
    );
  }
}

/// The master switch, with the state it produces named beside it.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.settings,
    required this.permissions,
    required this.strings,
    required this.saving,
    required this.onToggle,
  });

  final CallerIdSettings settings;
  final CallerIdPermissionStatus permissions;
  final AppStrings strings;
  final bool saving;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final (String label, AppBadgeVariant variant, String description) =
        !settings.enabled
        ? (
            strings.callerIdStatusOff,
            AppBadgeVariant.muted,
            strings.callerIdOffDescription,
          )
        : permissions.isReady
        ? (
            strings.callerIdStatusReady,
            AppBadgeVariant.success,
            strings.callerIdReadyDescription,
          )
        : (
            strings.callerIdStatusSetup,
            AppBadgeVariant.warning,
            strings.callerIdSetupDescription,
          );

    return AppCard(
      padding: const EdgeInsets.all(TajeerSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          Row(
            spacing: TajeerSpacing.sm,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: TajeerRadii.mdAll,
                ),
                child: Icon(
                  LucideIcons.phoneIncoming,
                  size: 20,
                  color: colors.primary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: TajeerSpacing.xs2,
                  children: <Widget>[
                    Text(
                      strings.callerIdTitle,
                      style: context.type.titleSm.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    AppBadge(
                      label: label,
                      variant: variant,
                      size: AppBadgeSize.small,
                    ),
                  ],
                ),
              ),
              AppSwitch(
                value: settings.enabled,
                enabled: !saving,
                semanticLabel: strings.callerIdEnabled,
                onChanged: onToggle,
              ),
            ],
          ),
          Text(
            description,
            style: context.type.bodySm.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Each grant the card depends on, with its own way of granting it.
class _SetupSteps extends StatelessWidget {
  const _SetupSteps({
    required this.permissions,
    required this.strings,
    required this.controller,
  });

  final CallerIdPermissionStatus permissions;
  final AppStrings strings;
  final CallerIdSettingsController controller;

  @override
  Widget build(BuildContext context) {
    return AppListSection(
      title: strings.callerIdSetupSteps,
      children: <Widget>[
        _SetupStep(
          granted: permissions.callScreeningRoleHeld,
          title: strings.callerIdCallScreening,
          description: strings.callerIdScreeningDescription,
          actionLabel: strings.callerIdGrant,
          grantedLabel: strings.callerIdGranted,
          onGrant: () => unawaited(controller.requestCallScreeningRole()),
        ),
        _SetupStep(
          granted: permissions.canDrawOverlays,
          title: strings.callerIdOverlay,
          description: strings.callerIdOverlayDescription,
          actionLabel: strings.callerIdGrant,
          grantedLabel: strings.callerIdGranted,
          onGrant: () => unawaited(controller.openOverlaySettings()),
        ),
        _SetupStep(
          granted: permissions.readContactsGranted,
          title: strings.callerIdContacts,
          description: strings.callerIdContactsDescription,
          actionLabel: strings.callerIdGrant,
          grantedLabel: strings.callerIdGranted,
          onGrant: () => unawaited(controller.requestContactsPermission()),
        ),
        _SetupStep(
          granted: permissions.readPhoneStateGranted,
          title: strings.callerIdPhoneState,
          description: strings.callerIdPhoneStateDescription,
          actionLabel: strings.callerIdGrant,
          grantedLabel: strings.callerIdGranted,
          onGrant: () => unawaited(controller.requestPhoneStatePermission()),
        ),
      ],
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.granted,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.grantedLabel,
    required this.onGrant,
  });

  final bool granted;
  final String title;
  final String description;
  final String actionLabel;
  final String grantedLabel;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return AppListItem(
      leading: Icon(
        granted ? LucideIcons.circleCheck : LucideIcons.circle,
        size: 22,
        color: granted ? colors.successDefault : colors.textMuted,
      ),
      title: Text(title),
      subtitle: Text(description),
      trailing: granted
          ? AppBadge(
              label: grantedLabel,
              variant: AppBadgeVariant.success,
              size: AppBadgeSize.small,
            )
          : AppButton(
              label: actionLabel,
              size: AppButtonSize.small,
              variant: AppButtonVariant.soft,
              onPressed: onGrant,
            ),
    );
  }
}

/// A labelled segmented choice, laid out as one row of a settings section.
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.description,
  });

  final String label;
  final String? description;
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TajeerSpacing.md,
          vertical: TajeerSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            Text(
              label,
              style: context.type.bodyMd.copyWith(color: colors.textPrimary),
            ),
            if (description != null)
              Text(
                description!,
                style: context.type.bodySm.copyWith(color: colors.textMuted),
              ),
            AppSegmentedControl<T>(
              options: options,
              value: value,
              enabled: enabled,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
