/// Which part of a contact a proposal would change.
///
/// The server's closed set. A value this build has never seen decodes as
/// [customField], whose label the server always sends -- a proposal is still
/// drawn and still decided, rather than dropped.
enum CustomerChangeField { name, email, phone, customField }

/// A change to a contact the AI employee read in a conversation, waiting for
/// a member to approve or reject it.
///
/// It replaces nothing until a member approves it: the contact card keeps its
/// current value, and the server applies the proposed one only on approval.
/// Never stored on the device -- a pending decision read from a cache is one
/// somebody may already have made on the web.
final class CustomerChangeProposal {
  const CustomerChangeProposal({
    required this.id,
    required this.field,
    required this.fieldLabel,
    required this.createdAt,
    this.fieldDefinitionId,
    this.currentValue,
    this.proposedValue,
    this.conversationId,
  });

  final String id;
  final CustomerChangeField field;

  /// The custom field's definition, for [CustomerChangeField.customField].
  final String? fieldDefinitionId;

  /// The server's name for the field, in the workspace's own words. What a
  /// custom field is called; the app uses its own copy for the built-in three.
  final String fieldLabel;

  /// What the card says now, as text. Null when it says nothing.
  final String? currentValue;

  /// What the conversation said instead, as text.
  final String? proposedValue;

  /// The conversation it was read in, when that is still known.
  final String? conversationId;
  final DateTime createdAt;
}
