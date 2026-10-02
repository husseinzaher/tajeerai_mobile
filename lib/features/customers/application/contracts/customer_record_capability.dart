import '../../domain/entities/customer.dart';
import '../../domain/entities/customer_note.dart';

// The types this door hands out, re-exported so a consumer names them through
// the door rather than by reaching into this feature's domain.
export '../../domain/entities/customer.dart' show Customer;
export '../../domain/entities/customer_note.dart' show CustomerNote;
export '../../domain/value_objects/whatsapp_contact.dart' show WhatsAppContact;

/// A contact's record, as another feature may read it.
///
/// What the conversation screen's customer panel needs and nothing more: the
/// contact as the device holds them, their entries, and a way to bring both
/// up to date. Read-only, like [CustomerDirectoryCapability]: a feature that
/// can show a contact must not thereby be able to edit one - that is the
/// customers feature's own screens, reached by route.
///
/// Both streams read the local database and re-emit when a sync writes a row,
/// so the panel is readable offline and never waits on the network to draw.
abstract interface class CustomerRecordCapability {
  Stream<Customer?> watchCustomer(String customerId);

  /// Newest first.
  Stream<List<CustomerNote>> watchNotes(String customerId);

  /// Fetches the contact and their entries from the server and writes both
  /// locally. Fails quietly offline - what is stored stays on screen - and
  /// removes a contact the server says no longer exists.
  Future<void> refresh(String customerId);
}
