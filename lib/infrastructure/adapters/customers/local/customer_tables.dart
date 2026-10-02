import 'package:drift/drift.dart';

/// Contacts, as this device knows them.
///
/// Columns mirror the API's customer payload rather than the backend's own
/// schema, because the payload is the contract the client is given. What the
/// server keeps and this does not -- custom field values, the segment tags a
/// generator writes in bulk -- is absent because no screen here reads it, not
/// because it was forgotten.
@DataClassName('CustomerRow')
class Customers extends Table {
  /// The server's uuid.
  TextColumn get id => text()();

  TextColumn get name => text()();
  TextColumn get email => text().nullable()();

  /// The number as the server stores it: E.164 where it could be parsed, and
  /// the digits as typed where it could not.
  TextColumn get phone => text().nullable()();

  /// The same number reduced to bare digits, written on every upsert.
  ///
  /// Indexed, and the only column a phone lookup touches. Derived rather than
  /// computed at query time because a caller card has one ring to answer in,
  /// and `LIKE` over a stripped column is a full scan.
  TextColumn get phoneDigits => text().nullable()();

  /// The last nine digits -- see `PhoneDigits.significantSuffix`. Stored
  /// beside the full digits so a lookup can compare equal-to-equal rather than
  /// with a trailing wildcard, which no index can serve.
  TextColumn get phoneSuffix => text().nullable()();

  TextColumn get locale => text().withDefault(const Constant('ar'))();

  /// JSON array. Tags are read whole for a chip row and filtered one at a
  /// time; a join table would buy nothing a `LIKE` on this cannot do at this
  /// size.
  TextColumn get tags => text().withDefault(const Constant('[]'))();

  /// The standing description of the person. Not their notes timeline -- that
  /// is [CustomerNotes], and the two are different facts.
  TextColumn get notes => text().nullable()();

  TextColumn get typeId => text().nullable()();

  /// Denormalised for the list: drawing a row must not need a join.
  TextColumn get typeName => text().nullable()();

  /// The server's own `CustomerSource` string, kept as text on purpose -- the
  /// backend adds values without a schema change, and a client enum would turn
  /// each new one into a crash.
  TextColumn get source => text().nullable()();

  TextColumn get photoUrl => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  /// When this device last saw the row in a sync.
  ///
  /// The reconciliation key: a full walk stamps every row it sees, and rows
  /// still carrying an older stamp afterwards are the ones the server no
  /// longer lists. A contact deleted on the web is absent from the walk rather
  /// than reported, so there is nothing else to notice it by.
  DateTimeColumn get seenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// A contact's own record: what anyone wrote down about them, and when.
///
/// Cached locally so the detail screen reads offline like every other screen,
/// and replaced wholesale per contact on each refresh -- the server's list is
/// bounded at a hundred entries and append-only, so there is no merge to do
/// and no local edit to lose.
@DataClassName('CustomerNoteRow')
class CustomerNotes extends Table {
  /// The server's uuid. Entries are never composed offline -- writing one is
  /// an online-only act -- so there is no local id to reconcile.
  TextColumn get id => text()();

  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.cascade)();

  TextColumn get body => text()();

  /// Null for an entry the system wrote, and for one whose author has left.
  TextColumn get authorId => text().nullable()();

  /// Their name as it stood when they wrote it, snapshotted by the server --
  /// so this screen never has to resolve a member who may be gone.
  TextColumn get authorName => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
