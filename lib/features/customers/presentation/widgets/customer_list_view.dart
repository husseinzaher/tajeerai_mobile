import 'package:flutter/material.dart';

import '../../../../app/localization/translations/app_strings.dart';
import '../../../../app/theme/theme.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/customer.dart';

/// A list of contacts in its four states.
///
/// Here rather than in the design system because it knows what a `Customer`
/// is, and a shared component that knows that can no longer be shared
/// (RULE 31's reasoning). What it draws is entirely the design system's:
/// `AppListItem` rows, `AppEmptyState`, `AppErrorState`, `AppSkeleton`.
class CustomerListView extends StatelessWidget {
  const CustomerListView({
    required this.state,
    required this.onOpen,
    required this.emptyTitle,
    required this.emptyDescription,
    required this.emptyIcon,
    required this.strings,
    this.onRefresh,
    super.key,
  });

  final AppViewState<List<Customer>> state;
  final ValueChanged<Customer> onOpen;
  final String emptyTitle;
  final String emptyDescription;
  final IconData emptyIcon;
  final AppStrings strings;

  /// Pull-to-refresh, where the list is one that syncs. The online search
  /// results have nothing to pull against, so they pass null.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AppViewLoading<List<Customer>>() => const _LoadingRows(),
      AppViewFailed<List<Customer>>(
        :final String message,
        :final VoidCallback? onRetry,
      ) =>
        AppErrorState(message: message, onRetry: onRetry, bordered: false),
      AppViewLoaded<List<Customer>>(:final List<Customer> value) =>
        value.isEmpty
            ? AppEmptyState(
                title: emptyTitle,
                description: emptyDescription,
                icon: emptyIcon,
                bordered: false,
              )
            : _Rows(
                customers: value,
                onOpen: onOpen,
                onRefresh: onRefresh,
                strings: strings,
              ),
    };
  }
}

class _Rows extends StatelessWidget {
  const _Rows({
    required this.customers,
    required this.onOpen,
    required this.onRefresh,
    required this.strings,
  });

  final List<Customer> customers;
  final ValueChanged<Customer> onOpen;
  final Future<void> Function()? onRefresh;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView.builder(
      itemCount: customers.length,
      itemBuilder: (BuildContext context, int index) {
        final Customer customer = customers[index];

        final String? subtitle = customer.phone ?? customer.email;

        return AppListItem(
          title: Text(customer.displayName),
          // The number reads left-to-right whatever the page does, which
          // `AppBidiText` is for -- an Arabic screen otherwise moves the `+`
          // to the wrong end.
          subtitle: subtitle == null
              ? null
              : AppBidiText(subtitle, alignToAmbient: true, maxLines: 1),
          leading: AppAvatar(
            name: customer.displayName,
            imageUrl: customer.photoUrl,
          ),
          trailing: customer.typeName == null
              ? null
              : AppBadge(label: customer.typeName!),
          onTap: () => onOpen(customer),
        );
      },
    );

    final Future<void> Function()? refresh = onRefresh;

    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// What the list looks like before its first emission -- which on this screen
/// is a database read, so it is a blink rather than a wait.
class _LoadingRows extends StatelessWidget {
  const _LoadingRows();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: TajeerSpacing.md),
      itemCount: 6,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: TajeerSpacing.sm),
        child: AppSkeleton(height: 56),
      ),
    );
  }
}
