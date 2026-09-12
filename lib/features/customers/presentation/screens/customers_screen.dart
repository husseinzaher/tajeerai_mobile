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
import '../controllers/customer_list_controller.dart';
import '../widgets/customer_async_view.dart';
import '../widgets/customer_list_view.dart';

/// The workspace's contacts.
///
/// Composition, and nothing else. The rows, the chips, the four states and the
/// search field are the design system's; what they show is mapped in
/// `customer_list_view.dart`.
///
/// The list reads the local database, so "loading" is the moment before its
/// first emission, never a network wait. The one control here that needs a
/// connection -- searching the whole workspace -- says so.
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _search = TextEditingController();

  /// Whether the member asked to look beyond this device.
  ///
  /// Off until asked, and reset by every keystroke: an online search is a
  /// request somebody made about one term, not a mode the screen stays in.
  bool _online = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String term) {
    if (_online) setState(() => _online = false);

    ref.read(customerSearchProvider.notifier).update(term);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = ref.watch(appStringsProvider);
    final String term = ref.watch(customerSearchProvider);
    final String? tag = ref.watch(customerTagFilterProvider);
    final List<String> tags =
        ref.watch(customerTagsProvider).value ?? const <String>[];

    return AppScaffold(
      toolbar: AppToolbar(title: strings.customers, centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(context.push(AppRoutes.customerNewPath())),
        tooltip: strings.newCustomer,
        child: const Icon(LucideIcons.userPlus),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(TajeerSpacing.md),
            child: AppSearchField(
              controller: _search,
              hintText: strings.searchCustomers,
              onChanged: _onSearchChanged,
              onSubmitted: (_) => setState(() => _online = true),
            ),
          ),
          if (tags.isNotEmpty)
            _TagFilterRow(
              tags: tags,
              selected: tag,
              allLabel: strings.allTags,
              onSelect: (String? next) => next == null
                  ? ref.read(customerTagFilterProvider.notifier).clear()
                  : ref.read(customerTagFilterProvider.notifier).toggle(next),
            ),
          Expanded(
            child: _online && term.isNotEmpty
                ? _OnlineResults(term: term, strings: strings)
                : _LocalResults(strings: strings, term: term),
          ),
        ],
      ),
    );
  }
}

/// The contacts this device holds.
class _LocalResults extends ConsumerWidget {
  const _LocalResults({required this.strings, required this.term});

  final AppStrings strings;
  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool searching = term.isNotEmpty;

    return CustomerListView(
      state: ref
          .watch(customerListProvider)
          .toViewState(
            (List<Customer> items) => items,
            failure: strings.customersUnreadable,
            onRetry: () => ref.invalidate(customerListProvider),
          ),
      onOpen: (Customer customer) =>
          unawaited(context.push(AppRoutes.customerDetailPath(customer.id))),
      onRefresh: () => ref.read(customerListControllerProvider).refresh(),
      emptyTitle: searching ? strings.noSearchMatches : strings.noCustomers,
      emptyDescription: searching
          ? strings.searchOnlineHint
          : strings.noCustomersDescription,
      emptyIcon: searching ? LucideIcons.searchX : LucideIcons.users,
      strings: strings,
    );
  }
}

/// What the workspace knows, including contacts this device has not synced.
class _OnlineResults extends ConsumerWidget {
  const _OnlineResults({required this.term, required this.strings});

  final String term;
  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomerListView(
      state: ref
          .watch(customerOnlineSearchProvider(term))
          .toViewState(
            (List<Customer> items) => items,
            // The only failure on this screen that is genuinely about the
            // network, so it is the only one that says so.
            failure: strings.searchOnlineOffline,
            onRetry: () => ref.invalidate(customerOnlineSearchProvider(term)),
          ),
      onOpen: (Customer customer) =>
          unawaited(context.push(AppRoutes.customerDetailPath(customer.id))),
      emptyTitle: strings.noSearchMatches,
      emptyDescription: strings.noCustomersDescription,
      emptyIcon: LucideIcons.searchX,
      strings: strings,
    );
  }
}

/// The tag filter: every tag in use, and a chip that clears the filter.
class _TagFilterRow extends StatelessWidget {
  const _TagFilterRow({
    required this.tags,
    required this.selected,
    required this.allLabel,
    required this.onSelect,
  });

  final List<String> tags;
  final String? selected;
  final String allLabel;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: TajeerSpacing.md),
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: TajeerSpacing.xs),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return AppChip(
              label: allLabel,
              selected: selected == null,
              onTap: () => onSelect(null),
            );
          }

          final String tag = tags[index - 1];

          return AppChip(
            label: tag,
            selected: selected == tag,
            onTap: () => onSelect(tag),
          );
        },
      ),
    );
  }
}
