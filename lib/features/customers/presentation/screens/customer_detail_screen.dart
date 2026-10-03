import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_change_proposal.dart';
import '../../domain/entities/customer_note.dart';
import '../controllers/customer_block_controller.dart';
import '../controllers/customer_change_proposals_controller.dart';
import '../controllers/customer_detail_controller.dart';

/// One contact: who they are, and what the team has written down.
///
/// Reads the local database, so it opens offline and on a cold start. Its
/// network calls are the refresh and the proposed changes, both allowed to
/// fail quietly -- what is already stored stays on screen -- and the two
/// online-only acts a member can take here: blocking the contact, and deciding
/// a change the AI employee proposed.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final AsyncValue<Customer?> detail = ref.watch(
      customerDetailProvider(customerId),
    );
    final Customer? customer = detail.value;

    // Fires once per contact and is not awaited: the screen is already
    // readable from the database, and a refresh must never gate the first
    // frame. It does decide what an *empty* database means, though: a
    // contact this device has never synced - one opened from the caller
    // card, or from an online search - is "loading" until the refresh has
    // had its say, and "gone" only after it. Saying gone first and then
    // drawing the person a second later read as an error.
    final AsyncValue<void> refresh = ref.watch(
      customerDetailRefreshProvider(customerId),
    );
    final bool settling =
        detail.isLoading || (customer == null && refresh.isLoading);
    final bool canEdit = ref.watch(canEditCustomerProvider);

    _listenForOutcomes(context, ref, strings);

    return AppScaffold(
      toolbar: AppToolbar(
        title: customer?.displayName ?? strings.customers,
        showBack: true,
      ),
      // Said once, under the toolbar, where it stays while the page scrolls:
      // a blocked contact is the one fact about this person that changes what
      // every other control on the page does.
      banner: customer != null && customer.isBlocked
          ? AppStatusBanner(
              message: strings.customerBlockedBanner,
              icon: LucideIcons.ban,
            )
          : null,
      body: settling
          ? const AppLoadingState()
          : customer == null
          ? AppEmptyState(
              title: strings.customerGone,
              icon: LucideIcons.userX,
              bordered: false,
            )
          : ListView(
              padding: const EdgeInsets.all(TajeerSpacing.md),
              children: <Widget>[
                AppProfileHeader(
                  name: customer.displayName,
                  subtitle: customer.typeName,
                  avatarUrl: customer.photoUrl,
                  badges: <Widget>[
                    if (customer.isBlocked)
                      AppBadge(
                        label: strings.customerBlocked,
                        variant: AppBadgeVariant.destructive,
                      ),
                    for (final String tag in customer.tags)
                      AppBadge(label: tag, variant: AppBadgeVariant.muted),
                  ],
                ),
                const SizedBox(height: TajeerSpacing.lg),
                _Details(customer: customer, strings: strings),
                _Proposals(
                  customerId: customerId,
                  strings: strings,
                  canDecide: canEdit,
                ),
                if (customer.notes case final String about
                    when about.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: TajeerSpacing.lg),
                  AppSectionHeader(title: strings.customerStandingNote),
                  const SizedBox(height: TajeerSpacing.sm),
                  AppCard(child: AppBidiText(about, alignToAmbient: true)),
                ],
                const SizedBox(height: TajeerSpacing.lg),
                AppSectionHeader(
                  title: strings.customerNotes,
                  description: strings.customerNotesDescription,
                ),
                const SizedBox(height: TajeerSpacing.sm),
                _Notes(customerId: customerId, strings: strings),
                const SizedBox(height: TajeerSpacing.md),
                AppButton(
                  label: strings.addNote,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  leading: const Icon(LucideIcons.notebookPen, size: 16),
                  onPressed: () => unawaited(
                    context.push(AppRoutes.customerNoteNewPath(customerId)),
                  ),
                ),
                if (canEdit) ...<Widget>[
                  const SizedBox(height: TajeerSpacing.xl),
                  _BlockButton(customer: customer, strings: strings),
                ],
              ],
            ),
    );
  }

  /// Says how the block action and a proposal decision came out. A toast,
  /// because both outlive the control that started them: the button changes
  /// its label on success, and a decided proposal leaves the list.
  void _listenForOutcomes(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) {
    ref.listen(customerBlockControllerProvider(customerId), (
      CustomerBlockState? previous,
      CustomerBlockState next,
    ) {
      final CustomerBlockOutcome? outcome = next.outcome;
      if (outcome == null || outcome == previous?.outcome) return;

      AppSnackbar.show(
        context,
        message: switch (outcome) {
          CustomerBlockOutcome.blocked => strings.customerBlockDone,
          CustomerBlockOutcome.unblocked => strings.customerUnblockDone,
          CustomerBlockOutcome.needsConnection =>
            strings.customerActionNeedsConnection,
          CustomerBlockOutcome.notAllowed => strings.customerActionNotAllowed,
          CustomerBlockOutcome.failed => strings.customerActionFailed,
        },
        tone: switch (outcome) {
          CustomerBlockOutcome.blocked ||
          CustomerBlockOutcome.unblocked => AppSnackbarTone.success,
          _ => AppSnackbarTone.warning,
        },
      );
      ref
          .read(customerBlockControllerProvider(customerId).notifier)
          .clearOutcome();
    });

    ref.listen(customerChangeDecisionControllerProvider(customerId), (
      ChangeDecisionState? previous,
      ChangeDecisionState next,
    ) {
      final ChangeDecisionOutcome? outcome = next.outcome;
      if (outcome == null || outcome == previous?.outcome) return;

      AppSnackbar.show(
        context,
        message: switch (outcome) {
          ChangeDecisionOutcome.approved => strings.customerProposalApproved,
          ChangeDecisionOutcome.rejected => strings.customerProposalRejected,
          ChangeDecisionOutcome.alreadyDecided =>
            strings.customerProposalAlreadyDecided,
          ChangeDecisionOutcome.needsConnection =>
            strings.customerActionNeedsConnection,
          ChangeDecisionOutcome.notAllowed => strings.customerActionNotAllowed,
          ChangeDecisionOutcome.failed => strings.customerActionFailed,
        },
        tone: switch (outcome) {
          ChangeDecisionOutcome.approved ||
          ChangeDecisionOutcome.rejected => AppSnackbarTone.success,
          _ => AppSnackbarTone.warning,
        },
      );
      ref
          .read(customerChangeDecisionControllerProvider(customerId).notifier)
          .clearOutcome();
    });
  }
}

