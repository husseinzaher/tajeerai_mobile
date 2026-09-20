import 'package:drift/drift.dart';

/// Where a conversation sits in its lifecycle. Mirrors the backend's
/// `ConversationState`.
enum ConversationStateRow { open, pending, closed, archived }

/// Which way a message travelled.
enum MessageDirectionRow { inbound, outbound }

/// A message's delivery state.
///
/// The first three are local-only and have no server equivalent: a message
/// exists on this device before the server has heard of it, and the UI has to
/// distinguish "queued on your phone" from "the provider has it".
enum MessageStateRow {
  /// Written locally, waiting for the outbox.
  pending,

  /// The send command is in flight.
  sending,

  /// The send failed and can be retried.
  failed,

  /// Accepted by the server.
  sent,

  delivered,
  read,

  /// The server never accepted it, or it was revoked.
  discarded,
}

/// Conversations, as this device knows them.
///
/// The primary read source for the rail. Columns mirror the backend's
/// `ConversationSocketEvent.conversation` payload rather than its database
/// schema, because the payload is the contract the client is actually given.
@DataClassName('ConversationRow')
class Conversations extends Table {
  /// The server's uuid.
  TextColumn get id => text()();

  TextColumn get state => textEnum<ConversationStateRow>()();

  TextColumn get channelId => text().nullable()();
  TextColumn get customerId => text().nullable()();
  TextColumn get assigneeId => text().nullable()();

  /// Denormalised for the rail: rendering a list must not need a join per row.
  TextColumn get customerName => text().nullable()();
  TextColumn get customerAvatarUrl => text().nullable()();

  TextColumn get subject => text().nullable()();

  IntColumn get unreadCount => integer().withDefault(const Constant(0))();

  BoolColumn get isBotEnabled => boolean().withDefault(const Constant(false))();

  /// JSON array. Tags are a display concern here and are never queried by
  /// element, so a join table would buy nothing.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// How many of this thread's messages the server has in `failed`.
  ///
  /// Denormalised on the server for the rail's sake and carried through
  /// verbatim, like [unreadCount]: the count is the server's answer, never
  /// this device's. A phone that counted its own would report the outbox
  /// rows it has not managed to send yet, which is a different thing.
  IntColumn get failedMessageCount =>
      integer().withDefault(const Constant(0))();

  /// A preview of the newest message, so the rail needs no message lookup.
  TextColumn get lastMessagePreview => text().nullable()();

  /// The rail's sort key.
  DateTimeColumn get lastMessageAt => dateTime().nullable()();

  DateTimeColumn get lastInboundMessageAt => dateTime().nullable()();

  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// `occurredAt` of the newest event applied to this row.
  ///
  /// The ordering guard: an event older than this is a late broadcast and is
  /// discarded rather than allowed to overwrite newer state. The backend puts
  /// `occurredAt` on every event for exactly this.
  DateTimeColumn get lastEventAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Messages, as this device knows them.
///
/// Holds both server messages and ones composed offline that the server has
/// never seen -- which is why [id] is not always a server uuid and why
/// [clientMessageId] exists.
@DataClassName('MessageRow')
class Messages extends Table {
  /// The server's uuid once known; until then, the locally generated
  /// [clientMessageId], so an optimistic row has a stable identity from the
  /// moment it is drawn.
  TextColumn get id => text()();

  TextColumn get conversationId => text()();

  /// The idempotency key from `messageSendCommandSchema.clientMessageId`.
  ///
  /// Generated before the first attempt and reused on every retry, so a resend
  /// after a lost acknowledgement returns the original message instead of
  /// creating a second one. Null on inbound messages.
  TextColumn get clientMessageId => text().nullable()();

  TextColumn get direction => textEnum<MessageDirectionRow>()();

  TextColumn get state => textEnum<MessageStateRow>()();

  /// Message kind (`text`, `image`, …). Free text: the provider set grows
  /// server-side, and an unknown value must render as "unsupported", never
  /// crash a decode.
  TextColumn get type => text().withDefault(const Constant('text'))();

  TextColumn get body => text().nullable()();
  TextColumn get mediaUrl => text().nullable()();

  /// Local path once downloaded. Lets an attachment open offline.
  TextColumn get localMediaPath => text().nullable()();

  TextColumn get authorName => text().nullable()();
  TextColumn get authorId => text().nullable()();

  BoolColumn get isFromBot => boolean().withDefault(const Constant(false))();

  /// Why a send failed, for the retry affordance.
  TextColumn get failureReason => text().nullable()();

  /// The provider's id, which exists only once the send was acknowledged.
  TextColumn get externalId => text().nullable()();

  /// The thread's sort key. For a pending message this is the local compose
  /// time, so it appears immediately and in the right place.
  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime().nullable()();
  DateTimeColumn get deliveredAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get queuedAt => dateTime().nullable()();

  /// Ordering guard, as on conversations.
  DateTimeColumn get lastEventAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
