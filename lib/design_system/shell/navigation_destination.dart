import 'package:flutter/widgets.dart';

/// Somewhere a member can go: one row in the drawer, one tab in the bottom bar.
///
/// Plain data, shared by both, so a destination is described once and drawn by
/// whichever surface shows it.
@immutable
class AppNavDestination {
  const AppNavDestination({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  /// Stable, and what [AppNavigationDrawer.onSelect] and
  /// [AppBottomNavigation.onSelect] report.
  final String id;

  final String label;
  final IconData icon;

  /// A filled or heavier glyph for the current destination. Optional — the
  /// selected state is also carried by weight and background, never by the
  /// icon alone.
  final IconData? selectedIcon;

  /// Unread or pending items. Zero draws no badge at all.
  final int badgeCount;
}

/// Destinations that belong together, under an optional heading.
@immutable
class AppNavGroup {
  const AppNavGroup({required this.destinations, this.label});

  final String? label;
  final List<AppNavDestination> destinations;
}
