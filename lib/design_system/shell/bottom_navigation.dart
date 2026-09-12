import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../display/badge.dart';
import '../primitives/pressable.dart';
import 'navigation_destination.dart';

/// The raised button in the middle of the bottom bar.
@immutable
class AppBottomNavAction {
  const AppBottomNavAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// What a screen reader calls it. The button is a glyph and nothing else,
  /// which is exactly why this is required.
  final String label;

  final VoidCallback onPressed;
}

/// The bottom navigation bar.
///
/// **Two to five destinations, enforced.** One is a label pretending to be
/// navigation, and six do not fit on a phone with their labels intact. The
/// shell simply does not draw the bar below two.
///
/// Destinations flow from the start edge, so in Arabic the first one sits on
/// the right. The current destination is marked by a tinted pill behind its
/// glyph, a heavier label and the selected semantics flag — never by colour
/// alone.
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    this.centerAction,
    super.key,
  }) : assert(
         destinations.length >= 2 && destinations.length <= 5,
         'A bottom bar holds two to five destinations.',
       );

  final List<AppNavDestination> destinations;
  final String selectedId;
  final ValueChanged<String> onSelect;
  final AppBottomNavAction? centerAction;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final int split = centerAction == null
        ? destinations.length
        : (destinations.length / 2).ceil();

    Widget item(AppNavDestination destination) => Expanded(
      child: _NavItem(
        destination: destination,
        selected: destination.id == selectedId,
        onTap: () => onSelect(destination.id),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: TajeerSpacing.md,
        end: TajeerSpacing.md,
        bottom: TajeerSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: TajeerRadii.xlAll,
          border: Border.all(color: colors.border),
          //testing part
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.12),
            ),
          ],
          // boxShadow: context.elevation.floating.shadow,
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TajeerSpacing.xs,
              vertical: TajeerSpacing.xs2,
            ),
            child: Row(
              children: <Widget>[
                for (final AppNavDestination d in destinations.take(split))
                  item(d),

                if (centerAction != null) _CenterAction(action: centerAction!),

                for (final AppNavDestination d in destinations.skip(split))
                  item(d),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final IconData icon = selected
        ? destination.selectedIcon ?? destination.icon
        : destination.icon;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: destination.badgeCount > 0
          ? '${destination.label}, ${destination.badgeCount}'
          : destination.label,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onTap,
          borderRadius: TajeerRadii.mdAll,
          child: ConstrainedBox(
            // A minimum, never a fixed height: the label grows with text size.
            constraints: const BoxConstraints(maxHeight: 70),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: TajeerSpacing.xs2,
                children: <Widget>[
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: context.motion.fast,
                        curve: context.motion.standard,
                        padding: const EdgeInsets.symmetric(
                          horizontal: TajeerSpacing.sm,
                          vertical: TajeerSpacing.xs2,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primarySoft
                              : Colors.transparent,
                          borderRadius: TajeerRadii.fullAll,
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          // `focus`, not `primary`: yellow on its own soft tint
                          // has no contrast in the light theme.
                          color: selected ? colors.focus : colors.textMuted,
                        ),
                      ),
                      if (destination.badgeCount > 0)
                        PositionedDirectional(
                          top: -4,
                          end: -4,
                          child: AppBadge.count(destination.badgeCount),
                        ),
                    ],
                  ),
                  TajeerTypography.clampForControl(
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.labelSm.copyWith(
                        color: selected ? colors.textPrimary : colors.textMuted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterAction extends StatelessWidget {
  const _CenterAction({required this.action});

  final AppBottomNavAction action;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TajeerSpacing.xs),
      child: Semantics(
        container: true,
        button: true,
        label: action.label,
        child: ExcludeSemantics(
          child: AppPressable(
            onTap: action.onPressed,
            borderRadius: TajeerRadii.fullAll,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                boxShadow: context.elevation.floating.shadow,
              ),
              child: Icon(
                action.icon,
                size: 26,
                color: colors.primaryForeground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
