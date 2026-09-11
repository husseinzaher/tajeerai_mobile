import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/theme.dart';
import '../buttons/app_button.dart';
import '../display/avatar.dart';
import '../display/status_dot.dart';
import '../inputs/search_field.dart';
import '../localization/ds_localization.dart';
import '../localization/ds_messages.dart';
import '../primitives/pressable.dart';
import 'shell_scope.dart';

/// What the toolbar is doing at the moment.
enum AppToolbarMode {
  /// A title, a way back or into the menu, and the screen's actions.
  normal,

  /// The title becomes a search field, and back leaves search.
  search,

  /// Something is selected: the title counts it, and the actions act on it.
  selection,
}

/// The screen's toolbar.
///
/// **One widget with a mode, not three toolbars.** Normal, search and selection
/// are the same bar in three states, and keeping them in one widget is what
/// keeps the height, the back affordance and the transition between them the
/// same everywhere. A conversation header is a preset of it, not a fourth.
///
/// The leading slot fills itself in, in order: an explicit [leading]; a back
/// button when [showBack]; the menu button when the screen sits inside an
/// [AppShell] with a drawer. No screen wires the menu button by hand.
///
/// The back chevron points toward the *start* of the line, so it mirrors in
/// Arabic — a custom toolbar does not get that from Material's own back button,
/// and it is exactly what ships broken when nobody tests it.
///
/// The bar's height is fixed, because it lives in a `PreferredSize`, so its
/// text is held to the control text-scale ceiling — and has to stay unclipped
/// at that ceiling, which the showcase smoke test checks.
class AppToolbar extends StatelessWidget implements PreferredSizeWidget {
  const AppToolbar({
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.showBack = false,
    this.onBack,
    this.actions = const <Widget>[],
    this.centerTitle = false,
    this.mode = AppToolbarMode.normal,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
    this.onSearchClose,
    this.selectionCount = 0,
    this.selectionActions = const <Widget>[],
    this.onSelectionClose,
    super.key,
  });

  /// A thread's header: the person, their presence, and the way back.
  ///
  /// A factory over the same widget, not a second toolbar.
  factory AppToolbar.conversation({
    required String title,
    String? subtitle,
    String? avatarUrl,
    AppPresence presence = AppPresence.unknown,
    List<Widget> actions = const <Widget>[],
    VoidCallback? onBack,
    VoidCallback? onTitleTap,
    Key? key,
  }) => AppToolbar(
    key: key,
    showBack: true,
    onBack: onBack,
    actions: actions,
    titleWidget: _ConversationTitle(
      title: title,
      subtitle: subtitle,
      avatarUrl: avatarUrl,
      presence: presence,
      onTap: onTitleTap,
    ),
  );

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;

  /// Defaults to popping the route, which is what a back button means.
  final VoidCallback? onBack;

  final List<Widget> actions;
  final bool centerTitle;
  final AppToolbarMode mode;

  /// Required in search mode.
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClose;

  final int selectionCount;
  final List<Widget> selectionActions;
  final VoidCallback? onSelectionClose;

  static const double height = 56;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    assert(
      mode != AppToolbarMode.search || searchController != null,
      'AppToolbar in search mode needs a searchController.',
    );

    final TajeerColors colors = context.colors;
    final AppMessages strings = context.strings;

    final (
      Widget? leadingWidget,
      Widget? middle,
      List<Widget> trailing,
      Color background,
    ) = switch (mode) {
      AppToolbarMode.search => (
        _IconAction(
          icon: _backIcon(context),
          label: strings.back,
          onPressed: onSearchClose,
        ),
        AppSearchField(
          controller: searchController!,
          hintText: searchHint ?? strings.search,
          onChanged: onSearchChanged,
          autofocus: true,
        ),
        const <Widget>[],
        colors.background,
      ),
      // A tinted bar says "you are acting on a selection" before the count is
      // read.
      AppToolbarMode.selection => (
        _IconAction(
          icon: LucideIcons.x,
          label: strings.close,
          onPressed: onSelectionClose,
        ),
        _Title(
          text: AppMessages.interpolate(
            strings.selectedCount,
            <String, Object?>{'count': selectionCount},
          ),
        ),
        selectionActions,
        colors.primarySoft,
      ),
      AppToolbarMode.normal => (
        leading ?? _impliedLeading(context, strings),
        titleWidget ??
            (title == null ? null : _Title(text: title!, subtitle: subtitle)),
        actions,
        colors.background,
      ),
    };

    return AppBar(
      toolbarHeight: height,
      automaticallyImplyLeading: false,
      backgroundColor: background,
      foregroundColor: colors.textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: mode == AppToolbarMode.normal && centerTitle,
      titleSpacing: leadingWidget == null ? TajeerSpacing.md : TajeerSpacing.xs,
      leading: leadingWidget,
      title: middle == null ? null : TajeerTypography.clampForControl(middle),
      actions: <Widget>[
        ...trailing,
        const SizedBox(width: TajeerSpacing.xs),
      ],
      shape: Border(bottom: BorderSide(color: colors.border)),
    );
  }

  Widget? _impliedLeading(BuildContext context, AppMessages strings) {
    if (showBack) {
      return _IconAction(
        icon: _backIcon(context),
        label: strings.back,
        onPressed: onBack ?? () => Navigator.maybePop(context),
      );
    }
    final AppShellScope? shell = AppShellScope.maybeOf(context);
    if (shell != null && shell.hasDrawer) {
      return _IconAction(
        icon: LucideIcons.menu,
        label: strings.menu,
        onPressed: shell.openDrawer,
      );
    }
    return null;
  }

  /// Toward the start of the line: left in English, right in Arabic.
  static IconData _backIcon(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl
      ? LucideIcons.chevronRight
      : LucideIcons.chevronLeft;
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppButton.icon(
    icon: Icon(icon),
    semanticLabel: label,
    onPressed: onPressed,
  );
}

class _Title extends StatelessWidget {
  const _Title({required this.text, this.subtitle});

  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final Widget title = Semantics(
      header: true,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.type.titleMd,
      ),
    );

    if (subtitle == null) {
      return title;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        title,
        Text(
          subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.caption.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }
}

class _ConversationTitle extends StatelessWidget {
  const _ConversationTitle({
    required this.title,
    required this.presence,
    this.subtitle,
    this.avatarUrl,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final AppPresence presence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppAvatar(
          name: title,
          imageUrl: avatarUrl,
          size: 36,
          presence: presence,
        ),
        const SizedBox(width: TajeerSpacing.sm),
        Flexible(
          child: _Title(text: title, subtitle: subtitle),
        ),
      ],
    );

    return onTap == null
        ? content
        : AppPressable(
            onTap: onTap,
            borderRadius: TajeerRadii.mdAll,
            child: content,
          );
  }
}
