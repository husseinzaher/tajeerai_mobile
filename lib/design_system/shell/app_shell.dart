import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import 'bottom_navigation.dart';
import 'navigation_destination.dart';
import 'shell_scope.dart';

/// The frame around the signed-in app: the navigation drawer and the bottom
/// bar.
///
/// **Not the toolbar.** Each screen draws its own through
/// `AppScaffold(toolbar:)`, because the toolbar is the part that differs from
/// screen to screen — a search mode on one, a conversation header on another,
/// a selection mode on a third. A shell that drew the toolbar would have to
/// know every screen. The two meet through [AppShellScope]: a toolbar inside a
/// shell that has a drawer shows the menu button on its own.
///
/// **The bottom bar appears only with two destinations or more.** A tab bar
/// with one tab is a label, and a worse one than the title already on screen.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.body,
    this.drawer,
    this.destinations = const <AppNavDestination>[],
    this.selectedId,
    this.onSelect,
    this.centerAction,
    super.key,
  });

  /// The current screen — normally an `AppScaffold` with its own toolbar.
  final Widget body;

  final Widget? drawer;
  final List<AppNavDestination> destinations;
  final String? selectedId;
  final ValueChanged<String>? onSelect;
  final AppBottomNavAction? centerAction;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffold = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final bool showNavigation =
        widget.destinations.length >= 2 && widget.onSelect != null;

    return Scaffold(
      key: _scaffold,
      backgroundColor: context.colors.background,
      drawer: widget.drawer,
      drawerScrimColor: context.colors.surfaceOverlay,
      bottomNavigationBar: showNavigation
          ? AppBottomNavigation(
              destinations: widget.destinations,
              selectedId: widget.selectedId ?? widget.destinations.first.id,
              onSelect: widget.onSelect!,
              centerAction: widget.centerAction,
            )
          : null,
      body: AppShellScope(
        hasDrawer: widget.drawer != null,
        openDrawer: () => _scaffold.currentState?.openDrawer(),
        child: widget.body,
      ),
    );
  }
}
