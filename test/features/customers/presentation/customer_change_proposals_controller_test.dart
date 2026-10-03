import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_change_proposal.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/features/customers/presentation/controllers/customer_change_proposals_controller.dart';

import '../../../support/fixed_clock.dart';

CustomerChangeProposal _proposal(String id) => CustomerChangeProposal(
  id: id,
  field: CustomerChangeField.email,
  fieldLabel: 'Email',
  currentValue: 'old@demo.test',
  proposedValue: 'new@demo.test',
  createdAt: testEpoch,
);

class _Contacts implements CustomerRepository {
  _Contacts({
    this.pending = const <CustomerChangeProposal>[],
    this.listFailure,
    this.decisionFailure,
    this.refreshFailure,
  });

  List<CustomerChangeProposal> pending;
  final AppFailure? listFailure;
  final AppFailure? decisionFailure;
  final AppFailure? refreshFailure;

  final List<String> calls = <String>[];
  int lists = 0;

  /// Holds a decision open until the test lets it go.
  Completer<void>? gate;

  @override
  Future<List<CustomerChangeProposal>> changeProposals(
    String customerId,
  ) async {
    lists += 1;
    final AppFailure? raised = listFailure;
    if (raised != null) throw raised;

    return pending;
  }

  @override
  Future<void> approveChange(String customerId, String proposalId) async {
    calls.add('approve $proposalId');
    await gate?.future;
    final AppFailure? raised = decisionFailure;
    if (raised != null) throw raised;
  }

  @override
  Future<void> rejectChange(String customerId, String proposalId) async {
    calls.add('reject $proposalId');
    final AppFailure? raised = decisionFailure;
    if (raised != null) throw raised;
  }

