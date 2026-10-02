import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_note.dart';
import 'package:TajeerAi/infrastructure/adapters/customers/models/customer_dto.dart';

/// The fields the conversation's customer panel added to the decoders.
void main() {
  test('carries the metadata a channel wrote', () {
    final Customer customer = CustomerDto.decode(<String, Object?>{
      'id': 'c1',
      'name': 'Sara',
      'createdAt': '2026-01-01T00:00:00Z',
      'metadata': <String, Object?>{'whatsappUsername': 'sara'},
    });

    expect(customer.whatsApp.handle, '@sara');
  });

  test('reads an absent metadata object as empty', () {
    final Customer customer = CustomerDto.decode(<String, Object?>{
      'id': 'c1',
      'name': 'Sara',
      'createdAt': '2026-01-01T00:00:00Z',
    });

    expect(customer.metadata, isEmpty);
    expect(customer.whatsApp.isEmpty, isTrue);
  });

  test('carries a note’s reminder and its completion', () {
    final CustomerNote note = CustomerNoteDto.decode(<String, Object?>{
      'id': 'n1',
      'subjectId': 'c1',
      'body': 'Ring back',
      'createdAt': '2026-01-01T00:00:00Z',
      'followUpAt': '2026-01-03T09:00:00Z',
      'followUpDoneAt': null,
    });

    expect(note.followUpAt, DateTime.utc(2026, 1, 3, 9));
    expect(note.followUpDoneAt, isNull);
    expect(note.isFollowUpDue, isTrue);
  });
}
