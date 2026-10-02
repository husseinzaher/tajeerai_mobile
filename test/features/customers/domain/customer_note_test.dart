import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_note.dart';

/// What "still owed" means for a follow-up - the web's definition, kept here.
void main() {
  final DateTime now = DateTime.utc(2026, 10, 2, 12);

  CustomerNote note({DateTime? followUpAt, DateTime? doneAt}) => CustomerNote(
    id: 'n1',
    customerId: 'c1',
    body: 'Ring back',
    createdAt: now,
    followUpAt: followUpAt,
    followUpDoneAt: doneAt,
  );

  test('an entry without a reminder is not a follow-up', () {
    expect(note().isFollowUpDue, isFalse);
    expect(note().isOverdue(now), isFalse);
  });

  test('a reminder nobody has closed is due', () {
    final CustomerNote open = note(
      followUpAt: now.add(const Duration(days: 1)),
    );

    expect(open.isFollowUpDue, isTrue);
    expect(open.isOverdue(now), isFalse);
  });

  test('a reminder past its time is overdue', () {
    final CustomerNote late = note(
      followUpAt: now.subtract(const Duration(hours: 1)),
    );

    expect(late.isOverdue(now), isTrue);
  });

  test('a completed reminder is neither due nor overdue', () {
    final CustomerNote done = note(
      followUpAt: now.subtract(const Duration(days: 2)),
      doneAt: now.subtract(const Duration(days: 1)),
    );

    expect(done.isFollowUpDue, isFalse);
    expect(done.isOverdue(now), isFalse);
  });
}
