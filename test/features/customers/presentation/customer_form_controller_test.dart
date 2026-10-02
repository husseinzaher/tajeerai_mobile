import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_note.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/features/customers/presentation/controllers/customer_form_controller.dart';
import 'package:TajeerAi/features/customers/presentation/controllers/customer_note_form_controller.dart';

import '../../../support/fixed_clock.dart';

class _Contacts implements CustomerRepository {
  _Contacts({this.existing, this.failure});

  final Customer? existing;
  final AppFailure? failure;

  final List<String?> phonesCreated = <String?>[];
  final List<String?> emailsCreated = <String?>[];
  final List<String> lookedUp = <String>[];
  final List<String> notesWritten = <String>[];

  @override
  Future<Customer?> findByPhone(String number) async {
    lookedUp.add(number);

    return existing;
  }

  @override
  Future<Customer> create({
    required String name,
    String? email,
    String? phone,
    List<String> tags = const <String>[],
    String? notes,
    String? typeId,
  }) async {
    final AppFailure? raised = failure;

    if (raised != null) throw raised;

    phonesCreated.add(phone);
    emailsCreated.add(email);

    return Customer(id: 'c9', name: name, createdAt: testEpoch);
  }

  @override
  Future<CustomerNote> addNote(String customerId, String body) async {
    final AppFailure? raised = failure;

    if (raised != null) throw raised;

    notesWritten.add(body);

    return CustomerNote(
      id: 'n1',
      customerId: customerId,
      body: body,
      createdAt: testEpoch,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The save sequence on its own: validate, look up, create. The screen tests
/// drive the same code through the widgets; this is where the branches a
/// screen test has no reason to reach are pinned.
void main() {
  late ProviderContainer container;

  ProviderContainer containerFor(CustomerRepository contacts) {
    final ProviderContainer built = ProviderContainer(
      overrides: [customerRepositoryProvider.overrideWithValue(contacts)],
    );

    addTearDown(built.dispose);
    // Auto-disposed: a listener keeps the controller alive across the awaits.
    built.listen(customerFormControllerProvider, (_, _) {});
    built.listen(customerNoteFormControllerProvider, (_, _) {});

    return built;
  }

  CustomerFormController form() =>
      container.read(customerFormControllerProvider.notifier);

  CustomerFormState formState() =>
      container.read(customerFormControllerProvider);

  group('the contact form', () {
    test('does nothing for a blank name', () async {
      final _Contacts contacts = _Contacts();
      container = containerFor(contacts);

      expect(await form().save(name: '  ', phone: '', email: ''), isNull);
      expect(contacts.phonesCreated, isEmpty);
    });

    test('refuses a number without a country code before looking up', () async {
      final _Contacts contacts = _Contacts();
      container = containerFor(contacts);

      final CustomerFormOutcome? outcome = await form().save(
        name: 'Ada',
        phone: '0501234567',
        email: '',
      );

      expect(outcome, isA<CustomerSaveRefused>());
      expect(formState().error, CustomerFormError.phoneNeedsCountryCode);
      expect(formState().isSaving, isFalse);
      expect(contacts.lookedUp, isEmpty);
      expect(contacts.phonesCreated, isEmpty);
    });

    test('the bare calling code is nobody\'s number', () async {
      final _Contacts contacts = _Contacts();
      container = containerFor(contacts);

      final CustomerFormOutcome? outcome = await form().save(
        name: ' Ada ',
        phone: CustomerFormController.defaultCallingCode,
        email: ' ada@example.com ',
      );

      expect(outcome, isA<CustomerSaved>());
      expect((outcome! as CustomerSaved).customerId, 'c9');
      // Neither looked up nor sent: there was no number.
      expect(contacts.lookedUp, isEmpty);
      expect(contacts.phonesCreated, <String?>[null]);
      expect(contacts.emailsCreated, <String?>['ada@example.com']);
    });

    test('opens the contact a number already belongs to', () async {
      final _Contacts contacts = _Contacts(
        existing: Customer(id: 'c1', name: 'Ada', createdAt: testEpoch),
      );
      container = containerFor(contacts);

      final CustomerFormOutcome? outcome = await form().save(
        name: 'Ada Lovelace',
        phone: '+966501234567',
        email: '',
      );

      expect(outcome, isA<CustomerAlreadyExisted>());
      expect((outcome! as CustomerAlreadyExisted).customerId, 'c1');
      expect(contacts.phonesCreated, isEmpty);
      expect(formState().error, isNull);
    });

    test(
      'a refused write is reported by reason, and the form is free again',
      () async {
        container = containerFor(
          _Contacts(failure: const ConflictFailure(message: 'exists')),
        );

        final CustomerFormOutcome? outcome = await form().save(
          name: 'Ada',
          phone: '+966501234567',
          email: '',
        );

        expect(outcome, isA<CustomerSaveRefused>());
        expect(formState().error, CustomerFormError.alreadyExists);
        expect(formState().isSaving, isFalse);
      },
    );

    test('anything else is a plain failure to save', () async {
      container = containerFor(_Contacts(failure: const UnknownFailure()));

      await form().save(name: 'Ada', phone: '', email: '');

      expect(formState().error, CustomerFormError.saveFailed);
    });

    test('being offline is its own reason', () async {
      container = containerFor(
        _Contacts(
          failure: const TransportFailure(message: 'offline', isOffline: true),
        ),
      );

      await form().save(name: 'Ada', phone: '', email: '');

      expect(formState().error, CustomerFormError.needsConnection);
    });

    test('clearing the error leaves a clean form', () async {
      container = containerFor(_Contacts(failure: const UnknownFailure()));

      await form().save(name: 'Ada', phone: '', email: '');
      form().clearError();

      expect(formState(), const CustomerFormState());

      // Idempotent: clearing nothing changes nothing.
      form().clearError();

      expect(formState(), const CustomerFormState());
    });
  });

  group('the note form', () {
    CustomerNoteFormController notes() =>
        container.read(customerNoteFormControllerProvider.notifier);

    CustomerNoteFormState noteState() =>
        container.read(customerNoteFormControllerProvider);

    test('writes the entry, trimmed, and says so', () async {
      final _Contacts contacts = _Contacts();
      container = containerFor(contacts);

      expect(
        await notes().save(customerId: 'c1', body: '  Called back  '),
        isTrue,
      );
      expect(contacts.notesWritten, <String>['Called back']);
      expect(noteState().isSaving, isFalse);
    });

    test('sends nothing for an empty entry', () async {
      final _Contacts contacts = _Contacts();
      container = containerFor(contacts);

      expect(await notes().save(customerId: 'c1', body: '   '), isFalse);
      expect(contacts.notesWritten, isEmpty);
    });

    test('keeps the reason when there is no connection', () async {
      container = containerFor(
        _Contacts(
          failure: const TransportFailure(message: 'offline', isOffline: true),
        ),
      );

      expect(await notes().save(customerId: 'c1', body: 'x'), isFalse);
      expect(noteState().error, CustomerNoteFormError.needsConnection);
    });

    test('anything else is a plain failure to save, cleared on edit', () async {
      container = containerFor(_Contacts(failure: const UnknownFailure()));

      await notes().save(customerId: 'c1', body: 'x');

      expect(noteState().error, CustomerNoteFormError.saveFailed);

      notes().clearError();

      expect(noteState(), const CustomerNoteFormState());
    });
  });
}
