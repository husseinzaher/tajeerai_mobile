import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../display/avatar.dart';
import '../display/badge.dart';
import '../display/chip.dart';
import '../primitives/bidi_text.dart';

/// One fact on the caller card: a label and its value, drawn as a row.
@immutable
final class AppCallerCardFact {
  const AppCallerCardFact({required this.label, required this.value});

  final String label;
  final String value;
}

/// How the post-call status line reads: a missed call is a warning, an
/// answered one is good news, and an outgoing one is neither.
enum AppCallerCardTone { neutral, success, danger }

/// What the card shows once the call is over, and what can be done about it.
///
/// All copy comes in from the caller: the design system renders the shape of
/// a summary and knows nothing of which language the member reads.
@immutable
final class AppCallerCardSummary {
  const AppCallerCardSummary({
    required this.statusLabel,
    required this.statusIcon,
    required this.callBackLabel,
    required this.messageLabel,
    required this.customerLabel,
    this.tone = AppCallerCardTone.neutral,
    this.onCallBack,
    this.onMessage,
    this.onOpenCustomer,
  });

  final String statusLabel;
  final IconData statusIcon;
  final AppCallerCardTone tone;
  final String callBackLabel;
  final String messageLabel;

  /// Read by assistive technology for the icon-only customer action.
  final String customerLabel;
  final VoidCallback? onCallBack;
  final VoidCallback? onMessage;
  final VoidCallback? onOpenCustomer;
}

/// Presentation data for the Caller Card.
@immutable
final class AppCallerCardData {
  const AppCallerCardData({
    required this.phoneNumber,
    required this.directionLabel,
    this.brandLabel,
    this.displayName,
    this.businessName,
    this.avatarUrl,
    this.tags = const <String>[],
    this.spamLabel,
    this.lastNote,
    this.facts = const <AppCallerCardFact>[],
    this.summary,
    this.compact = true,
    this.showAvatar = true,
    this.showCallerName = true,
    this.showPhoneNumber = true,
    this.showTags = true,
    this.showSpamStatus = true,
    this.showBusinessInfo = true,
  });

  final String phoneNumber;
  final String directionLabel;

  /// The product's name, drawn as a pill in the header so the member knows
  /// which app is speaking over their call screen.
  final String? brandLabel;
  final String? displayName;
  final String? businessName;
  final String? avatarUrl;
  final List<String> tags;
  final String? spamLabel;

  /// The newest note on the contact, already prefixed by the caller
  /// ("Last note: …"). Kept for callers that have one line and no label;
  /// [facts] is the labelled form.
  final String? lastNote;

  /// Labelled facts: last order, address, last note.
  final List<AppCallerCardFact> facts;

  /// Present once the call has ended.
  final AppCallerCardSummary? summary;
  final bool compact;
  final bool showAvatar;
  final bool showCallerName;
  final bool showPhoneNumber;
  final bool showTags;
  final bool showSpamStatus;
  final bool showBusinessInfo;

  String get primaryLabel {
    final String? name = displayName?.trim();

    if (name != null && name.isNotEmpty) return name;

    return phoneNumber;
  }
}

/// The Caller Card drawn from [AppCallerCardData].
///
/// One dark glass surface in both appearances - it is drawn over a call
/// screen, not inside the app - so it is built from the ambient palette's
/// elevated surface fading to its background, with the primary colour as the
/// one accent: the brand pill, the ring around the avatar, the call-back
/// button. Shown inside the app it should sit under the dark theme of the
/// member's preset, which is what the settings preview does.
class AppCallerCard extends StatelessWidget {
  const AppCallerCard({
    required this.data,
    this.onTap,
    this.onClose,
    super.key,
  });

  final AppCallerCardData data;
  final VoidCallback? onTap;

