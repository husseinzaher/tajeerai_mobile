import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/design_system.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../localization/translations/app_strings.dart';
import 'shell_destination.dart';

/// The frame around every signed-in screen.
///
/// Composition, which is why it lives in `app/`: it joins the design system's
/// [AppShell] to the session, and to the routes — three things no single
/// feature owns.
///
/// **Only destinations the member may open.** [ShellDestination] lists the
/// screens that exist; the drawer and the bottom bar offer the ones this
/// member's permissions open, and `AuthGuard` keeps them off the rest. The
/// bottom bar appears once two are on offer: a tab bar with one tab is a
/// label.
class AuthenticatedShell extends ConsumerWidget {
  const AuthenticatedShell({required this.navigationShell, super.key});

  /// The router's side of the shell: the current destination's screen, which
  /// draws its own toolbar, and the way between destinations.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Session? session = ref.watch(authControllerProvider).session;

    final ShellDestination current =
        ShellDestination.values[navigationShell.currentIndex];
    final List<AppNavDestination> destinations = <AppNavDestination>[
      for (final ShellDestination destination in ShellDestination.values)
        if (session != null && destination.isOpenTo(session.user))
          _describe(destination, strings),
    ];

    return AppShell(
      drawer: AppNavigationDrawer(
        profile: session == null
            ? null
            : AppDrawerProfile(
                name: session.user.name,
                // The workspace says which store this is — the thing a member
                // with more than one needs to know first.
                subtitle: session.workspace?.name ?? session.user.email,
                avatarUrl: session.user.avatarUrl,
              ),
        selectedId: current.name,
        onSelect: _select,
        groups: <AppNavGroup>[AppNavGroup(destinations: destinations)],
        footerActions: <AppDrawerAction>[
          AppDrawerAction(
            label: strings.signOut,
            icon: LucideIcons.logOut,
            destructive: true,
            // The router reacts to the session ending and moves to sign-in on
            // its own; nothing here navigates.
            onPressed: () =>
                unawaited(ref.read(authControllerProvider.notifier).signOut()),
          ),
        ],
      ),
      destinations: destinations,
      selectedId: current.name,
      onSelect: _select,
      body: navigationShell,
    );
  }

  void _select(String id) {
    final ShellDestination destination = ShellDestination.values.byName(id);

    navigationShell.goBranch(
      destination.index,
      // Picking the destination already open returns it to where it starts,
      // the way tapping the current tab does everywhere else.
      initialLocation: destination.index == navigationShell.currentIndex,
    );
  }

  /// How [destination] is drawn. A switch, so a destination added without an
  /// icon and a label does not compile.
  static AppNavDestination _describe(
    ShellDestination destination,
    AppStrings strings,
  ) {
    return switch (destination) {
      ShellDestination.inbox => AppNavDestination(
        id: destination.name,
        label: strings.inbox,
        icon: LucideIcons.messagesSquare,
      ),
    };
  }
}
