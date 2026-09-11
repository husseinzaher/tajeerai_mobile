import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';

/// The greeting over a sign-in form: a title and one line under it.
///
/// One widget rather than a title and a description beside each other. The web
/// design system splits them because JSX needs somewhere to hang the gap
/// between them; two Flutter widgets whose only shared job is that gap would be
/// ceremony.
class AppAuthHeader extends StatelessWidget {
  const AppAuthHeader({required this.title, this.description, super.key});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TajeerSpacing.xs,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.type.headlineXl,
          ),
        ),
        if (description != null)
          Text(
            description!,
            textAlign: TextAlign.center,
            style: context.type.bodyMd.copyWith(
              color: context.colors.textMuted,
            ),
          ),
      ],
    );
  }
}
