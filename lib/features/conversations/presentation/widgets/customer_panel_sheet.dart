import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/locale_manager.dart';
import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../../customers/application/contracts/customer_record_capability.dart';
import '../../../orders/application/contracts/customer_orders_capability.dart';
import '../../domain/entities/conversation.dart';
import '../controllers/customer_panel_controller.dart';

/// The person behind a thread, in three tabs: who they are, what they bought,
/// what somebody promised to come back to.
///
/// The web's contact panel, drawn the way a phone draws a secondary surface -
/// as a bottom sheet over the thread rather than a third column beside it
/// (`AppBottomSheet` carries that mapping). Same header, same three tabs, same
/// order, so a member who knows one knows the other.
///
/// Everything here is read through two contracts, `CustomerRecordCapability`
/// and `CustomerOrdersCapability`, from the local database. The sheet draws
/// at once from what the phone holds and refreshes behind the first frame;
/// the orders tab refreshes only when it is opened, because it is the one tab
/// that costs a request.
class CustomerPanelSheet extends ConsumerStatefulWidget {
  const CustomerPanelSheet({
    required this.conversation,
    this.onOpenCustomer,
    this.onAddReminder,
    super.key,
  });

  final Conversation conversation;

  /// Opens the contact's own screen, or the form to create one.
  final VoidCallback? onOpenCustomer;

  /// Opens the note form, where a reminder is a note with a date.
  final VoidCallback? onAddReminder;

  @override
  ConsumerState<CustomerPanelSheet> createState() => _CustomerPanelSheetState();
}

enum _Tab { data, orders, followUps }

class _CustomerPanelSheetState extends ConsumerState<CustomerPanelSheet> {
  _Tab _tab = _Tab.data;

  String? get _customerId => widget.conversation.customerId;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final String? customerId = _customerId;

    final AsyncValue<Customer?> customer = customerId == null
        ? const AsyncValue<Customer?>.data(null)
        : ref.watch(panelCustomerProvider(customerId));

    if (customerId != null) {
      // Fires once per contact and is not awaited: the sheet is already
      // readable from the database, and a refresh must never gate the first
      // frame.
      ref.watch(panelRefreshProvider(customerId));
    }

