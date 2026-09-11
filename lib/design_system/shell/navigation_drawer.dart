import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../auth/brand_logo.dart';
import '../buttons/app_button.dart';
import '../display/avatar.dart';
import '../display/badge.dart';
import '../display/list_item.dart';
import '../display/separator.dart';
import '../localization/ds_localization.dart';
import '../primitives/pressable.dart';
import 'navigation_destination.dart';

/// Who the drawer belongs to.
@immutable
class AppDrawerProfile {
  const AppDrawerProfile({
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.onTap,
  });

  final String name;

  /// The workspace, usually — the store this person is working in.
  final String? subtitle;

  final String? avatarUrl;
  final VoidCallback? onTap;
}

/// A row at the foot of the drawer: something to *do*, not somewhere to *go*.
@immutable
class AppDrawerAction {
  const AppDrawerAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  /// Drawn in the danger colour, and by convention last. Signing out.
  final bool destructive;
}

/// The navigation drawer.
///
/// It opens from the *start* edge — the right, in Arabic — because it is placed
/// as a `Scaffold.drawer`, which follows the reading direction on its own. That
/// is asserted in a test rather than assumed, since a drawer sliding in from
/// the wrong side is the classic RTL defect.
///
/// The current destination is marked three ways at once: a tinted background,
/// a heavier label and the selected semantics flag. Colour alone would leave it
/// invisible to a reader who cannot tell the tint apart, and a screen reader
/// cannot see a colour at all.
///
/// Picking a destination or an action closes the drawer first, then reports
/// the choice. A panel shown on its own — in the showcase — has no drawer to
/// close, and that is not an error.
class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({
    required this.groups,
    required this.selectedId,
    required this.onSelect,
    this.profile,
    this.header,
    this.footerActions = const <AppDrawerAction>[],
    super.key,
  });

  final List<AppNavGroup> groups;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  final AppDrawerProfile? profile;

  /// Defaults to the horizontal logo.
  final Widget? header;

  final List<AppDrawerAction> footerActions;

  static void _close(BuildContext context) =>
      Scaffold.maybeOf(context)?.closeDrawer();

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final double width = math.min(304, MediaQuery.sizeOf(context).width * 0.85);

    return Drawer(
      width: width,
      backgroundColor: context.elevation.modal.tone,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.horizontal(
          end: Radius.circular(TajeerRadii.xl),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TajeerSpacing.md,
                TajeerSpacing.xs,
                TajeerSpacing.xs,
                TajeerSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child:
                          header ??
                          const AppBrandLogo(
                            variant: AppBrandLogoVariant.horizontal,
                            height: 32,
                          ),
                    ),
                  ),
                  AppButton.icon(
                    icon: const Icon(LucideIcons.x),
                    semanticLabel: context.strings.close,
                    onPressed: () => _close(context),
                  ),
                ],
              ),
            ),
            if (profile != null) ...<Widget>[
              AppListItem(
                leading: AppAvatar(
                  name: profile!.name,
                  imageUrl: profile!.avatarUrl,
                  size: 44,
                ),
                title: Text(profile!.name),
                subtitle: profile!.subtitle == null
                    ? null
                    : Text(profile!.subtitle!),
                onTap: profile!.onTap,
              ),
              const AppSeparator(),
            ],
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
                children: <Widget>[
                  for (final AppNavGroup group in groups) ...<Widget>[
                    if (group.label != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          TajeerSpacing.md,
                          TajeerSpacing.sm,
                          TajeerSpacing.md,
                          TajeerSpacing.xs2,
                        ),
                        child: Text(
                          group.label!,
                          style: context.type.labelSm.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    for (final AppNavDestination destination
                        in group.destinations)
                      _DrawerRow(
                        icon: destination.id == selectedId
                            ? destination.selectedIcon ?? destination.icon
                            : destination.icon,
                        label: destination.label,
                        badgeCount: destination.badgeCount,
                        selected: destination.id == selectedId,
                        onTap: () {
                          _close(context);
                          onSelect(destination.id);
                        },
                      ),
                  ],
                ],
              ),
            ),
            if (footerActions.isNotEmpty) ...<Widget>[
              const AppSeparator(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final AppDrawerAction action in footerActions)
                      _DrawerRow(
                        icon: action.icon,
                        label: action.label,
                        destructive: action.destructive,
                        onTap: () {
                          _close(context);
                          action.onPressed();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.selected = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool selected;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Color ink = destructive
        ? colors.dangerDefault
        : selected
        ? colors.textPrimary
        : colors.textSecondary;
    // `focus`, not `primary`, for the selected glyph: the brand yellow on its
    // own soft tint has no contrast to speak of in the light theme.
    final Color glyph = destructive
        ? colors.dangerDefault
        : selected
        ? colors.focus
        : colors.textMuted;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '$label, $badgeCount' : label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: TajeerSpacing.xs),
          child: AppPressable(
            onTap: onTap,
            borderRadius: TajeerRadii.mdAll,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: selected ? colors.primarySoft : Colors.transparent,
                borderRadius: TajeerRadii.mdAll,
              ),
              child: Row(
                spacing: TajeerSpacing.sm,
                children: <Widget>[
                  Icon(icon, size: 20, color: glyph),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.labelLg.copyWith(
                        color: ink,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badgeCount > 0) AppBadge.count(badgeCount),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
