import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';
import '../../domain/repositories/customer_repository.dart';

part 'customer_detail_controller.g.dart';

/// One contact, from local storage.
///
/// Family-scoped by id, like the Inbox's thread, so two contacts never share a
/// subscription.
@riverpod
Stream<Customer?> customerDetail(Ref ref, String customerId) {
  return ref.watch(customerRepositoryProvider).watchCustomer(customerId);
}

/// That contact's own record, newest first, also from local storage.
@riverpod
Stream<List<CustomerNote>> customerNotes(Ref ref, String customerId) {
  return ref.watch(customerRepositoryProvider).watchNotes(customerId);
}

/// Brings one contact and its entries up to date.
///
/// Its own provider rather than a call in the screen's `initState`, for three
/// reasons it has to handle and a widget should not:
///
/// - **A contact this device has never synced.** The online search hands over
///   an id the local table does not have, and every screen past that point
///   reads locally -- so the contact is fetched before anything tries to draw
///   it, or the screen says the person was deleted.
/// - **A contact that really was deleted.** The 404 removes the local row
///   rather than leaving somebody looking at a record nothing can be done
///   with.
/// - **No connection.** It fails quietly: what is already stored stays on
///   screen, which is the whole point of reading locally.
@riverpod
Future<void> customerDetailRefresh(Ref ref, String customerId) async {
  final CustomerRepository customers = ref.watch(customerRepositoryProvider);

  try {
    if (await customers.refresh(customerId) == null) return;

    await customers.synchronizeNotes(customerId);
  } on AppFailure {
    // Offline, throttled, or a server error. The local copy stands.
  }
}