  @override
  Future<Customer?> refresh(String customerId) async {
    calls.add('refresh $customerId');
    final AppFailure? raised = refreshFailure;
    if (raised != null) throw raised;

    return Customer(id: customerId, name: 'Ada', createdAt: testEpoch);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  ProviderContainer containerFor(CustomerRepository contacts) {
    final ProviderContainer container = ProviderContainer(
      overrides: [customerRepositoryProvider.overrideWithValue(contacts)],
    );

    addTearDown(container.dispose);
    // Auto-disposed: listeners keep both alive across the awaits.
    container
      ..listen(customerChangeProposalsProvider('c1'), (_, _) {})
      ..listen(customerChangeDecisionControllerProvider('c1'), (_, _) {});

    return container;
  }

  CustomerChangeDecisionController decisionsIn(ProviderContainer container) =>
      container.read(customerChangeDecisionControllerProvider('c1').notifier);

  ChangeDecisionState stateIn(ProviderContainer container) =>
      container.read(customerChangeDecisionControllerProvider('c1'));

  group('the list', () {
    test('is what the server says is pending', () async {
      final ProviderContainer container = containerFor(
        _Contacts(pending: <CustomerChangeProposal>[_proposal('p1')]),
      );

      final List<CustomerChangeProposal> proposals = await container.read(
        customerChangeProposalsProvider('c1').future,
      );

      expect(proposals.single.id, 'p1');
    });

    /*
      Offline there is nothing this device can honestly say is pending, and the
      section is drawn only when something is.
    */
    test('is empty when the server cannot be asked', () async {
      final ProviderContainer container = containerFor(
        _Contacts(
          listFailure: const TransportFailure(
            message: 'offline',
            isOffline: true,
          ),
        ),
      );

      expect(
        await container.read(customerChangeProposalsProvider('c1').future),
        isEmpty,
      );
    });
  });

  group('approving', () {
    /*
      Approving is the server editing the contact: the card has to show the
      value it now holds, and the decided proposal has to leave the list.
    */
    test('refreshes the contact, then reads the list again', () async {
      final _Contacts contacts = _Contacts(
        pending: <CustomerChangeProposal>[_proposal('p1')],
      );
      final ProviderContainer container = containerFor(contacts);
      await container.read(customerChangeProposalsProvider('c1').future);

      contacts.pending = const <CustomerChangeProposal>[];
      await decisionsIn(container).approve('p1');

      expect(contacts.calls, <String>['approve p1', 'refresh c1']);
      expect(stateIn(container).outcome, ChangeDecisionOutcome.approved);
      expect(
        await container.read(customerChangeProposalsProvider('c1').future),
        isEmpty,
      );
      expect(contacts.lists, 2);
    });

    test('still counts as approved when the refresh after it fails', () async {
      final _Contacts contacts = _Contacts(
        refreshFailure: const TransportFailure(
          message: 'offline',
          isOffline: true,
        ),
      );
      final ProviderContainer container = containerFor(contacts);

      await decisionsIn(container).approve('p1');

      expect(stateIn(container).outcome, ChangeDecisionOutcome.approved);
    });

    test('holds the proposal\'s buttons while it is on its way', () async {
      final _Contacts contacts = _Contacts()..gate = Completer<void>();
      final ProviderContainer container = containerFor(contacts);
      final CustomerChangeDecisionController decisions = decisionsIn(container);

      final Future<void> first = decisions.approve('p1');

      expect(stateIn(container).deciding, <String>{'p1'});

      // A second tap on the same proposal is not a second request.
      await decisions.approve('p1');
      contacts.gate!.complete();
      await first;

      expect(
        contacts.calls.where((String call) => call.startsWith('approve')),
        <String>['approve p1'],
      );
      expect(stateIn(container).deciding, isEmpty);
    });
  });

  group('rejecting', () {
    test('reads the list again without touching the contact', () async {
      final _Contacts contacts = _Contacts(
        pending: <CustomerChangeProposal>[_proposal('p1')],
      );
      final ProviderContainer container = containerFor(contacts);
      await container.read(customerChangeProposalsProvider('c1').future);

      await decisionsIn(container).reject('p1');
      await container.read(customerChangeProposalsProvider('c1').future);

      expect(contacts.calls, <String>['reject p1']);
      expect(stateIn(container).outcome, ChangeDecisionOutcome.rejected);
      expect(contacts.lists, 2);
    });
  });

  group('failures', () {
    Future<(ChangeDecisionOutcome?, _Contacts)> outcomeFor(
      AppFailure failure,
    ) async {
      final _Contacts contacts = _Contacts(decisionFailure: failure);
      final ProviderContainer container = containerFor(contacts);
      await container.read(customerChangeProposalsProvider('c1').future);

      await decisionsIn(container).approve('p1');
      await container.read(customerChangeProposalsProvider('c1').future);

      return (stateIn(container).outcome, contacts);
    }

    /* Somebody decided it on the web first: it is no longer pending. */
    test('a 404 is already decided, and the list is read again', () async {
      final (ChangeDecisionOutcome? outcome, _Contacts contacts) =
          await outcomeFor(const NotFoundFailure(message: 'gone'));

      expect(outcome, ChangeDecisionOutcome.alreadyDecided);
      expect(contacts.lists, 2);
      expect(contacts.calls, isNot(contains('refresh c1')));
    });

    test('a 403 is not allowed, and the proposal stays', () async {
      final (ChangeDecisionOutcome? outcome, _Contacts contacts) =
          await outcomeFor(const AuthorizationFailure(message: 'no'));

      expect(outcome, ChangeDecisionOutcome.notAllowed);
      expect(contacts.lists, 1);
    });

    test('offline needs a connection', () async {
      final (ChangeDecisionOutcome? outcome, _) = await outcomeFor(
        const TransportFailure(message: 'offline', isOffline: true),
      );

      expect(outcome, ChangeDecisionOutcome.needsConnection);
    });

    test('anything else failed', () async {
      final (ChangeDecisionOutcome? outcome, _) = await outcomeFor(
        const TransportFailure(message: '500', statusCode: 500),
      );

      expect(outcome, ChangeDecisionOutcome.failed);
    });
  });

  test('clears the outcome once the screen has said it', () async {
    final ProviderContainer container = containerFor(_Contacts());
    final CustomerChangeDecisionController decisions = decisionsIn(container);

    await decisions.reject('p1');
    decisions.clearOutcome();

    expect(stateIn(container).outcome, isNull);

    decisions.clearOutcome();
    expect(stateIn(container).outcome, isNull);
  });
}
