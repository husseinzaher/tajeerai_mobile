import '../../domain/entities/conversation.dart';

/// Decodes the backend's conversation payload.
///
/// Built against `ConversationSocketEvent.conversation` -- the *public wire
/// shape* the backend documents as being derived from domain-event snapshots
/// rather than from entities, precisely so a new database column is not
/// silently a change to what clients receive.
///
/// Forgiving by design. An unknown `state` becomes [ConversationState.open]
/// rather than throwing: the server's vocabulary can grow, and a client that
/// crashes on an unrecognised value fails much worse than one that shows the
/// thread as open.
abstract final class ConversationDto {
  static Conversation decode(Map<String, Object?> json) {
    final id = json['id']?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('Conversation carried no id.');
    }

    return Conversation(
      id: id,
      state: decodeState(json['state']),
      channelId: json['channelId']?.toString(),
      customerId: json['customerId']?.toString(),
      customerName: _customerName(json),
      customerAvatarUrl: _customerAvatar(json),
      assigneeId: json['assigneeId']?.toString(),
      subject: json['subject']?.toString(),
      unreadCount: _int(json['unreadCount']) ?? 0,
      tags: _tags(json['tags']),
      lastMessagePreview: _preview(json),
      lastMessageAt: parseTime(json['lastMessageAt']),
      lastInboundMessageAt: parseTime(json['lastInboundMessageAt']),
      // The rail sends timestamps, not booleans: `pinnedAt` and `archivedAt`
      // are null when unset. `muted` is already resolved server-side, because
      // "muted until a time that has passed" is not muted and the backend
      // declines to make every client re-implement that comparison.
      isPinned: _isSet(json['pinnedAt']) || json['isPinned'] == true,
      isArchived: _isSet(json['archivedAt']) || json['isArchived'] == true,
      isMuted: json['muted'] == true || json['isMuted'] == true,
      isBotEnabled: json['isBotEnabled'] == true,
      createdAt: parseTime(json['createdAt']) ?? DateTime.now().toUtc(),
      updatedAt: parseTime(json['updatedAt']),
    );
  }

  /// Unwraps the `{eventId, occurredAt, conversation: {...}}` envelope.
  static Conversation decodeEvent(Map<String, Object?> json) {
    final conversation = json['conversation'];

    if (conversation is! Map) {
      throw const FormatException('Event carried no conversation.');
    }

    return decode(Map<String, Object?>.from(conversation));
  }

  static ConversationState decodeState(Object? raw) {
    return switch (raw?.toString().toLowerCase()) {
      'open' => ConversationState.open,
      'pending' => ConversationState.pending,
      'closed' => ConversationState.closed,
      'archived' => ConversationState.archived,
      // An unrecognised state is shown as open rather than crashing the list.
      _ => ConversationState.open,
    };
  }

  /// The rail's one-line preview.
  ///
  /// The backend attaches the newest message as a one-element `messages`
  /// array rather than a preview string -- it hydrates the real row so the
  /// client can show media and template messages properly. There is no
  /// `lastMessagePreview` field; reading one produced an Inbox where every
  /// row said "No messages yet".
  static String? _preview(Map<String, Object?> json) {
    final direct = json['lastMessagePreview']?.toString();

    if (direct != null && direct.isNotEmpty) return direct;

    final messages = json['messages'];

    if (messages is! List || messages.isEmpty) return null;

    final latest = messages.first;

    if (latest is! Map) return null;

    final body = latest['body']?.toString();

    if (body != null && body.trim().isNotEmpty) {
      return body.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    // A media message has no body. Naming the kind beats an empty row.
    return latest['mediaUrl'] == null ? null : 'Attachment';
  }

  /// A nullable timestamp used as a flag.
  static bool _isSet(Object? raw) => raw != null && raw.toString().isNotEmpty;

  /// The customer's name, wherever the payload happens to carry it.
  ///
  /// The rail payload nests a `customer` object; some events carry only a flat
  /// `customerName`. Both are read so one shape does not blank the rail.
  static String? _customerName(Map<String, Object?> json) {
    final flat = json['customerName']?.toString();

    if (flat != null && flat.isNotEmpty) return flat;

    final customer = json['customer'];

    if (customer is! Map) return null;

    // `name` is what the rail's customer object carries; `displayName` is the
    // discovery payload's spelling.
    final name = customer['name'] ?? customer['displayName'];
    final text = name?.toString();

    return text == null || text.isEmpty ? null : text;
  }

  static String? _customerAvatar(Map<String, Object?> json) {
    final customer = json['customer'];

    if (customer is Map) {
      // The rail resolves the photo server-side into `photoUrl`.
      final photo = customer['photoUrl']?.toString();

      if (photo != null && photo.isNotEmpty) return photo;

      final avatar = customer['avatar'];

      if (avatar is Map) return avatar['url']?.toString();
      if (avatar is String) return avatar;
    }

    return json['customerAvatarUrl']?.toString();
  }

  static List<String> _tags(Object? raw) {
    if (raw is! List) return const <String>[];

    return raw
        .map((entry) {
          if (entry is Map) return entry['name']?.toString() ?? '';

          return entry.toString();
        })
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  static int? _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();

    return int.tryParse(raw?.toString() ?? '');
  }

  /// Parses an ISO timestamp into UTC.
  ///
  /// Always UTC: the app compares timestamps from the server against ones it
  /// wrote locally, and mixing zones makes ordering wrong by hours.
  static DateTime? parseTime(Object? raw) {
    if (raw is DateTime) return raw.toUtc();
    if (raw is! String || raw.isEmpty) return null;

    return DateTime.tryParse(raw)?.toUtc();
  }
}
