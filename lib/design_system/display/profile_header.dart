import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../loaders/skeleton.dart';
import '../localization/ds_localization.dart';
import '../primitives/pressable.dart';
import 'avatar.dart';

/// One thing that can be done from a profile: call, message, write a note.
@immutable
class AppProfileAction {
  const AppProfileAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

/// Who a person is, at the top of their page.
///
/// A picture, a name, a line about them, what they are, and what can be done.
/// Two sizes of the same facts: the default heads a page, centred; [compact]
/// is a row — a drawer's account, a card over a call.
///
/// **Three actions at most.** A fourth stops being an action row and becomes
/// a menu nobody reads at a glance; more belongs further down the page.
class AppProfileHeader extends StatelessWidget {
  const AppProfileHeader({
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.badges = const <Widget>[],
    this.actions = const <AppProfileAction>[],
    this.compact = false,
    this.onTap,
    super.key,
  }) : _placeholder = false;

  /// The shape of a header whose person has not loaded yet.
  ///
  /// Shaped like the real one, so nothing below it jumps when it arrives.
  const AppProfileHeader.placeholder({this.compact = false, super.key})
    : name = '',
      subtitle = null,
      avatarUrl = null,
      badges = const <Widget>[],
      actions = const <AppProfileAction>[],
      onTap = null,
      _placeholder = true;

  final String name;
  final String? subtitle;
  final String? avatarUrl;

  /// What the person is — a role, a tag — usually `AppBadge`s.
  final List<Widget> badges;

  final List<AppProfileAction> actions;
  final bool compact;

  /// Opens the person. Compact only: a page's header is already their page.
  final VoidCallback? onTap;

  final bool _placeholder;

  @override
  Widget build(BuildContext context) {
    assert(actions.length <= 3, 'A profile offers three actions at most.');

    if (_placeholder) return _Placeholder(compact: compact);

    return compact ? _compact(context) : _regular(context);
  }

  Widget _regular(BuildContext context) {
    final TajeerColors colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TajeerSpacing.md,
        vertical: TajeerSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          AppAvatar(name: name, imageUrl: avatarUrl, size: 72),
          Text(name, style: context.type.titleLg, textAlign: TextAlign.center),
          if (subtitle != null)
            Text(
              subtitle!,
              style: context.type.bodySm.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          if (badges.isNotEmpty)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: TajeerSpacing.xs,
              runSpacing: TajeerSpacing.xs,
              children: badges,
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TajeerSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: TajeerSpacing.lg,
                children: <Widget>[
                  for (final AppProfileAction action in actions)
                    Flexible(child: _LabelledAction(action: action)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context) {
    final TajeerColors colors = context.colors;

    return AppPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TajeerSpacing.md,
          vertical: TajeerSpacing.sm,
        ),
        child: Row(
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            AppAvatar(name: name, imageUrl: avatarUrl, size: 44),
            Expanded(
              child: MergeSemantics(
                child: Semantics(
                  button: onTap != null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: TajeerSpacing.xs2,
                    children: <Widget>[
                      Text(
                        name,
                        style: context.type.titleSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.type.bodySm.copyWith(
                            color: colors.textMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (badges.isNotEmpty)
                        Wrap(
                          spacing: TajeerSpacing.xs,
                          runSpacing: TajeerSpacing.xs2,
                          children: badges,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            for (final AppProfileAction action in actions)
              AppButton.icon(
                icon: Icon(action.icon),
                semanticLabel: action.label,
                onPressed: action.onPressed,
              ),
          ],
        ),
      ),
    );
  }
}

/// An action under a page's header: a round button with its word beneath.
class _LabelledAction extends StatelessWidget {
  const _LabelledAction({required this.action});

  final AppProfileAction action;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: TajeerSpacing.xs2,
      children: <Widget>[
        AppButton.icon(
          icon: Icon(action.icon),
          semanticLabel: action.label,
          variant: AppButtonVariant.soft,
          shape: AppButtonShape.circle,
          onPressed: action.onPressed,
        ),
        // The button already carries the word, so it is heard once.
        ExcludeSemantics(
          child: Text(
            action.label,
            style: context.type.labelSm.copyWith(
              color: context.colors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget shape = compact
        ? const Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: TajeerSpacing.md,
              vertical: TajeerSpacing.sm,
            ),
            child: Row(
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                AppSkeleton.circle(size: 44),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: TajeerSpacing.xs,
                    children: <Widget>[
                      AppSkeleton.text(width: 140),
                      AppSkeleton.text(width: 96),
                    ],
                  ),
                ),
              ],
            ),
          )
        : const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TajeerSpacing.md,
              vertical: TajeerSpacing.lg,
            ),
            child: Column(
              spacing: TajeerSpacing.xs,
              children: <Widget>[
                AppSkeleton.circle(size: 72),
                AppSkeleton.text(width: 160),
                AppSkeleton.text(width: 112),
              ],
            ),
          );

    // Heard as loading, never as a person with no name.
    return Semantics(
      label: context.strings.loading,
      child: ExcludeSemantics(child: shape),
    );
  }
}
