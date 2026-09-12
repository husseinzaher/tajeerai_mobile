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
import '../../domain/entities/customer_note.dart';
import '../controllers/customer_detail_controller.dart';

/// One contact: who they are, and what the team has written down.
///
/// Reads the local database, so it opens offline and on a cold start. The one
/// network call it makes is the entries refresh, which is allowed to fail
/// quietly -- what is already stored stays on screen.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final Customer? customer = ref
        .watch(customerDetailProvider(customerId))
        .value;

    // Fires once per contact and is not awaited: the screen is already
    // readable from the database, and a refresh must never gate the first
    // frame.
    ref.watch(customerDetailRefreshProvider(customerId));

    return AppScaffold(
      toolbar: AppToolbar(
        title: customer?.displayName ?? strings.customers,
        showBack: true,
      ),
      body: customer == null
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
                    for (final String tag in customer.tags)
                      AppBadge(label: tag, variant: AppBadgeVariant.muted),
                  ],
                ),
                const SizedBox(height: TajeerSpacing.lg),
                _Details(customer: customer, strings: strings),
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
