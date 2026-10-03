import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_change_proposal.dart';
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

  group('blocking and aliases', () {
    test('reads a block, its reason and the other names', () {
      final Customer customer = CustomerDto.decode(<String, Object?>{
        'id': 'c1',
        'name': 'Sara',
        'createdAt': '2026-01-01T00:00:00Z',
        'blockedAt': '2026-02-01T10:00:00Z',
        'blockReason': 'Spam',
        'aliases': <Object?>['Sarah', ' ', null, 'S. Ahmed'],
      });

      expect(customer.isBlocked, isTrue);
      expect(customer.blockedAt, DateTime.utc(2026, 2, 1, 10));
      expect(customer.blockReason, 'Spam');
      // Blanks and nulls are not names.
      expect(customer.aliases, <String>['Sarah', 'S. Ahmed']);
    });

    test('reads a payload without them as not blocked, no other names', () {
      // What a server older than the feature sends, and what every unblocked
      // contact carries.
      final Customer customer = CustomerDto.decode(<String, Object?>{
        'id': 'c1',
        'name': 'Sara',
        'createdAt': '2026-01-01T00:00:00Z',
        'blockedAt': null,
        'blockReason': '',
        'aliases': 'not a list',
      });

      expect(customer.isBlocked, isFalse);
      expect(customer.blockReason, isNull);
      expect(customer.aliases, isEmpty);
    });
  });

  group('change proposals', () {
    Map<String, Object?> proposal({
      String? id = 'p1',
      Object? field = 'email',
      Object? currentValue = 'old@demo.test',
      Object? proposedValue = 'new@demo.test',
    }) {
      return <String, Object?>{
        'id': id,
        'field': field,
        'fieldDefinitionId': null,
        'fieldLabel': 'Email',
        'currentValue': currentValue,
        'proposedValue': proposedValue,
        'conversationId': 'v1',
        'createdAt': '2026-03-01T08:00:00Z',
      };
    }

    test('reads every field the server sends', () {
      final CustomerChangeProposal decoded = CustomerChangeProposalDto.decode(
        proposal(),
      );

      expect(decoded.id, 'p1');
      expect(decoded.field, CustomerChangeField.email);
      expect(decoded.fieldDefinitionId, isNull);
      expect(decoded.fieldLabel, 'Email');
      expect(decoded.currentValue, 'old@demo.test');
      expect(decoded.proposedValue, 'new@demo.test');
      expect(decoded.conversationId, 'v1');
      expect(decoded.createdAt, DateTime.utc(2026, 3, 1, 8));
    });

    test('maps each field the server names', () {
      CustomerChangeField fieldOf(Object? raw) =>
          CustomerChangeProposalDto.decode(proposal(field: raw)).field;

      expect(fieldOf('name'), CustomerChangeField.name);
      expect(fieldOf('email'), CustomerChangeField.email);
      expect(fieldOf('phone'), CustomerChangeField.phone);
      expect(fieldOf('customField'), CustomerChangeField.customField);
      // A kind this build has never seen is still drawn, by its label.
      expect(fieldOf('somethingNew'), CustomerChangeField.customField);
    });

    test('turns a custom field\'s value into the text a member reads', () {
      final CustomerChangeProposal decoded = CustomerChangeProposalDto.decode(
        proposal(
          field: 'customField',
          currentValue: null,
          proposedValue: <Object?>['Riyadh', null, ' ', 'Jeddah'],
        ),
      );

      expect(decoded.currentValue, isNull);
      expect(decoded.proposedValue, 'Riyadh, Jeddah');
      expect(CustomerChangeProposalDto.displayValue(42), '42');
      expect(CustomerChangeProposalDto.displayValue(true), 'true');
      expect(CustomerChangeProposalDto.displayValue(<Object?>[]), isNull);
    });

    test('reads the bare array, skipping what it cannot read', () {
      final List<CustomerChangeProposal> decoded =
          CustomerChangeProposalDto.decodeList(<Object?>[
            proposal(),
            proposal(id: null),
            'not an object',
            proposal(id: 'p2', field: 'phone'),
          ]);

      expect(decoded.map((CustomerChangeProposal p) => p.id), <String>[
        'p1',
        'p2',
      ]);
      expect(CustomerChangeProposalDto.decodeList(null), isEmpty);
    });
  });
}
