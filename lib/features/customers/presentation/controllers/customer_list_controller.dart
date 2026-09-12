import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../domain/entities/customer.dart';

part 'customer_list_controller.g.dart';

/// What the contact search box holds.
///
/// Its own provider so typing re-runs the local query without rebuilding
/// anything else, and without touching the network: search here filters what
/// is already on the device. Reaching the workspace is a separate, deliberate
/// act -- see [CustomerListController.searchOnline].
final NotifierProvider<CustomerSearchController, String>
customerSearchProvider = NotifierProvider<CustomerSearchController, String>(
  CustomerSearchController.new,
);

class CustomerSearchController extends Notifier<String> {
  @override
  String build() => '';

  void update(String term) => state = term;

  void clear() => state = '';
}

/// The selected tag, or null for all of them.
final NotifierProvider<CustomerTagFilterController, String?>
customerTagFilterProvider =
    NotifierProvider<CustomerTagFilterController, String?>(
      CustomerTagFilterController.new,
    );

class CustomerTagFilterController extends Notifier<String?> {
  @override
  String? build() => null;

  /// Selecting the tag already selected clears it, so the chip row needs no
  /// separate "All" behaviour beyond its own chip.
  void toggle(String tag) => state = state == tag ? null : tag;

  void clear() => state = null;
}

/// The contact list.
///
/// **Reads the local database, never the network.** It emits offline, and
/// re-emits when a sync writes a row. Whether the data arrived a second ago or
/// last week is the sync state's business, not this screen's.
final StreamProvider<List<Customer>> customerListProvider =
    StreamProvider<List<Customer>>((Ref ref) {
      final String search = ref.watch(customerSearchProvider);
      final String? tag = ref.watch(customerTagFilterProvider);

      return ref
          .watch(customerRepositoryProvider)
          .watchCustomers(searchTerm: search.isEmpty ? null : search, tag: tag);
    });

/// Every tag in use locally, for the filter row.
final StreamProvider<List<String>> customerTagsProvider =
    StreamProvider<List<String>>(
      (Ref ref) => ref.watch(customerRepositoryProvider).watchTags(),
    );

/// Contacts the server knows and this device has not synced.
///
/// A separate provider from [customerListProvider] on purpose: it is the one
/// thing on this screen that needs a connection, and keeping it separate is
/// what lets the screen say so instead of showing an empty list.
@riverpod
Future<List<Customer>> customerOnlineSearch(Ref ref, String term) {
  return ref.watch(customerRepositoryProvider).searchOnline(term);
}

/// Actions the contact list offers.
final Provider<CustomerListController> customerListControllerProvider =
    Provider<CustomerListController>(CustomerListController.new);

class CustomerListController {
  const CustomerListController(this._ref);

  final Ref _ref;

  /// Pull-to-refresh: the only place the list causes a network call, and it
  /// still writes through the database rather than into the widget.
  Future<void> refresh() => _ref.read(customerSyncProvider).synchronize();
}
