import 'package:tajeerai_mobile/infrastructure/database/app_database.dart';

/// Opens a fresh in-memory database for one test.
///
/// A real SQLite engine, not a mock: the behaviour these tests assert on --
/// reactive re-emission, upsert-on-conflict, ordering by index -- belongs to
/// the engine, and testing it against a fake would only prove the fake works.
AppDatabase openTestDatabase() => AppDatabase.memory();