  /// Draws the close affordance in the header when given.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[colors.surfaceElevated, colors.background],
        ),
        borderRadius: TajeerRadii.xl2All,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: TajeerRadii.xl2All,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TajeerSpacing.md,
              TajeerSpacing.sm,
              TajeerSpacing.sm + TajeerSpacing.xs2,
              TajeerSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                _header(context),
                _identity(context),
                if (_facts.isNotEmpty) _factsPanel(context),
                if (data.showTags && data.tags.isNotEmpty) _tags(context),
                if (data.summary != null) _summary(context, data.summary!),
                if (data.summary == null && !data.compact)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Icon(
                        LucideIcons.phoneIncoming,
                        size: 16,
                        color: colors.textMuted,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<AppCallerCardFact> get _facts {
    if (data.facts.isNotEmpty) return data.facts;
    final String? note = data.lastNote?.trim();
    if (note == null || note.isEmpty) return const <AppCallerCardFact>[];

    return <AppCallerCardFact>[AppCallerCardFact(label: '', value: note)];
  }

  Widget _header(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Row(
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        if (data.brandLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TajeerSpacing.xs + TajeerSpacing.xs2 / 2,
              vertical: TajeerSpacing.xs2 / 2,
            ),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: TajeerRadii.fullAll,
            ),
            child: Text(
              data.brandLabel!,
              style: context.type.labelSm.copyWith(
                color: colors.primaryForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Expanded(
          child: Text(
            data.directionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: colors.textMuted),
          ),
        ),
        if (onClose != null)
          AppButton(
            label: null,
            semanticLabel: data.directionLabel,
            size: AppButtonSize.icon,
            shape: AppButtonShape.circle,
            variant: AppButtonVariant.ghost,
            leading: const Icon(LucideIcons.x),
            onPressed: onClose,
          ),
      ],
    );
  }

  Widget _identity(BuildContext context) {
    final TajeerColors colors = context.colors;
    final String? name = data.displayName?.trim();
    final bool known = name != null && name.isNotEmpty;

    return Row(
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        if (data.showAvatar)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.primary, width: 2),
            ),
            child: AppAvatar(
              name: data.primaryLabel,
              imageUrl: data.avatarUrl,
              size: 56,
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TajeerSpacing.xs2,
            children: <Widget>[
              if (data.showCallerName || !known)
                // The caller wrote neither of these, and the primary label is
                // the phone number when there is no name: laid out in the
                // app's direction, "+966…" reads "966…+" in Arabic.
                AppBidiText(
                  data.primaryLabel,
                  alignToAmbient: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.titleLg.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (data.showPhoneNumber && known)
                Text(
                  data.phoneNumber,
                  style: context.type.bodySm.copyWith(color: colors.textMuted),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
              if (data.showBusinessInfo &&
                  data.businessName != null &&
                  data.businessName!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: TajeerSpacing.xs2),
                  child: AppBadge(
                    label: data.businessName!,
                    variant: AppBadgeVariant.primary,
                    size: AppBadgeSize.small,
                  ),
                ),
              if (data.showSpamStatus && data.spamLabel != null)
                AppBadge(
                  label: data.spamLabel!,
                  variant: AppBadgeVariant.warning,
                  size: AppBadgeSize.small,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _factsPanel(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TajeerSpacing.sm,
        vertical: TajeerSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: TajeerRadii.mdAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.xs2,
        children: <Widget>[
          for (final AppCallerCardFact fact in _facts)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                if (fact.label.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 72),
                    child: Text(
                      fact.label,
                      style: context.type.caption.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                Expanded(
                  child: AppBidiText(
                    fact.value,
                    alignToAmbient: true,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tags(BuildContext context) {
    return Wrap(
      spacing: TajeerSpacing.xs,
      runSpacing: TajeerSpacing.xs,
      children: <Widget>[
        // Two at most: a third chip is where the row stops reading as a
        // label and starts reading as a list.
        for (final String tag in data.tags.take(2)) AppChip(label: tag),
      ],
    );
  }

  Widget _summary(BuildContext context, AppCallerCardSummary summary) {
    final TajeerColors colors = context.colors;
    final Color tone = switch (summary.tone) {
      AppCallerCardTone.success => colors.successDefault,
      AppCallerCardTone.danger => colors.dangerDefault,
      AppCallerCardTone.neutral => colors.textSecondary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        Row(
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            Icon(summary.statusIcon, size: 18, color: tone),
            Expanded(
              child: Text(
                summary.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.bodyMd.copyWith(color: tone),
              ),
            ),
          ],
        ),
        Row(
          spacing: TajeerSpacing.xs,
          children: <Widget>[
            Expanded(
              child: AppButton(
                label: summary.callBackLabel,
                leading: const Icon(LucideIcons.phone),
                onPressed: summary.onCallBack,
              ),
            ),
            Expanded(
              child: AppButton(
                label: summary.messageLabel,
                variant: AppButtonVariant.outline,
                leading: const Icon(LucideIcons.messageCircle),
                onPressed: summary.onMessage,
              ),
            ),
            AppButton(
              label: null,
              semanticLabel: summary.customerLabel,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.icon,
              shape: AppButtonShape.circle,
              leading: const Icon(LucideIcons.user),
              onPressed: summary.onOpenCustomer,
            ),
          ],
        ),
      ],
    );
  }
}
