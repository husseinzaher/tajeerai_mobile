import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/theme.dart';
import '../../buttons/app_button.dart';
import '../../cards/app_card.dart';
import '../../display/avatar.dart';
import '../../display/badge.dart';
import '../../display/avatar_group.dart';
import '../../display/chip.dart';
import '../../display/labelled_separator.dart';
import '../../display/list_item.dart';
import '../../display/list_section.dart';
import '../../display/section_header.dart';
import '../../display/segmented_control.dart';
import '../../display/status_dot.dart';
import '../../display/tabs.dart';
import '../../display/separator.dart';
import '../../feedback/async_view.dart';
import '../../feedback/connection_banner.dart';
import '../../feedback/empty_state.dart';
import '../../feedback/error_state.dart';
import '../../feedback/inline_error.dart';
import '../../feedback/loading_state.dart';
import '../../feedback/progress_bar.dart';
import '../../feedback/status_banner.dart';
import '../../feedback/tooltip.dart';
import '../../inputs/app_checkbox.dart';
import '../../inputs/app_radio.dart';
import '../../inputs/app_select.dart';
import '../../inputs/app_switch.dart';
import '../../inputs/app_text_field.dart';
import '../../inputs/otp_field.dart';
import '../../inputs/password_field.dart';
import '../../inputs/search_field.dart';
import '../../loaders/app_splash.dart';
import '../../loaders/skeleton.dart';
import '../../loaders/spinner.dart';
import '../../overlays/action_sheet.dart';
import '../../overlays/app_bottom_sheet.dart';
import '../../overlays/app_dialog.dart';
import '../../overlays/app_snackbar.dart';
import '../../primitives/bidi_text.dart';
import '../../primitives/pressable.dart';
import '../showcase_fixtures.dart';
import '../showcase_section.dart';

