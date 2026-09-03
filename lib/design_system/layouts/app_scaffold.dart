import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The screen shell.
///
/// Exists so screens stop repeating the same `Scaffold` configuration and so
/// the app bar's surface stays on `background` rather than Material's tinted
/// default. Every screen in the app goes through it.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.bottom,
    this.floatingActionButton,
    this.banner,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;

  /// A full-width strip pinned under the app bar -- the connection and
  /// synchronisation notices land here rather than floating over content.
  final Widget? banner;

  final bool resizeToAvoidBottomInset;

  bool get _hasAppBar =>
      title != null || titleWidget != null || showBack || leading != null;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: _hasAppBar
          ? AppBar(
              backgroundColor: colors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              leading:
                  leading ??
                  (showBack
                      ? BackButton(color: colors.foreground, onPressed: onBack)
                      : null),
              title:
                  titleWidget ??
                  (title == null
                      ? null
                      : Text(title!, style: context.text.titleLarge)),
              actions: actions,
              bottom: bottom,
              // A hairline under the bar, matching the web's `border-b`.
              shape: Border(bottom: BorderSide(color: colors.border)),
            )
          : null,
      body: banner == null
          ? SafeArea(top: !_hasAppBar, child: body)
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
