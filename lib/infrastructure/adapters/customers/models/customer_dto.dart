import '../../../../features/customers/domain/entities/customer.dart';
import '../../../../features/customers/domain/entities/customer_change_proposal.dart';
import '../../../../features/customers/domain/entities/customer_note.dart';

/// Decodes the API's customer payloads.
///
/// Forgiving by design, like the conversation decoder: an unknown `source`
/// stays a string and an unreadable timestamp becomes null, because the
/// server's vocabulary grows and a client that throws on an unrecognised value
/// fails far worse than one that shows a row without a label.
///
/// Its own time parser rather than the conversation feature's, because a
/// feature may not import another feature's internals -- and a shared one
/// would have to move to a layer neither owns for a saving of six lines.
abstract final class CustomerDto {
  static Customer decode(Map<String, Object?> json) {
    final String? id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Customer carried no id.');
    }

    final Map<String, Object?>? type = _map(json['type']);

    return Customer(
      id: id,
      name: json['name']?.toString() ?? '',
      email: _text(json['email']),
      phone: _text(json['phone']),
      locale: json['locale']?.toString() ?? 'ar',
      tags: _tags(json['tags']),
      notes: _text(json['notes']),
      typeId: _text(json['typeId']) ?? _text(type?['id']),
      typeName: _text(type?['name']),
      source: _text(json['source']),
      photoUrl: _text(json['photoUrl']),
      metadata: _map(json['metadata']) ?? const <String, Object?>{},
      createdAt: parseTime(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: parseTime(json['updatedAt']),
      blockedAt: parseTime(json['blockedAt']),
      blockReason: _text(json['blockReason']),
      // The same shape as tags: a list of strings, blanks dropped.
      aliases: _tags(json['aliases']),
    );
  }

  /// The `{data, meta}` envelope every paginated list endpoint answers with.
  static List<Customer> decodeList(Object? raw) {
    final List<Object?> items = raw is List<Object?> ? raw : const <Object?>[];

    return <Customer>[
      for (final Object? item in items)
        if (_map(item) case final Map<String, Object?> json) decode(json),
    ];
  }

  static DateTime? parseTime(Object? raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is! String || raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toUtc();
  }

  static Map<String, Object?>? _map(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map<Object?, Object?>) {
      return raw.map(
        (Object? key, Object? value) =>
            MapEntry<String, Object?>(key.toString(), value),
      );
    }

    return null;
  }

  static String? _text(Object? raw) {
    final String? value = raw?.toString().trim();

    return value == null || value.isEmpty ? null : value;
  }

  static List<String> _tags(Object? raw) {
    if (raw is! List<Object?>) return const <String>[];

    return <String>[
      for (final Object? tag in raw)
        if (tag != null && tag.toString().trim().isNotEmpty) tag.toString(),
    ];
  }
}

/// Decodes the API's `NoteEntry`.
abstract final class CustomerNoteDto {
  static CustomerNote decode(Map<String, Object?> json, {String? customerId}) {
    final String? id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Note carried no id.');
    }

    return CustomerNote(
      id: id,
      customerId: json['subjectId']?.toString() ?? customerId ?? '',
      body: json['body']?.toString() ?? '',
      authorId: CustomerDto._text(json['authorId']),
      authorName: CustomerDto._text(json['authorName']),
      followUpAt: CustomerDto.parseTime(json['followUpAt']),
      followUpDoneAt: CustomerDto.parseTime(json['followUpDoneAt']),
      createdAt:
          CustomerDto.parseTime(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  static List<CustomerNote> decodeList(Object? raw, {String? customerId}) {
    final List<Object?> items = raw is List<Object?> ? raw : const <Object?>[];

    return <CustomerNote>[
      for (final Object? item in items)
        if (CustomerDto._map(item) case final Map<String, Object?> json)
          decode(json, customerId: customerId),
    ];
  }
}

/// Decodes the API's `CustomerChangeProposalView`.
///
/// The two values are `unknown` on the server -- a custom field can hold a
/// number, a yes/no or a list -- and arrive here as whatever JSON made of
/// them. They are turned into text once, here, because text is all a member
/// is shown and all they decide on.
abstract final class CustomerChangeProposalDto {
  static CustomerChangeProposal decode(Map<String, Object?> json) {
    final String? id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Change proposal carried no id.');
    }

    return CustomerChangeProposal(
      id: id,
      field: switch (json['field']) {
        'name' => CustomerChangeField.name,
        'email' => CustomerChangeField.email,
        'phone' => CustomerChangeField.phone,
        _ => CustomerChangeField.customField,
      },
      fieldDefinitionId: CustomerDto._text(json['fieldDefinitionId']),
      fieldLabel: json['fieldLabel']?.toString() ?? '',
      currentValue: displayValue(json['currentValue']),
      proposedValue: displayValue(json['proposedValue']),
      conversationId: CustomerDto._text(json['conversationId']),
      createdAt:
          CustomerDto.parseTime(json['createdAt']) ?? DateTime.now().toUtc(),
    );
  }

  /// The endpoint answers with a bare array, which `HttpClient` hands over as
  /// `{'data': [...]}`. Malformed entries are skipped, not fatal.
  static List<CustomerChangeProposal> decodeList(Object? raw) {
    final List<Object?> items = raw is List<Object?> ? raw : const <Object?>[];
    final List<CustomerChangeProposal> decoded = <CustomerChangeProposal>[];

    for (final Object? item in items) {
      final Map<String, Object?>? json = CustomerDto._map(item);

      if (json == null) continue;

      try {
        decoded.add(decode(json));
      } on FormatException {
        // One proposal without an id is not a reason to hide the others.
      }
    }

    return decoded;
  }

  /// A value as a member reads it: a list joined, blanks as nothing.
  static String? displayValue(Object? raw) {
    if (raw == null) return null;
    if (raw is List<Object?>) {
      final String joined = raw
          .where((Object? item) => item != null)
          .map((Object? item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .join(', ');

      return joined.isEmpty ? null : joined;
    }

    return CustomerDto._text(raw);
  }
}