ShowcaseSection buttonsSection() => ShowcaseSection(
  title: 'Buttons',
  icon: LucideIcons.mousePointerClick,
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Variants',
      description:
          'The link variant draws its text in `focus`, not `primary`: in the '
          'light palette the accent is 1.53:1 on white and cannot carry text.',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.xs,
        runSpacing: TajeerSpacing.xs,
        children: <Widget>[
          for (final AppButtonVariant variant in AppButtonVariant.values)
            AppButton(label: variant.name, variant: variant, onPressed: () {}),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Sizes',
      description:
          'Every height is a minimum. 44 is the platform touch-target floor, '
          'which the previous 36 and 32 did not meet.',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.xs,
        runSpacing: TajeerSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final AppButtonSize size in <AppButtonSize>[
            AppButtonSize.small,
            AppButtonSize.medium,
            AppButtonSize.large,
          ])
            AppButton(label: size.name, size: size, onPressed: () {}),
          AppButton.icon(
            icon: const Icon(LucideIcons.ellipsis),
            semanticLabel: 'More',
            onPressed: () {},
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'States',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.xs,
        runSpacing: TajeerSpacing.xs,
        children: <Widget>[
          AppButton(label: 'Enabled', onPressed: () {}),
          const AppButton(label: 'Disabled'),
          AppButton(label: 'Loading', loading: true, onPressed: () {}),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Shape and badge',
      description:
          'The badge sits at the top-END corner, so it flips in Arabic. That '
          'slot is why there is no NotificationButton.',
      builder: (BuildContext context) => Row(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppButton.icon(
            icon: const Icon(LucideIcons.bell),
            semanticLabel: 'Notifications',
            badge: const AppBadge(label: '3'),
            onPressed: () {},
          ),
          AppButton.icon(
            icon: const Icon(LucideIcons.send),
            semanticLabel: 'Send',
            variant: AppButtonVariant.primary,
            shape: AppButtonShape.circle,
            onPressed: () {},
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Full width',
      builder: (BuildContext context) => AppButton(
        label: 'تسجيل الدخول',
        size: AppButtonSize.large,
        expand: true,
        trailing: const Icon(LucideIcons.arrowLeft),
        onPressed: () {},
      ),
    ),
    ShowcaseExample(
      name: 'Pressable',
      description:
          'The surface under everything tappable. A press washes it rather '
          'than recolouring it, so the same component reads on any '
          'background. Its scale comes from context.motion, which is where '
          'reduced motion is decided — no component checks for it.',
      builder: (BuildContext context) => AppPressable(
        onTap: () {},
        borderRadius: TajeerRadii.lgAll,
        child: Padding(
          padding: const EdgeInsets.all(TajeerSpacing.md),
          child: Text('طلب #1042 — اضغط هنا', style: context.type.bodyMd),
        ),
      ),
    ),
  ],
);

ShowcaseSection formsSection() => ShowcaseSection(
  title: 'Forms',
  icon: LucideIcons.textCursorInput,
  description:
      'Every control here draws its edge with the same AppFieldSurface, and '
      'its label with the same AppFieldScaffold.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Text field',
      builder: (BuildContext context) => Column(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          const AppTextField(
            label: 'البريد الإلكتروني',
            hintText: 'name@yourstore.com',
            leading: Icon(LucideIcons.mail),
          ),
          const AppTextField(
            label: 'With a description',
            description:
                'Helper text sits under the field until an error does.',
          ),
          const AppTextField(
            label: 'Invalid',
            errorText: 'That does not look like an email address.',
          ),
          const AppTextField(label: 'Disabled', enabled: false),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Multiline',
      builder: (BuildContext context) =>
          const AppTextField.multiline(label: 'Note', minLines: 3),
    ),
    ShowcaseExample(
      name: 'Password',
      description:
          'The reveal is a 44px target, and its label changes with it.',
      builder: (BuildContext context) =>
          const AppPasswordField(label: 'كلمة المرور'),
    ),
    ShowcaseExample(
      name: 'Search',
      builder: (BuildContext context) =>
          AppSearchField(controller: TextEditingController()),
    ),
    ShowcaseExample(
      name: 'Select',
      description: 'Opens a sheet, not a dropdown. Tap it.',
      builder: (BuildContext context) => const _SelectDemo(),
    ),
    ShowcaseExample(
      name: 'Searchable select',
      description:
          'The same component with searchable: true — not a sibling. The match '
          'folds the alef family and drops harakat, so "احمد" finds "أحمد", '
          'which is how people actually type.',
      builder: (BuildContext context) => const _SearchableSelectDemo(),
    ),
    ShowcaseExample(
      name: 'Checkbox and switch',
      description: 'The whole row is the target, not the 22px box.',
      builder: (BuildContext context) => const _TogglesDemo(),
    ),
    ShowcaseExample(
      name: 'Radio group',
      builder: (BuildContext context) => const _RadioDemo(),
    ),
    ShowcaseExample(
      name: 'One-time code',
      description:
          'Pinned left-to-right whatever the direction: a code is a sequence, '
          'not a sentence. Switch to RTL and watch it stay put.',
      builder: (BuildContext context) => const AppOtpField(length: 6),
    ),
  ],
);

ShowcaseSection displaySection() => ShowcaseSection(
  title: 'Display',
  icon: LucideIcons.layoutGrid,
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Badges',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.xs,
        runSpacing: TajeerSpacing.xs,
        children: <Widget>[
          for (final AppBadgeVariant variant in AppBadgeVariant.values)
            AppBadge(label: variant.name, variant: variant),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Avatars',
      description: 'Initials are grapheme-safe, so Arabic names work.',
      builder: (BuildContext context) => const Row(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppAvatar(name: ShowcaseFixtures.customer),
          AppAvatar(name: 'Nour Store', size: 32),
          AppAvatar(name: 'خالد عبدالله', size: 56),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Chips',
      description:
          'A control, not a badge: it has a pressed state, a selected state and '
          'a 44px target. Removing and selecting are separate taps.',
      builder: (BuildContext context) => const _ChipsDemo(),
    ),
    ShowcaseExample(
      name: 'Presence and avatar groups',
      description:
          'An unknown presence draws nothing. Unknown is not offline, and a '
          'grey dot is a confident answer to a question the app cannot answer.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          Row(
            spacing: TajeerSpacing.md,
            children: <Widget>[
              AppAvatar(
                name: ShowcaseFixtures.customer,
                presence: AppPresence.online,
              ),
              AppAvatar(
                name: ShowcaseFixtures.secondCustomer,
                presence: AppPresence.away,
              ),
              AppAvatar(name: 'خالد', presence: AppPresence.busy),
              AppAvatar(name: 'نورة', presence: AppPresence.offline),
              AppAvatar(name: 'ريم', presence: AppPresence.unknown),
            ],
          ),
          AppAvatarGroup(
            names: <String>['أحمد', 'سارة', 'خالد', 'نورة', 'محمد'],
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Status dots',
      description:
          'One primitive, and meanings that must not be swapped at a call '
          'site: a person, and whether the data is current (under States). '
          'The ring is a cutout, so a dot stays legible on a photograph.',
      builder: (BuildContext context) => Row(
        spacing: TajeerSpacing.md,
        children: <Widget>[
          for (final AppPresence presence in AppPresence.values)
            AppPresenceDot(presence: presence, label: presence.name),
          AppStatusDot(color: context.colors.primary, size: 14),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Text somebody else wrote',
      description:
          'A customer writes in their own language. Laid out in the app\'s '
          'direction, an English question in an Arabic list reads "?before it '
          'ships". AppBidiText keeps the words\' own direction, and lines each '
          'one up with the row.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          AppBidiText(
            'Can I change the size before it ships?',
            alignToAmbient: true,
          ),
          AppBidiText('هل يمكن تغيير المقاس قبل الشحن؟', alignToAmbient: true),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'List items',
      description:
          'Emphasis is a flag, not something each list styles for itself — '
          'which is how two lists end up disagreeing about what unread looks '
          'like. The selected row is marked on the START edge, so it flips.',
      builder: (BuildContext context) => const _ListDemo(),
    ),
    ShowcaseExample(
      name: 'Tabs and segmented control',
      description:
          'Not the same widget. Tabs navigate a panel; a segmented control '
          'picks a value and announces itself as mutually exclusive. Merging '
          'them would force one to lie to a screen reader.',
      builder: (BuildContext context) => const _TabsDemo(),
    ),
    ShowcaseExample(
      name: 'Labelled separator',
      builder: (BuildContext context) => const Column(
        spacing: TajeerSpacing.md,
        children: <Widget>[
          AppLabelledSeparator(label: 'أو تابع باستخدام'),
          AppLabelledSeparator(
            label: 'رسائل غير مقروءة',
            tone: AppSeparatorTone.primary,
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Tooltip',
      description:
          'Long-press only — there is no hover on a phone. The semantic label '
          'is the real accessibility answer; this is the extra sentence.',
      builder: (BuildContext context) => AppTooltip(
        message: 'تمت المزامنة قبل دقيقتين',
        child: AppBadge(label: 'متزامن', variant: AppBadgeVariant.muted),
      ),
    ),
    ShowcaseExample(
      name: 'Card and section header',
      builder: (BuildContext context) => const AppCard(
        child: Column(
          spacing: TajeerSpacing.sm,
          children: <Widget>[
            AppSectionHeader(
              title: 'قنوات التواصل',
              description:
                  'The channels this workspace can reach customers on.',
            ),
            AppSeparator(),
            AppSectionHeader(
              title: 'Selected',
              description: 'With a trailing slot',
            ),
          ],
        ),
      ),
    ),
  ],
);

Widget _names(List<String> names) => Text(names.join('، '));

bool _isEmpty(List<String> names) => names.isEmpty;

ShowcaseSection statesSection() => ShowcaseSection(
  title: 'States',
  icon: LucideIcons.circleAlert,
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Loading',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppSpinner(),
          AppSkeleton.text(width: 220),
          AppSkeleton.text(width: 160),
          AppSkeleton.circle(),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Loading, as a screen draws it',
      description:
          'A wait with no shape of its own is a spinner. A list on its way '
          'draws rows shaped like the ones it stands in for, so nothing jumps '
          'when the first real one lands. Either way it is one word to a '
          'screen reader.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppLoadingState(),
          // Whole rows: a placeholder cut in half reads as a rendering bug.
          SizedBox(height: 160, child: AppLoadingState.list(rows: 2)),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Splash',
      description: 'Before the first screen has anything to say.',
      builder: (BuildContext context) =>
          const SizedBox(height: 120, child: AppSplash()),
    ),
    ShowcaseExample(
      name: 'Async view',
      description:
          'The four states, drawn one way everywhere. Loaded and empty are one '
          'value to the data layer and two different pictures here, so the '
          'caller says what empty means for its own type.',
      builder: (BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TajeerSpacing.md,
        children: <Widget>[
          const AppAsyncView<List<String>>(
            state: AppViewLoading<List<String>>(),
            data: _names,
          ),
          AppAsyncView<List<String>>(
            state: AppViewFailed<List<String>>(
              'تعذّر تحميل القائمة.',
              onRetry: () {},
            ),
            data: _names,
          ),
          const AppAsyncView<List<String>>(
            state: AppViewLoaded<List<String>>(<String>[]),
            isEmpty: _isEmpty,
            data: _names,
          ),
          const AppAsyncView<List<String>>(
            state: AppViewLoaded<List<String>>(<String>[
              ShowcaseFixtures.customer,
              ShowcaseFixtures.secondCustomer,
            ]),
            isEmpty: _isEmpty,
            data: _names,
          ),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Progress',
      description:
          'null is indeterminate — something is happening and nobody can say '
          'how much is left. A different claim from 0, which says it has not '
          'started.',
      builder: (BuildContext context) => const Column(
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppProgressBar(value: 0.35),
          AppProgressBar(value: 0.8, tone: AppProgressTone.success),
          AppProgressBar(),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Empty',
      builder: (BuildContext context) => const AppEmptyState(
        title: 'لا توجد محادثات بعد',
        description: 'ستظهر هنا المحادثات الواردة من قنوات التواصل.',
        icon: LucideIcons.messageCircle,
      ),
    ),
    ShowcaseExample(
      name: 'Error',
      builder: (BuildContext context) => AppErrorState(
        message: 'تعذّر تحميل المحادثات. تحقق من اتصالك وحاول مرة أخرى.',
        onRetry: () {},
      ),
    ),
    ShowcaseExample(
      name: 'Inline error',
      builder: (BuildContext context) =>
          const AppInlineError(message: 'كلمة المرور غير صحيحة'),
    ),
    ShowcaseExample(
      name: 'Banners',
      description:
          'Offline is a condition, not a failure — the data on screen is still '
          'valid, so it wears warning rather than danger.',
      builder: (BuildContext context) => const Column(
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          AppStatusBanner(
            message: 'عرض الرسائل المحفوظة. جارٍ إعادة الاتصال…',
            icon: LucideIcons.wifiOff,
          ),
          AppStatusBanner(
            message: 'تمت المزامنة',
            tone: AppStatusTone.success,
            icon: LucideIcons.check,
          ),
          AppStatusBanner(message: 'Neutral', tone: AppStatusTone.neutral),
        ],
      ),
    ),
    ShowcaseExample(
      name: 'Connection dot',
      description:
          'The connection banner, where there is no room for a sentence. Same '
          'status, so the two never disagree. Nothing is drawn while current, '
          'which also means not yet asked; and the words always reach a screen '
          'reader, because offline and a failed catch-up share a colour.',
      builder: (BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TajeerSpacing.sm,
        children: <Widget>[
          AppConnectionDot(
            status: AppConnectionStatus.syncing,
            showLabel: true,
          ),
          AppConnectionDot(
            status: AppConnectionStatus.offline,
            showLabel: true,
          ),
          AppConnectionDot(status: AppConnectionStatus.failed, showLabel: true),
          Row(
            spacing: TajeerSpacing.sm,
            children: <Widget>[
              AppConnectionDot(status: AppConnectionStatus.current),
              AppConnectionDot(status: AppConnectionStatus.syncing),
              AppConnectionDot(status: AppConnectionStatus.offline),
            ],
          ),
        ],
      ),
    ),
  ],
);

ShowcaseSection overlaysSection() => ShowcaseSection(
  title: 'Overlays',
  icon: LucideIcons.layers,
  description: 'These open. Tap them.',
  examples: <ShowcaseExample>[
    ShowcaseExample(
      name: 'Dialog',
      builder: (BuildContext context) => AppButton(
        label: 'Open a confirmation',
        variant: AppButtonVariant.outline,
        onPressed: () => AppDialog.confirm(
          context: context,
          title: 'حذف المحادثة؟',
          message: 'لا يمكن التراجع عن هذا الإجراء.',
          destructive: true,
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Bottom sheet',
      builder: (BuildContext context) => AppButton(
        label: 'Open a sheet',
        variant: AppButtonVariant.outline,
        onPressed: () => AppBottomSheet.show<void>(
          context: context,
          sheet: const AppBottomSheet(
            title: 'قنوات التواصل',
            description: 'Pick where this message goes.',
            child: SizedBox(height: 120),
          ),
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Action sheet',
      description:
          'Composed over the bottom sheet, not a second one. This is the '
          'long-press menu, the overflow menu, and why there is no ProfileMenu.',
      builder: (BuildContext context) => AppButton(
        label: 'Open actions',
        variant: AppButtonVariant.outline,
        onPressed: () => AppActionSheet.show(
          context: context,
          title: ShowcaseFixtures.customer,
          actions: <AppAction>[
            AppAction(
              label: 'تثبيت المحادثة',
              icon: LucideIcons.pin,
              onSelected: () {},
            ),
            AppAction(
              label: 'كتم الإشعارات',
              icon: LucideIcons.bellOff,
              onSelected: () {},
            ),
            AppAction(
              label: 'حذف المحادثة',
              icon: LucideIcons.trash2,
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
      ),
    ),
    ShowcaseExample(
      name: 'Snackbar',
      builder: (BuildContext context) => Wrap(
        spacing: TajeerSpacing.xs,
        children: <Widget>[
          AppButton(
            label: 'Neutral',
            variant: AppButtonVariant.outline,
            onPressed: () =>
                AppSnackbar.show(context, message: 'تم حفظ التغييرات'),
          ),
          AppButton(
            label: 'Error',
            variant: AppButtonVariant.outline,
            onPressed: () => AppSnackbar.error(context, 'تعذّر الإرسال'),
          ),
        ],
      ),
    ),
  ],
);

// --- stateful demos --------------------------------------------------------
// The showcase owns the state a controlled component needs, exactly as a screen
// would. It never owns a *variant* of the component.

class _ChipsDemo extends StatefulWidget {
  const _ChipsDemo();

  @override
  State<_ChipsDemo> createState() => _ChipsDemoState();
}

class _ChipsDemoState extends State<_ChipsDemo> {
  final Set<String> _selected = <String>{'الكل'};
  final List<String> _filters = <String>[
    'الكل',
    'غير مقروءة',
    'مهمة',
    'مؤرشفة',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: TajeerSpacing.xs,
    runSpacing: TajeerSpacing.xs,
    children: <Widget>[
      for (final String filter in _filters)
        AppChip(
          label: filter,
          selected: _selected.contains(filter),
          onTap: () => setState(() {
            _selected.contains(filter)
                ? _selected.remove(filter)
                : _selected.add(filter);
          }),
          onRemove: filter == 'الكل'
              ? null
              : () => setState(() => _filters.remove(filter)),
        ),
    ],
  );
}

class _ListDemo extends StatefulWidget {
  const _ListDemo();

  @override
  State<_ListDemo> createState() => _ListDemoState();
}

class _ListDemoState extends State<_ListDemo> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => AppListSection(
    title: 'المحادثات',
    children: <Widget>[
      AppListItem(
        leading: const AppAvatar(
          name: ShowcaseFixtures.customer,
          presence: AppPresence.online,
        ),
        title: const Text(ShowcaseFixtures.customer),
        subtitle: const Text('مرحباً، هل المنتج ما زال متوفر؟'),
        meta: const Text('10:24'),
        trailing: AppBadge.count(3),
        emphasised: true,
        selected: _selected == 0,
        onTap: () => setState(() => _selected = 0),
      ),
      AppListItem(
        leading: const AppAvatar(name: ShowcaseFixtures.store),
        title: const Text(ShowcaseFixtures.store),
        subtitle: const Text('تم شحن طلبك بنجاح'),
        meta: const Text('09:15'),
        selected: _selected == 1,
        onTap: () => setState(() => _selected = 1),
      ),
      AppListItem(
        leading: const AppAvatar(
          name: ShowcaseFixtures.secondCustomer,
          presence: AppPresence.away,
        ),
        title: const Text(ShowcaseFixtures.secondCustomer),
        subtitle: const Text('كم مدة التوصيل؟'),
        meta: const Text('أمس'),
        selected: _selected == 2,
        onTap: () => setState(() => _selected = 2),
      ),
    ],
  );
}

class _TabsDemo extends StatefulWidget {
  const _TabsDemo();

  @override
  State<_TabsDemo> createState() => _TabsDemoState();
}

class _TabsDemoState extends State<_TabsDemo> {
  int _tab = 0;
  String _segment = 'all';

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: TajeerSpacing.md,
    children: <Widget>[
      AppTabs(
        index: _tab,
        onChanged: (int i) => setState(() => _tab = i),
        tabs: <AppTab>[
          const AppTab(label: 'الكل'),
          AppTab(label: 'غير مقروءة', badge: AppBadge.count(12)),
          const AppTab(label: 'مؤرشفة'),
        ],
      ),
      AppSegmentedControl<String>(
        value: _segment,
        options: const <String, String>{'all': 'الكل', 'mine': 'المسندة إليّ'},
        onChanged: (String v) => setState(() => _segment = v),
      ),
    ],
  );
}

class _SelectDemo extends StatefulWidget {
  const _SelectDemo();

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  String? _value = 'whatsapp';

  @override
  Widget build(BuildContext context) => AppSelect<String>(
    label: 'القناة',
    value: _value,
    options: const <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: 'whatsapp',
        label: 'WhatsApp',
        description: 'محادثات واتساب للأعمال',
      ),
      AppSelectOption<String>(value: 'instagram', label: 'Instagram'),
      AppSelectOption<String>(value: 'email', label: 'Email'),
      AppSelectOption<String>(
        value: 'sms',
        label: 'SMS',
        description: 'Not connected',
        enabled: false,
      ),
    ],
    onChanged: (String value) => setState(() => _value = value),
  );
}

class _SearchableSelectDemo extends StatefulWidget {
  const _SearchableSelectDemo();

  @override
  State<_SearchableSelectDemo> createState() => _SearchableSelectDemoState();
}

class _SearchableSelectDemoState extends State<_SearchableSelectDemo> {
  String? _value;

  @override
  Widget build(BuildContext context) => AppSelect<String>(
    label: 'أسند إلى',
    placeholder: 'اختر عضو الفريق',
    searchable: true,
    value: _value,
    options: const <AppSelectOption<String>>[
      AppSelectOption<String>(
        value: '1',
        label: 'أحمد محمد',
        description: 'مالك المتجر',
      ),
      AppSelectOption<String>(
        value: '2',
        label: ShowcaseFixtures.customer,
        description: 'خدمة العملاء',
      ),
      AppSelectOption<String>(
        value: '3',
        label: 'خالد عبدالله',
        description: 'المبيعات',
      ),
      AppSelectOption<String>(
        value: '4',
        label: 'فاطمة الزهراء',
        description: 'التسويق',
      ),
      AppSelectOption<String>(
        value: '5',
        label: 'Reem Al-Saleh',
        description: 'Support',
      ),
      AppSelectOption<String>(
        value: '6',
        label: ShowcaseFixtures.secondCustomer,
        description: 'المبيعات',
      ),
      AppSelectOption<String>(
        value: '7',
        label: 'نورة سعد',
        description: 'خدمة العملاء',
      ),
      AppSelectOption<String>(
        value: '8',
        label: 'عبدالرحمن يوسف',
        description: 'الحسابات',
      ),
    ],
    onChanged: (String value) => setState(() => _value = value),
  );
}

class _TogglesDemo extends StatefulWidget {
  const _TogglesDemo();

  @override
  State<_TogglesDemo> createState() => _TogglesDemoState();
}

class _TogglesDemoState extends State<_TogglesDemo> {
  bool _remember = true;
  bool _notify = false;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      AppCheckbox(
        value: _remember,
        label: 'تذكرني',
        onChanged: (bool value) => setState(() => _remember = value),
      ),
      AppSwitch(
        value: _notify,
        label: 'الإشعارات',
        description: 'Takes effect immediately, which is why it is a switch.',
        onChanged: (bool value) => setState(() => _notify = value),
      ),
      // `onChanged` is required even when null: a disabled control still has
      // to say what it would have done, which stops "disabled" being spelled
      // by quietly omitting the callback.
      const AppCheckbox(
        value: true,
        label: 'Disabled',
        enabled: false,
        onChanged: null,
      ),
    ],
  );
}

class _RadioDemo extends StatefulWidget {
  const _RadioDemo();

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _value = 'all';

  @override
  Widget build(BuildContext context) => AppRadioGroup<String>(
    value: _value,
    options: const <AppRadioOption<String>>[
      AppRadioOption<String>(value: 'all', label: 'كل المحادثات'),
      AppRadioOption<String>(
        value: 'mine',
        label: 'المسندة إليّ',
        description: 'Only conversations assigned to you',
      ),
      AppRadioOption<String>(value: 'unread', label: 'غير مقروءة'),
    ],
    onChanged: (String value) => setState(() => _value = value),
  );
}
