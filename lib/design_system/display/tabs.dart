import 'package:flutter/material.dart';

import '../../app/theme/theme.dart';
import '../primitives/pressable.dart';

/// One tab.
@immutable
class AppTab {
  const AppTab({required this.label, this.icon, this.badge});

  final String label;
  final IconData? icon;

  /// A count or a dot beside the label — unread on an Inbox filter.
  final Widget? badge;
}

/// Tabs that select which panel is showing.
///
/// **Not interchangeable with `AppSegmentedControl`**, and the difference is
/// not visual. Tabs *navigate*: they announce a tab role and a selected tab,
/// and a screen reader treats the thing below as the panel they revealed. A
/// segmented control *picks a value* — it is a form control that happens to
/// look like a row. Merging them would force one of the two to lie about what
/// it is, and the one that lies is always the one nobody tested with a reader.
///
/// Scrollable by default, because a filter row in Arabic is as long as its
/// longest word and there is no honest way to know that in advance.
class AppTabs extends StatelessWidget {
  const AppTabs({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.scrollable = true,
    super.key,
  });

  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;

    final Widget row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: <Widget>[
        for (int i = 0; i < tabs.length; i++)
          if (scrollable)
            _Tab(tab: tabs[i], selected: i == index, onTap: () => onChanged(i))
          else
            Expanded(
              child: _Tab(
                tab: tabs[i],
                selected: i == index,
                onTap: () => onChanged(i),
              ),
            ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.tab, required this.selected, required this.onTap});

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TajeerColors colors = context.colors;
    final Color ink = selected ? colors.textPrimary : colors.textMuted;

    return Semantics(
      // The role that makes a screen reader treat the panel below as this
      // tab's content.
      selected: selected,
      button: true,
      label: tab.label,
      child: ExcludeSemantics(
        child: AppPressable(
          onTap: onTap,
          child: AnimatedContainer(
            duration: context.motion.fast,
            curve: context.motion.standard,
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TajeerSpacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: TajeerSpacing.xs2,
              children: <Widget>[
                if (tab.icon != null) Icon(tab.icon, size: 16, color: ink),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.labelMd.copyWith(color: ink),
                ),
                ?tab.badge,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