/// Block, or unblock -- one button that names what it will do, behind a
/// confirmation that says what that means. Last on the page, apart from the
/// note button, so it is never the thing a thumb lands on by accident.
class _BlockButton extends ConsumerWidget {
  const _BlockButton({required this.customer, required this.strings});

  final Customer customer;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool blocked = customer.isBlocked;
    final bool working = ref
        .watch(customerBlockControllerProvider(customer.id))
        .isWorking;

    return AppButton(
      label: blocked ? strings.customerUnblock : strings.customerBlock,
      variant: blocked
          ? AppButtonVariant.outline
          : AppButtonVariant.destructive,
      expand: true,
      loading: working,
      leading: Icon(
        blocked ? LucideIcons.shieldCheck : LucideIcons.ban,
        size: 16,
      ),
      onPressed: working ? null : () => unawaited(_confirm(context, ref)),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final bool blocked = customer.isBlocked;
    final bool confirmed = await AppDialog.confirm(
      context: context,
      title: blocked
          ? strings.customerUnblockConfirmTitle
          : strings.customerBlockConfirmTitle,
      message: blocked
          ? strings.customerUnblockConfirmBody
          : strings.customerBlockConfirmBody,
      // The destructive direction names its act; lifting a block is a plain
      // confirmation. Both fit beside Cancel on the narrowest phone, in
      // either language.
      confirmLabel: blocked ? null : strings.customerBlockConfirm,
      destructive: !blocked,
    );

    if (!confirmed || !context.mounted) return;

    final CustomerBlockController controller = ref.read(
      customerBlockControllerProvider(customer.id).notifier,
    );

    await (blocked ? controller.unblock() : controller.block());
  }
}

/// The changes the AI employee proposed, when any are waiting.
///
/// Nothing at all when none are: an empty section headed "proposed changes"
/// is a question about the AI the member did not ask.
class _Proposals extends ConsumerWidget {
  const _Proposals({
    required this.customerId,
    required this.strings,
    required this.canDecide,
  });

  final String customerId;
  final AppStrings strings;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CustomerChangeProposal> proposals =
        ref.watch(customerChangeProposalsProvider(customerId)).value ??
        const <CustomerChangeProposal>[];

    if (proposals.isEmpty) return const SizedBox.shrink();

