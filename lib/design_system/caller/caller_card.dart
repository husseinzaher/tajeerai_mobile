import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../display/avatar.dart';
import '../display/badge.dart';
import '../display/chip.dart';

/// Presentation data for the Caller Card overlay.
@immutable
final class AppCallerCardData {
  const AppCallerCardData({
    required this.phoneNumber,
    required this.directionLabel,
    this.displayName,
    this.businessName,
    this.avatarUrl,
    this.tags = const <String>[],
    this.spamLabel,
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
  final String? displayName;
  final String? businessName;
  final String? avatarUrl;
  final List<String> tags;
  final String? spamLabel;
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
class AppCallerCard extends StatelessWidget {
  const AppCallerCard({required this.data, this.onTap, super.key});

  final AppCallerCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Material(
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: TajeerRadii.lgAll,
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: TajeerRadii.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(TajeerSpacing.md),
          child: data.compact ? _compact(context) : _full(context),
        ),
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Row(
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        if (data.showAvatar)
          AppAvatar(name: data.primaryLabel, imageUrl: data.avatarUrl, size: 48),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: TajeerSpacing.xs,
            children: <Widget>[
              Text(
                data.directionLabel,
                style: context.type.caption.copyWith(color: colors.textMuted),
              ),
              if (data.showCallerName)
                Text(
                  data.primaryLabel,
                  style: context.type.titleMd.copyWith(color: colors.textPrimary),
                ),
              if (data.showPhoneNumber && data.displayName != null)
                Text(
                  data.phoneNumber,
                  style: context.type.bodySm.copyWith(color: colors.textMuted),
                  textDirection: TextDirection.ltr,
                ),
              if (data.showBusinessInfo && data.businessName != null)
                Text(
                  data.businessName!,
                  style: context.type.bodySm.copyWith(color: colors.textSecondary),
                ),
              if (data.showSpamStatus && data.spamLabel != null)
                AppBadge(label: data.spamLabel!, variant: AppBadgeVariant.warning),
              if (data.showTags && data.tags.isNotEmpty) _tags(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _full(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TajeerSpacing.sm,
      children: <Widget>[
        _compact(context),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: TajeerSpacing.xs,
          children: const <Widget>[
            Icon(LucideIcons.phoneIncoming, size: 16),
          ],
        ),
      ],
    );
  }

  Widget _tags(BuildContext context) {
    return Wrap(
      spacing: TajeerSpacing.xs,
      runSpacing: TajeerSpacing.xs,
      children: <Widget>[
        for (final String tag in data.tags) AppChip(label: tag),
      ],
    );
  }
}
