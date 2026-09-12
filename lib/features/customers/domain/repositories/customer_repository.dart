import '../entities/customer.dart';
import '../entities/customer_note.dart';

/// Data access for contacts.
///
/// Reads are **local-first by contract**, as conversations are: the watch
/// methods observe the database and have no way to reach the network, so a
/// screen bound to one renders offline. Synchronisation is a separate verb,
/// called by a coordinator.
///
/// The exceptions are spelled out rather than hidden: [searchOnline],
/// [create] and [addNote] are network calls by definition, and are named so a
/// reader can see which screens stop working on a plane.
abstract interface class CustomerRepository {
  /// The contact list, from local storage, re-emitting on every change.
  ///
  /// [searchTerm] matches the name, the email and the phone's digits -- the
  /// three things somebody types when looking for a person. [tag] narrows to
  /// one label.
  Stream<List<Customer>> watchCustomers({
    String? searchTerm,
    String? tag,
    int limit = 100,
  });

  /// One contact, from local storage.
  Stream<Customer?> watchCustomer(String customerId);

  Future<Customer?> findCustomer(String customerId);

  /// Every tag in use locally, for the filter row.
  Stream<List<String>> watchTags();

  /// The contact behind a ringing number, if the workspace knows them.
  ///
  /// Matched on the digits rather than the stored spelling -- see
  /// `PhoneDigits`. Local by definition: a call arrives whether or not there
  /// is a network, and a lookup that waited for one would answer after the
  /// call had been taken.
  Future<Customer?> findByPhone(String number);

  /// Pulls one page of the server's list into local storage.
  ///
  /// Returns how far the walk got, so the coordinator can decide whether to
  /// ask for another page. Called by the sync coordinator, never by a screen.
  Future<CustomerPage> synchronizePage({required int page, int perPage});

  /// Removes local rows the server no longer lists.
  ///
  /// Takes the ids a completed full walk saw. A contact deleted on the web is
  /// absent from the walk rather than reported, so reconciliation is the only
  /// way a device learns about it.
  Future<int> reconcileDeletions({
    required Set<String> seenIds,
    required DateTime walkStartedAt,
  });

  /// Drops one contact locally, for the 404 that says it is gone.
  Future<void> forget(String customerId);

  /// Fetches one contact from the server and writes it locally.
  ///
  /// What makes a contact this device has never synced openable: an online
  /// search can hand somebody an id the local table does not have, and every
  /// screen past that point reads locally. Answers null when the server no
  /// longer has them, having removed the local row -- a deletion reaches a
  /// device either this way or through the next full walk, and waiting for the
  /// walk leaves somebody looking at a contact that is gone.
  Future<Customer?> refresh(String customerId);

  /// Asks the server for contacts matching [term].
  ///
  /// Online only, and deliberately separate from [watchCustomers]: this is the
  /// search that finds somebody this device has not synced yet.
  Future<List<Customer>> searchOnline(String term, {int limit});

  /// Creates a contact on the server, then locally. Online only.
  Future<Customer> create({
    required String name,
    String? email,
    String? phone,
    List<String> tags,
    String? notes,
    String? typeId,
  });

  /// A contact's own record, newest first, from local storage.
  Stream<List<CustomerNote>> watchNotes(String customerId);

  /// Refreshes one contact's entries from the server.
  Future<int> synchronizeNotes(String customerId);

  /// Appends an entry. Online only -- see the class comment.
  Future<CustomerNote> addNote(String customerId, String body);
}

/// One page of a walk over the server's contact list.
final class CustomerPage {
  const CustomerPage({
    required this.customers,
    required this.page,
    required this.lastPage,
  });

  final List<Customer> customers;
  final int page;

  /// How many pages the server says there are, so the walk knows when it is
  /// done rather than guessing from a short page.
  final int lastPage;

  bool get hasMore => page < lastPage;
}