    final Set<String> deciding = ref
        .watch(customerChangeDecisionControllerProvider(customerId))
        .deciding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: TajeerSpacing.lg),
        AppSectionHeader(
          title: strings.customerProposals.replaceAll(
            '{count}',
            '${proposals.length}',
          ),
          description: strings.customerProposalsHint,
        ),
        const SizedBox(height: TajeerSpacing.sm),
        for (final CustomerChangeProposal proposal in proposals)
          Padding(
            padding: const EdgeInsets.only(bottom: TajeerSpacing.sm),
            child: _ProposalCard(
              proposal: proposal,
              strings: strings,
              deciding: deciding.contains(proposal.id),
              onApprove: canDecide
                  ? () => unawaited(
                      ref
                          .read(
                            customerChangeDecisionControllerProvider(customerId)
                                .notifier,
                          )
                          .approve(proposal.id),
                    )
                  : null,
              onReject: canDecide
                  ? () => unawaited(
                      ref
                          .read(
                            customerChangeDecisionControllerProvider(customerId)
                                .notifier,
                          )
                          .reject(proposal.id),
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

/// One proposed change: which field, what it says now, what it would say.
class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.strings,
    required this.deciding,
    this.onApprove,
    this.onReject,
  });

  final CustomerChangeProposal proposal;
  final AppStrings strings;
  final bool deciding;

  /// Null when the member may not decide -- the buttons are then not drawn.
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  /// The app's own word for the built-in three; the workspace's for its own
  /// fields.
  String get _label => switch (proposal.field) {
    CustomerChangeField.name => strings.customerName,
    CustomerChangeField.email => strings.email,
    CustomerChangeField.phone => strings.phone,
    CustomerChangeField.customField => proposal.fieldLabel,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_label, style: context.text.labelMedium),
          const SizedBox(height: TajeerSpacing.xs),
          // What the card says now, struck through: it is what approving
          // replaces, and it stays on the card until somebody does.
          AppBidiText(
            proposal.currentValue ?? strings.customerPanelNotSet,
            alignToAmbient: true,
            style: context.type.bodySm.copyWith(
              color: context.colors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: TajeerSpacing.xs),
          AppBidiText(
            proposal.proposedValue ?? strings.customerPanelNotSet,
            alignToAmbient: true,
          ),
          if (onApprove != null && onReject != null) ...<Widget>[
            const SizedBox(height: TajeerSpacing.sm),
            Row(
              spacing: TajeerSpacing.sm,
              children: <Widget>[
                Expanded(
                  child: AppButton(
                    label: strings.customerProposalApprove,
                    size: AppButtonSize.small,
                    expand: true,
                    loading: deciding,
                    leading: const Icon(LucideIcons.check, size: 16),
                    onPressed: deciding ? null : onApprove,
                  ),
                ),
                Expanded(
                  child: AppButton(
                    label: strings.customerProposalReject,
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.small,
                    expand: true,
                    leading: const Icon(LucideIcons.x, size: 16),
                    onPressed: deciding ? null : onReject,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.customer, required this.strings});

  final Customer customer;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (customer.phone case final String phone)
          AppDetailRow(
            label: strings.phone,
            value: phone,
            icon: LucideIcons.phone,
            // Pinned left-to-right and copyable: a number is read to be dialled
            // or pasted, and neither survives it being reordered by the page.
            identifier: true,
            copyable: true,
          ),
        if (customer.email case final String email)
          AppDetailRow(
            label: strings.email,
            value: email,
            icon: LucideIcons.mail,
            identifier: true,
            copyable: true,
          ),
        if (customer.typeName case final String type)
          AppDetailRow(
            label: strings.customerType,
            value: type,
            icon: LucideIcons.tag,
          ),
        if (customer.source case final String source)
          AppDetailRow(
            label: strings.customerSource,
            value: source,
            icon: LucideIcons.download,
          ),
        if (customer.aliases.isNotEmpty)
          AppDetailRow(
            label: strings.customerAliases,
            value: customer.aliases.join(' · '),
            icon: LucideIcons.users,
          ),
        if (customer.isBlocked)
          if (customer.blockReason case final String reason)
            AppDetailRow(
              label: strings.customerBlockReason,
              value: reason,
              icon: LucideIcons.ban,
            ),
      ],
    );
  }
}

/// The contact's entries, or the reason there are none.
class _Notes extends ConsumerWidget {
  const _Notes({required this.customerId, required this.strings});

  final String customerId;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<CustomerNote> notes =
        ref.watch(customerNotesProvider(customerId)).value ??
        const <CustomerNote>[];

    if (notes.isEmpty) {
      return AppEmptyState(
        title: strings.noNotes,
        description: strings.noNotesDescription,
        icon: LucideIcons.notebook,
      );
    }

    return Column(
      children: <Widget>[
        for (final CustomerNote note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: TajeerSpacing.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          note.authorName ?? strings.noteAuthorUnknown,
                          style: context.text.labelMedium,
                        ),
                      ),
                      Text(
                        AppRelativeTime.forRow(
                          note.createdAt,
                          locale:
                              Localizations.maybeLocaleOf(context)
                                  ?.languageCode ??
                              'en',
                          messages: context.strings,
                        ),
                        style: context.text.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: TajeerSpacing.xs),
                  // The entry is whatever somebody typed, in whichever
                  // language: its direction is its own, not the page's.
                  AppBidiText(note.body, alignToAmbient: true),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
