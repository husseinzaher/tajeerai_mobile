import '../../domain/entities/customer.dart';

/// What other features may know about the workspace's contacts.
///
/// **The only supported way another feature reaches customers.** Its first
/// caller is the caller card: a call arrives, and something has to turn a
/// ringing number into the person the workspace already knows. That feature
/// must not import `CustomerRepository`, the customer data layer or a customer
/// screen to do it -- it depends on this, which says what it needs.
///
/// Deliberately read-only and deliberately narrow. A feature that can look a
/// contact up must not thereby be able to create, edit or delete one; the
/// screens that do that live in this feature and stay there.
abstract interface class CustomerDirectoryCapability {
  /// The contact behind a number, or null when the workspace does not know
  /// them.
  ///
  /// Local and synchronous with respect to the network: a call does not wait
  /// for a request, and an answer that arrives after the phone stopped ringing
  /// is not an answer.
  Future<Customer?> findByPhone(String number);

  /// One contact by id, for a screen opened from a card.
  Future<Customer?> findById(String customerId);

  /// Whether the device has finished its first walk over the contact list.
  ///
  /// The card asks before offering "Add as customer": on a device that has not
  /// synced yet, "we do not know this number" is not something this app has
  /// earned the right to say.
  Future<bool> get isReady;
}
