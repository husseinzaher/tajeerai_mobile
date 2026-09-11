import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The screen shell.
///
/// Exists so screens stop repeating the same `Scaffold` configuration. Every
/// screen in the app goes through it.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.toolbar,
    this.floatingActionButton,
    this.banner,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;

  /// The screen's toolbar — an `AppToolbar`, and the only way a screen draws
  /// one. The older title-and-actions bar this scaffold used to build is gone:
  /// a scaffold with two ways to draw a title is how two screens end up with
  /// two different titles.
  final PreferredSizeWidget? toolbar;

  final Widget? floatingActionButton;

  /// A full-width strip pinned under the toolbar -- the connection and
  /// synchronisation notices land here rather than floating over content.
  final Widget? banner;

  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: toolbar,
      body: banner == null
          ? SafeArea(top: toolbar == null, child: body)
          : Column(
              children: <Widget>[
                banner!,
                Expanded(child: SafeArea(top: false, child: body)),
              ],
            ),
      floatingActionButton: floatingActionButton,
    );
  }
}
