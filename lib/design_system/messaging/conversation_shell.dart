import 'package:flutter/material.dart';

import '../layouts/app_scaffold.dart';

/// The frame of one conversation: its header, the thread, and the composer
/// under it.
///
/// Composition, and thin on purpose. What it settles is the arrangement every
/// thread shares — the thread takes the space, the composer sits on the bottom
/// edge and rides up with the keyboard, a notice about the connection sits
/// under the header — so no screen works it out again.
class AppConversationShell extends StatelessWidget {
  const AppConversationShell({
    required this.toolbar,
    required this.timeline,
    required this.composer,
    this.banner,
    super.key,
  });

  /// Normally `AppToolbar.conversation`.
  final PreferredSizeWidget toolbar;

  /// Normally `AppMessageTimeline`.
  final Widget timeline;

  /// Normally `AppComposer`.
  final Widget composer;

  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      toolbar: toolbar,
      banner: banner,
      body: Column(
        children: <Widget>[
          Expanded(child: timeline),
          composer,
        ],
      ),
    );
  }
}
