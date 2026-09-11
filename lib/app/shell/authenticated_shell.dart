import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../design_system/design_system.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../localization/translations/app_strings.dart';
import '../router/routes.dart';

/// The frame around every signed-in screen.
///
/// Composition, which is why it lives in `app/`: it joins the design system's
/// [AppShell] to the session, and to the routes — three things no single
/// feature owns.
///
/// **Only destinations that exist.** The Inbox is the one signed-in screen
/// today, so the drawer holds it and the way out, and there is no bottom bar:
/// a tab bar with one tab is a label. Customers, orders and the rest arrive
/// here with their screens, not before — a drawer entry for a screen that is
/// not built is a control that goes nowhere.
class AuthenticatedShell extends ConsumerWidget {
  const AuthenticatedShell({required this.child, super.key});

  /// The current signed-in screen, which draws its own toolbar.
  final Widget child;

  static const String _inbox = 'inbox';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Session? session = ref.watch(authControllerProvider).session;

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
        selectedId: _inbox,
        onSelect: (String id) => context.go(AppRoutes.conversations),
        groups: <AppNavGroup>[
          AppNavGroup(
            destinations: <AppNavDestination>[
              AppNavDestination(
                id: _inbox,
                label: strings.inbox,
                icon: LucideIcons.messagesSquare,
              ),
            ],
          ),
        ],
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
      body: child,
    );
  }
}
