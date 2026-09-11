import 'package:flutter/widgets.dart';

/// What a screen inside an [AppShell] can know about the shell around it.
///
/// This is how a toolbar learns there is a drawer to open without any screen
/// wiring it up. The toolbar belongs to the screen and the drawer belongs to
/// the shell, so neither can hold a reference to the other — this is the one
/// thing they share.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    required this.hasDrawer,
    required this.openDrawer,
    required super.child,
    super.key,
  });

  /// Whether there is a drawer to open. A toolbar only offers the menu button
  /// when this is true — a menu button with nothing behind it is a dead
  /// control.
  final bool hasDrawer;

  final VoidCallback openDrawer;

  static AppShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellScope>();

  // The callback is rebuilt with the shell on every build, so comparing it
  // would notify every dependant every frame for no change they could see.
  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      hasDrawer != oldWidget.hasDrawer;
}