    return AppBottomSheet(
      title: strings.customerPanelTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _header(context, strings, customer),
            const SizedBox(height: TajeerSpacing.sm),
            AppTabs(
              scrollable: false,
              tabs: <AppTab>[
                AppTab(label: strings.customerPanelTabData),
                AppTab(label: strings.customerPanelTabOrders),
                AppTab(label: strings.customerPanelTabFollowUps),
              ],
              index: _tab.index,
              onChanged: (int index) =>
                  setState(() => _tab = _Tab.values[index]),
            ),
            Flexible(
              child: switch (_tab) {
                _Tab.data => _DataTab(
                  conversation: widget.conversation,
                  customer: customer.value,
                  strings: strings,
                ),
                _Tab.orders => _OrdersTab(
                  customerId: customerId,
                  strings: strings,
                ),
                _Tab.followUps => _FollowUpsTab(
                  customerId: customerId,
                  strings: strings,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppStrings strings,
    AsyncValue<Customer?> customer,
  ) {
    final Conversation thread = widget.conversation;

    if (customer.isLoading && customer.value == null && _customerId != null) {
      return const AppProfileHeader.placeholder();
    }

    final Customer? person = customer.value;
    final bool registered = person != null;
    final String name =
        person?.displayName ??
        thread.customerName ??
        strings.customerPanelUnregistered;

    return AppProfileHeader(
      name: name,
      subtitle: _firstContact(context, strings, person, thread),
      avatarUrl: person?.photoUrl ?? thread.customerAvatarUrl,
      badges: <Widget>[
        AppBadge(
          label: registered
              ? strings.customerPanelRegistered
              : strings.customerPanelUnregistered,
          variant: registered ? AppBadgeVariant.success : AppBadgeVariant.muted,
          size: AppBadgeSize.small,
        ),
        if (person?.typeName case final String type)
          AppBadge(
            label: type,
            variant: AppBadgeVariant.primary,
            size: AppBadgeSize.small,
          ),
      ],
      // Three at most - the header's own ceiling. Call, remind, open: the
      // same three as the web's header, in the same order.
      actions: <AppProfileAction>[
        if (person?.phone case final String phone)
          AppProfileAction(
            icon: LucideIcons.phone,
            label: strings.customerPanelCall,
            onPressed: () => _dial(phone),
          ),
        if (registered && widget.onAddReminder != null)
          AppProfileAction(
            icon: LucideIcons.bellPlus,
            label: strings.customerPanelReminder,
            onPressed: widget.onAddReminder,
          ),
        if (widget.onOpenCustomer != null)
          AppProfileAction(
            icon: registered ? LucideIcons.userRound : LucideIcons.userPlus,
            label: registered
                ? strings.customerPanelOpen
                : strings.customerPanelUnregistered,
            onPressed: widget.onOpenCustomer,
          ),
      ],
    );
  }

  /// Hands the number to the dialler. The phone's own dialler, deliberately:
  /// placing the call is its job, and the caller card follows from there.
  Future<void> _dial(String phone) async {
    final Uri uri = Uri(scheme: 'tel', path: phone);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String? _firstContact(
    BuildContext context,
    AppStrings strings,
    Customer? person,
    Conversation thread,
  ) {
    final DateTime since = person?.createdAt ?? thread.createdAt;

    return strings.customerPanelFirstContact.replaceAll(
      '{date}',
      AppRelativeTime.forDay(
        since,
        locale: _locale(context),
        messages: context.strings,
      ),
    );
  }
}

String _locale(BuildContext context) =>
    Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';

// -- Details ------------------------------------------------------------------

class _DataTab extends StatelessWidget {
  const _DataTab({
    required this.conversation,
    required this.customer,
    required this.strings,
  });

  final Conversation conversation;
  final Customer? customer;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final Customer? person = customer;
    final String notSet = strings.customerPanelNotSet;
    final WhatsAppContact whatsApp =
        person?.whatsApp ?? const WhatsAppContact();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TajeerSpacing.md,
        TajeerSpacing.sm,
        TajeerSpacing.md,
        TajeerSpacing.lg,
      ),
      children: <Widget>[
        AppSectionHeader(title: strings.customerPanelFields),
        AppDetailRow(
          label: strings.customerPanelName,
          value: person?.displayName ?? conversation.customerName ?? notSet,
          icon: LucideIcons.user,
        ),
        AppDetailRow(
          label: strings.phone,
          value: person?.phone ?? notSet,
          icon: LucideIcons.phone,
          identifier: person?.phone != null,
          copyable: person?.phone != null,
        ),
        AppDetailRow(
          label: strings.email,
          value: person?.email ?? notSet,
          icon: LucideIcons.mail,
          identifier: person?.email != null,
        ),
        if (whatsApp.handle case final String handle)
          AppDetailRow(
            label: strings.customerPanelWhatsAppUsername,
            value: handle,
            icon: LucideIcons.atSign,
            identifier: true,
          ),
        if (whatsApp.userId case final String userId)
          AppDetailRow(
            label: strings.customerPanelWhatsAppUserId,
            value: userId,
            icon: LucideIcons.hash,
            identifier: true,
            copyable: true,
          ),
        AppDetailRow(
          label: strings.customerPanelLanguage,
          // The language's name in its own script, the way the language
          // switcher writes it - a property of the locale, not a translation.
          value: switch (person?.locale) {
            'ar' => AppLocale.arabic.nativeName,
            'en' => AppLocale.english.nativeName,
            final String other => other,
            null => notSet,
          },
          icon: LucideIcons.languages,
        ),
        if (person?.notes case final String about when about.trim().isNotEmpty)
          AppDetailRow(
            label: strings.customerStandingNote,
            value: about,
            icon: LucideIcons.notebookPen,
          ),
        const SizedBox(height: TajeerSpacing.md),
        AppSectionHeader(title: strings.customerPanelTags),
        if ((person?.tags ?? conversation.tags).isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.xs),
            child: Text(
              strings.customerPanelNoTags,
              style: context.type.bodySm.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          )
        else
          Wrap(
            spacing: TajeerSpacing.xs,
            runSpacing: TajeerSpacing.xs,
            children: <Widget>[
              for (final String tag in <String>{
                ...conversation.tags,
                ...?person?.tags,
              })
                AppChip(label: tag),
            ],
          ),
        const SizedBox(height: TajeerSpacing.md),
        AppSectionHeader(title: strings.customerPanelConversation),
        AppDetailRow(
          label: strings.customerPanelStatus,
          value: _stateLabel(conversation.state, strings),
          icon: LucideIcons.circleDot,
        ),
        AppDetailRow(
          label: strings.customerPanelAssignee,
          value: conversation.assigneeId == null
              ? strings.customerPanelUnassigned
              : strings.customerPanelAssigned,
          icon: LucideIcons.userCheck,
        ),
        AppDetailRow(
          label: strings.customerPanelStarted,
          value: AppRelativeTime.forDay(
            conversation.createdAt,
            locale: _locale(context),
            messages: context.strings,
          ),
          icon: LucideIcons.calendarDays,
        ),
        if (conversation.lastMessageAt case final DateTime at)
          AppDetailRow(
            label: strings.customerPanelLastActivity,
            value: AppRelativeTime.forRow(
              at,
              locale: _locale(context),
              messages: context.strings,
            ),
            icon: LucideIcons.clock,
          ),
      ],
    );
  }

  static String _stateLabel(ConversationState state, AppStrings strings) =>
      switch (state) {
        ConversationState.open => strings.conversationStateOpen,
        ConversationState.pending => strings.conversationStatePending,
        ConversationState.closed => strings.conversationStateClosed,
        ConversationState.archived => strings.conversationStateArchived,
      };
}

// -- Orders ------------------------------------------------------------------

class _OrdersTab extends ConsumerWidget {
  const _OrdersTab({required this.customerId, required this.strings});

