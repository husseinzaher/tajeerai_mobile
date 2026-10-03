import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/auth/application/contracts/session_capability.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/features/customers/presentation/controllers/customer_block_controller.dart';
import 'package:TajeerAi/features/customers/presentation/controllers/customer_detail_controller.dart';

import '../../../support/fixed_clock.dart';

class _Contacts implements CustomerRepository {
  _Contacts({this.failure});

  final AppFailure? failure;
  final List<String> calls = <String>[];

  /// Holds a write open until the test lets it go, to see the state between.
  Completer<void>? gate;

  @override
  Future<Customer> block(String customerId, {String? reason}) async {
    calls.add('block $customerId ${reason ?? '-'}');
    await gate?.future;
    final AppFailure? raised = failure;
    if (raised != null) throw raised;

    return Customer(
      id: customerId,
      name: 'Ada',
      createdAt: testEpoch,
      blockedAt: testEpoch,
    );
  }

  @override
  Future<Customer> unblock(String customerId) async {
    calls.add('unblock $customerId');
    final AppFailure? raised = failure;
    if (raised != null) throw raised;

    return Customer(id: customerId, name: 'Ada', createdAt: testEpoch);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Session implements SessionCapability {
  _Session(this.permissions);

  final Set<String> permissions;

  @override
  Session? get currentSession => Session(
    user: AuthenticatedUser(
      id: 'u1',
      name: 'Agent',
      email: 'agent@demo.test',
      role: 'agent',
      locale: 'en',
      permissions: permissions,
    ),
  );

  @override
  Stream<Session?> get sessionChanges => const Stream<Session?>.empty();

  @override
  String? get currentUserId => 'u1';

  @override
  String? get currentWorkspaceId => 'w1';

  @override
  Future<void> signOut() async {}
}

void main() {
  ProviderContainer containerFor(CustomerRepository contacts) {
    final ProviderContainer container = ProviderContainer(
      overrides: [customerRepositoryProvider.overrideWithValue(contacts)],
    );

    addTearDown(container.dispose);
    // Auto-disposed: a listener keeps the controller alive across the awaits.
    container.listen(customerBlockControllerProvider('c1'), (_, _) {});

    return container;
  }

  CustomerBlockController controllerIn(ProviderContainer container) =>
      container.read(customerBlockControllerProvider('c1').notifier);

  test('blocks without a reason, and says it did', () async {
    final _Contacts contacts = _Contacts();
    final ProviderContainer container = containerFor(contacts);

    await controllerIn(container).block();

    expect(contacts.calls, <String>['block c1 -']);
    expect(
      container.read(customerBlockControllerProvider('c1')),
      const CustomerBlockState(outcome: CustomerBlockOutcome.blocked),
    );
  });

  test('unblocks, and says it did', () async {
    final _Contacts contacts = _Contacts();
    final ProviderContainer container = containerFor(contacts);

    await controllerIn(container).unblock();

    expect(contacts.calls, <String>['unblock c1']);
    expect(
      container.read(customerBlockControllerProvider('c1')).outcome,
      CustomerBlockOutcome.unblocked,
    );
  });

  /*
    One write at a time: a second tap while the first is on its way would send
    the same block twice, or a block and an unblock racing each other.
  */
  test(
    'is working while the server answers, and ignores a second tap',
    () async {
      final _Contacts contacts = _Contacts()..gate = Completer<void>();
      final ProviderContainer container = containerFor(contacts);
      final CustomerBlockController controller = controllerIn(container);

      final Future<void> first = controller.block();

      expect(
        container.read(customerBlockControllerProvider('c1')).isWorking,
        isTrue,
      );

      await controller.unblock();
      contacts.gate!.complete();
      await first;

      expect(contacts.calls, <String>['block c1 -']);
      expect(
        container.read(customerBlockControllerProvider('c1')).isWorking,
        isFalse,
      );
    },
  );

  test('maps each failure to a reason the screen words', () async {
    Future<CustomerBlockOutcome?> outcomeFor(AppFailure failure) async {
      final ProviderContainer container = containerFor(
        _Contacts(failure: failure),
      );

      await controllerIn(container).block();

      return container.read(customerBlockControllerProvider('c1')).outcome;
    }

    expect(
      await outcomeFor(
        const TransportFailure(message: 'offline', isOffline: true),
      ),
      CustomerBlockOutcome.needsConnection,
    );
    expect(
      await outcomeFor(const AuthorizationFailure(message: 'no')),
      CustomerBlockOutcome.notAllowed,
    );
    expect(
      await outcomeFor(const TransportFailure(message: '500', statusCode: 500)),
      CustomerBlockOutcome.failed,
    );
  });

  test('clears the outcome once the screen has said it', () async {
    final ProviderContainer container = containerFor(_Contacts());
    final CustomerBlockController controller = controllerIn(container);

    await controller.block();
    controller.clearOutcome();

    expect(
      container.read(customerBlockControllerProvider('c1')).outcome,
      isNull,
    );

    // Clearing nothing is a no-op, not a rebuild.
    controller.clearOutcome();
    expect(
      container.read(customerBlockControllerProvider('c1')),
      const CustomerBlockState(),
    );
  });

  group('canEditCustomer', () {
    bool canEditWith(Set<String> permissions) {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sessionCapabilityProvider.overrideWithValue(_Session(permissions)),
        ],
      );
      addTearDown(container.dispose);

      return container.read(canEditCustomerProvider);
    }

    test('follows update:Customer, the permission the server checks', () {
      expect(canEditWith(<String>{'update:Customer'}), isTrue);
      expect(canEditWith(<String>{'manage:all'}), isTrue);
      expect(canEditWith(<String>{'read:Customer'}), isFalse);
    });
  });
}
