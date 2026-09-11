import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The frame every unauthenticated screen sits in.
///
/// Owns the four things a sign-in screen gets wrong when each one writes it
/// again: it centres when there is room and scrolls when there is not, it
/// stays out from under the keyboard, it caps its width so a form on a tablet
/// is not a strip of text the width of the display, and it keeps one corner for
/// a control that belongs to the screen rather than the form — the language.
///
/// It draws nothing decorative. The reference places soft warm shapes behind
/// the form; the brief for this system rules out decoration without a job, and
/// a sign-in screen is the last place to spend a member's attention on it.
class AppAuthLayout extends StatelessWidget {
  const AppAuthLayout({
    required this.child,
    this.logo,
    this.header,
    this.footer,
    this.topEnd,
    this.maxWidth = 400,
    super.key,
  });

  /// The form.
  final Widget child;

  final Widget? logo;
  final Widget? header;

  /// Under the form: a security note, a legal line.
  final Widget? footer;

  /// The top-end corner — top-left in Arabic. A language switcher, usually.
  final Widget? topEnd;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: <Widget>[
          if (topEnd != null)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: TajeerSpacing.md,
                vertical: TajeerSpacing.xs,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: topEnd,
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                const double padding = TajeerSpacing.lg;
                final double minHeight = (constraints.maxHeight - padding * 2)
                    .clamp(0, double.infinity);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(padding),
                  child: ConstrainedBox(
                    // Tall enough to centre a short form, and no taller: past
                    // this the scroll view takes over, which is what keeps the
                    // Sign in button reachable with the keyboard up.
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (logo != null) ...<Widget>[
                              Center(child: logo),
                              const SizedBox(height: TajeerSpacing.lg),
                            ],
                            if (header != null) ...<Widget>[
                              header!,
                              const SizedBox(height: TajeerSpacing.xl),
                            ],
                            child,
                            if (footer != null) ...<Widget>[
                              const SizedBox(height: TajeerSpacing.lg),
                              footer!,
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