  final String? customerId;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = customerId;

    if (id == null) {
      return _Empty(
        icon: LucideIcons.shoppingBag,
        title: strings.customerPanelNoOrders,
        description: strings.customerPanelNoCustomer,
      );
    }

    // The one tab that costs a request, so the request is made here and not
    // when the sheet opens.
    ref.watch(panelOrdersRefreshProvider(id));
    final AsyncValue<List<CustomerOrder>> orders = ref.watch(
      panelOrdersProvider(id),
    );
    final bool refreshing = ref.watch(panelOrdersRefreshProvider(id)).isLoading;

    return orders.when(
      loading: () => const AppLoadingState(),
      error: (Object error, StackTrace stack) =>
          AppErrorState(message: strings.customersUnreadable),
      data: (List<CustomerOrder> items) {
        if (items.isEmpty) {
          return refreshing
              ? const AppLoadingState()
              : _Empty(
                  icon: LucideIcons.shoppingBag,
                  title: strings.customerPanelNoOrders,
                  description: strings.customerPanelNoOrdersDescription,
                );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
          itemCount: items.length,
          separatorBuilder: (BuildContext context, int index) =>
              const AppSeparator(indent: TajeerSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final CustomerOrder order = items[index];

            return AppListItem(
              leading: const Icon(LucideIcons.receipt),
              title: Text(
                '#${order.reference}',
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.start,
              ),
              subtitle: Text(
                AppRelativeTime.forDay(
                  order.placedAt,
                  locale: _locale(context),
                  messages: context.strings,
                ),
              ),
              meta: Text(
                '${order.grandTotal} ${order.currency}',
                textDirection: TextDirection.ltr,
              ),
              trailing: AppBadge(
                label: strings.orderStateName(order.state),
                variant: _stateVariant(order.state),
                size: AppBadgeSize.small,
              ),
            );
          },
        );
      },
    );
  }

  static AppBadgeVariant _stateVariant(String state) => switch (state) {
    'delivered' || 'paid' => AppBadgeVariant.success,
    'cancelled' || 'refunded' => AppBadgeVariant.destructive,
    'shipped' || 'processing' => AppBadgeVariant.info,
    _ => AppBadgeVariant.muted,
  };
}

// -- Follow-ups --------------------------------------------------------------

class _FollowUpsTab extends ConsumerWidget {
  const _FollowUpsTab({required this.customerId, required this.strings});

  final String? customerId;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? id = customerId;

    if (id == null) {
      return _Empty(
        icon: LucideIcons.bellOff,
        title: strings.customerPanelNoFollowUps,
        description: strings.customerPanelNoCustomer,
      );
    }

    final AsyncValue<List<CustomerNote>> notes = ref.watch(
      panelNotesProvider(id),
    );

    return notes.when(
      loading: () => const AppLoadingState(),
      error: (Object error, StackTrace stack) =>
          AppErrorState(message: strings.customersUnreadable),
      data: (List<CustomerNote> items) {
        final DateTime now = DateTime.now();
        // The timeline, narrowed to what is still owed - the web's definition.
        final List<CustomerNote> due =
            items
                .where((CustomerNote note) => note.isFollowUpDue)
                .toList(growable: false)
              ..sort(
                (CustomerNote a, CustomerNote b) =>
                    a.followUpAt!.compareTo(b.followUpAt!),
              );

        if (due.isEmpty) {
          return _Empty(
            icon: LucideIcons.bellOff,
            title: strings.customerPanelNoFollowUps,
            description: strings.customerPanelNoFollowUpsDescription,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
          itemCount: due.length,
          separatorBuilder: (BuildContext context, int index) =>
              const AppSeparator(indent: TajeerSpacing.md),
          itemBuilder: (BuildContext context, int index) {
            final CustomerNote note = due[index];
            final bool overdue = note.isOverdue(now);
            final TajeerColors colors = context.colors;

            return AppListItem(
              leading: Icon(
                overdue ? LucideIcons.bellRing : LucideIcons.bell,
                color: overdue ? colors.dangerDefault : null,
              ),
              title: AppBidiText(note.body, maxLines: 3),
              subtitle: Text(
                <String>[
                  AppRelativeTime.forRow(
                    note.followUpAt!,
                    locale: _locale(context),
                    messages: context.strings,
                  ),
                  if (note.authorName case final String author) author,
                ].join(' · '),
                style: overdue ? TextStyle(color: colors.dangerDefault) : null,
              ),
              trailing: overdue
                  ? AppBadge(
                      label: strings.customerPanelOverdue,
                      variant: AppBadgeVariant.destructive,
                      size: AppBadgeSize.small,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TajeerSpacing.md),
      child: AppEmptyState(
        icon: icon,
        title: title,
        description: description,
        bordered: false,
      ),
    );
  }
}
