import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/auth/application/contracts/session_capability.dart';
import 'package:TajeerAi/features/auth/domain/entities/user.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_change_proposal.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_note.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/features/customers/presentation/screens/customer_detail_screen.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/widget_harness.dart';

class _ScriptedCustomers implements CustomerRepository {
  _ScriptedCustomers({
    this.customer,
    this.notes = const <CustomerNote>[],
    this.refreshed,
    this.proposals = const <CustomerChangeProposal>[],
    this.writeFailure,
  });

  /// What every write throws, when set.
  final AppFailure? writeFailure;

  final Customer? customer;
  final List<CustomerNote> notes;

  /// What a refresh answers. Null means the server no longer has them.
  final Customer? refreshed;

  /// What the server says is pending.
  List<CustomerChangeProposal> proposals;

  int refreshes = 0;
  int noteSyncs = 0;
  final List<String> writes = <String>[];

  @override
  Future<List<CustomerChangeProposal>> changeProposals(
    String customerId,
  ) async => proposals;

  @override
  Future<void> approveChange(String customerId, String proposalId) async {
    writes.add('approve $proposalId');
    if (writeFailure case final AppFailure failure) throw failure;
    proposals = const <CustomerChangeProposal>[];
  }

  @override
  Future<void> rejectChange(String customerId, String proposalId) async {
    writes.add('reject $proposalId');
    if (writeFailure case final AppFailure failure) throw failure;
    proposals = const <CustomerChangeProposal>[];
  }

  @override
  Future<Customer> block(String customerId, {String? reason}) async {
    writes.add('block');
    if (writeFailure case final AppFailure failure) throw failure;

    return customer!;
  }

  @override
  Future<Customer> unblock(String customerId) async {
    writes.add('unblock');
    if (writeFailure case final AppFailure failure) throw failure;

    return customer!;
  }

  @override
  Stream<Customer?> watchCustomer(String customerId) =>
      Stream<Customer?>.value(customer);

  @override
  Stream<List<CustomerNote>> watchNotes(String customerId) =>
      Stream<List<CustomerNote>>.value(notes);

  @override
  Future<Customer?> refresh(String customerId) async {
    refreshes += 1;

    return refreshed;
  }

  @override
  Future<int> synchronizeNotes(String customerId) async {
    noteSyncs += 1;

    return notes.length;
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

Widget _screen(
  CustomerRepository customers, {
  Locale locale = const Locale('en'),
  Set<String> permissions = const <String>{'read:Customer', 'update:Customer'},
}) {
  return ProviderScope(
    // Untyped: Riverpod 3 does not export `Override`.
    overrides: [
      customerRepositoryProvider.overrideWithValue(customers),
      sessionCapabilityProvider.overrideWithValue(_Session(permissions)),
      appStringsProvider.overrideWithValue(
        AppStrings(
          locale.languageCode == 'ar' ? AppLocale.arabic : AppLocale.english,
        ),
      ),
    ],
    child: wrapWidget(
      const CustomerDetailScreen(customerId: 'c1'),
      locale: locale,
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
    ),
  );
}

final Customer _ada = Customer(
  id: 'c1',
  name: 'Ada Lovelace',
  phone: '+966501234567',
  email: 'ada@demo.test',
  notes: 'Prefers WhatsApp.',
  tags: const <String>['vip'],
  createdAt: testEpoch,
);

final Customer _blockedAda = Customer(
  id: 'c1',
  name: 'Ada Lovelace',
  phone: '+966501234567',
  createdAt: testEpoch,
  blockedAt: testEpoch,
  blockReason: 'Sends spam links',
  aliases: const <String>['Augusta King', 'A. Byron'],
);

final CustomerChangeProposal _emailProposal = CustomerChangeProposal(
  id: 'p1',
  field: CustomerChangeField.email,
  fieldLabel: 'email',
  currentValue: 'ada@demo.test',
  proposedValue: 'ada@lovelace.test',
  conversationId: 'v1',
  createdAt: testEpoch,
);

final CustomerChangeProposal _cityProposal = CustomerChangeProposal(
  id: 'p2',
  field: CustomerChangeField.customField,
  fieldDefinitionId: 'f1',
  fieldLabel: 'City',
  proposedValue: 'Riyadh',
  createdAt: testEpoch,
);

/// Gives the test view enough height to build the whole page.
///
/// `wrapWidget(size:)` only sets `MediaQuery`; the list lays out against the
/// test view, which is 800 logical pixels tall by default -- and a `ListView`
/// never builds what is below the fold, so a section further down cannot be
/// found however correct it is.
void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('draws who the contact is, from local storage', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(_ScriptedCustomers(customer: _ada, refreshed: _ada)),
    );
    await tester.pump();

    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('+966501234567'), findsOneWidget);
    expect(find.text('ada@demo.test'), findsOneWidget);
  });

  /*
    The standing note and the record are different facts, and the screen shows
    both -- one as a paragraph about the person, one as a list of what happened.
  */
  testWidgets('shows the standing note and the entries separately', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(
          customer: _ada,
          refreshed: _ada,
          notes: <CustomerNote>[
            CustomerNote(
              id: 'n1',
              customerId: 'c1',
              body: 'Called about the invoice.',
              authorName: 'Demo Owner',
              createdAt: testEpoch,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // A second frame: the entries arrive from a stream, and the first frame
    // is drawn before it has emitted.
    await tester.pump();

    expect(find.text('Prefers WhatsApp.'), findsOneWidget);
    expect(find.text('Called about the invoice.'), findsOneWidget);
    expect(find.text('Demo Owner'), findsOneWidget);
  });

  testWidgets('says the record is empty rather than showing nothing', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(_ScriptedCustomers(customer: _ada, refreshed: _ada)),
    );
    await tester.pump();

    expect(find.text('Nothing written down yet'), findsOneWidget);
  });

  /*
    An entry whose author has left is still a record of what was decided; it
    must not render as a blank where a name should be.
  */
  testWidgets('names an author who has left the workspace', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(
          customer: _ada,
          refreshed: _ada,
          notes: <CustomerNote>[
            CustomerNote(
              id: 'n1',
              customerId: 'c1',
              body: 'Called',
              createdAt: testEpoch,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.pump();

    expect(find.text('Author no longer on the team'), findsOneWidget);
  });

  testWidgets('says so when the contact is not there at all', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(_screen(_ScriptedCustomers()));
    await tester.pump();

    expect(
      find.text('This contact was removed from the workspace'),
      findsOneWidget,
    );
  });

  /*
    The online search hands over an id this device has never synced. The screen
    fetches it before anything tries to draw it -- without this it opens as
    "removed from the workspace".
  */
  testWidgets('fetches a contact it does not hold before drawing it', (
    WidgetTester tester,
  ) async {
    final _ScriptedCustomers customers = _ScriptedCustomers(
      customer: _ada,
      refreshed: _ada,
    );

    await tester.pumpWidget(_screen(customers));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(customers.refreshes, 1);
    expect(customers.noteSyncs, 1);
  });

  testWidgets('reads in Arabic, right to left', (WidgetTester tester) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(customer: _ada, refreshed: _ada),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('الملاحظات'), findsOneWidget);
    expect(find.text('إضافة ملاحظة'), findsOneWidget);
  });

  group('blocking', () {
    testWidgets('says the contact is blocked, why, and offers the way back', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(
          _ScriptedCustomers(customer: _blockedAda, refreshed: _blockedAda),
        ),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsOneWidget);
      expect(
        find.text(
          'Blocked — their messages are dropped and nothing is sent to them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sends spam links'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);
      expect(find.text('Block customer'), findsNothing);
    });

    testWidgets('an unblocked contact carries no banner, and offers a block', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(_ScriptedCustomers(customer: _ada, refreshed: _ada)),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsNothing);
      expect(find.text('Block customer'), findsOneWidget);
    });

    /*
      Blocking stops every message both ways, campaigns included. The member
      is told that before anything is sent, and nothing is sent until they
      confirm.
    */
    testWidgets('blocks only after the member confirms what it means', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      final _ScriptedCustomers customers = _ScriptedCustomers(
        customer: _ada,
        refreshed: _ada,
      );
      await tester.pumpWidget(_screen(customers));
      await tester.pump();

      await tester.tap(find.text('Block customer'));
      await tester.pumpAndSettle();

      expect(find.text('Block this customer?'), findsOneWidget);
      expect(find.textContaining('campaigns included'), findsOneWidget);
      expect(customers.writes, isEmpty);

      // The dialog's own confirm, which names the act rather than "OK".
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(customers.writes, <String>['block']);
      expect(find.text('Customer blocked'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation sends nothing', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      final _ScriptedCustomers customers = _ScriptedCustomers(
        customer: _blockedAda,
        refreshed: _blockedAda,
      );
      await tester.pumpWidget(_screen(customers));
      await tester.pump();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      expect(find.text('Unblock this customer?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(customers.writes, isEmpty);
    });

    testWidgets('unblocks after a plain confirmation', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      final _ScriptedCustomers customers = _ScriptedCustomers(
        customer: _blockedAda,
        refreshed: _blockedAda,
      );
      await tester.pumpWidget(_screen(customers));
      await tester.pump();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(customers.writes, <String>['unblock']);
      expect(find.text('Customer unblocked'), findsOneWidget);
    });

    /* A control the server would refuse is not drawn at all. */
    testWidgets('is not offered without update:Customer', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(
          _ScriptedCustomers(customer: _blockedAda, refreshed: _blockedAda),
          permissions: const <String>{'read:Customer'},
        ),
      );
      await tester.pump();

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Unblock'), findsNothing);
    });
  });

  testWidgets('lists the other names the contact is known by', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(customer: _blockedAda, refreshed: _blockedAda),
      ),
    );
    await tester.pump();

    expect(find.text('Also known as'), findsOneWidget);
    expect(find.text('Augusta King · A. Byron'), findsOneWidget);
  });

  group('proposed changes', () {
    testWidgets('draws nothing when none are waiting', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(_ScriptedCustomers(customer: _ada, refreshed: _ada)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Proposed changes'), findsNothing);
    });

    testWidgets('shows each change: field, current value, proposed value', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(
          _ScriptedCustomers(
            customer: _ada,
            refreshed: _ada,
            proposals: <CustomerChangeProposal>[_emailProposal, _cityProposal],
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Proposed changes (2)'), findsOneWidget);
      expect(
        find.text(
          'The AI employee read these in a conversation. The card keeps its '
          'current value until you approve.',
        ),
        findsOneWidget,
      );
      // The built-in field in the app's own word; a custom one by its name.
      expect(find.text('Email'), findsWidgets);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('ada@lovelace.test'), findsOneWidget);
      expect(find.text('Riyadh'), findsOneWidget);
      // A field the card has no value for yet says so.
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('Approve'), findsNWidgets(2));
      expect(find.text('Reject'), findsNWidgets(2));
    });

    testWidgets('approving sends the decision and the change leaves the list', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      final _ScriptedCustomers customers = _ScriptedCustomers(
        customer: _ada,
        refreshed: _ada,
        proposals: <CustomerChangeProposal>[_emailProposal],
      );
      await tester.pumpWidget(_screen(customers));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(customers.writes, <String>['approve p1']);
      expect(find.text('Change approved'), findsOneWidget);
      expect(find.textContaining('Proposed changes'), findsNothing);
    });

    testWidgets('rejecting sends the decision', (WidgetTester tester) async {
      _tallView(tester);
      final _ScriptedCustomers customers = _ScriptedCustomers(
        customer: _ada,
        refreshed: _ada,
        proposals: <CustomerChangeProposal>[_emailProposal],
      );
      await tester.pumpWidget(_screen(customers));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(customers.writes, <String>['reject p1']);
      expect(find.text('Change rejected'), findsOneWidget);
    });

    testWidgets('a reader without update:Customer sees them, not the buttons', (
      WidgetTester tester,
    ) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(
          _ScriptedCustomers(
            customer: _ada,
            refreshed: _ada,
            proposals: <CustomerChangeProposal>[_emailProposal],
          ),
          permissions: const <String>{'read:Customer'},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Proposed changes (1)'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });
  });

  testWidgets('the block, the names and the proposals read in Arabic', (
    WidgetTester tester,
  ) async {
    _tallView(tester);
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(
          customer: _blockedAda,
          refreshed: _blockedAda,
          proposals: <CustomerChangeProposal>[_emailProposal],
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('محظور'), findsOneWidget);
    expect(
      find.text('محظور — تُتجاهَل رسائله ولا يُرسَل إليه شيء.'),
      findsOneWidget,
    );
    expect(find.text('سبب الحظر'), findsOneWidget);
    expect(find.text('أسماء أخرى'), findsOneWidget);
    expect(find.text('تعديلات مقترحة (1)'), findsOneWidget);
    expect(
      find.text(
        'قرأها الموظف الآلي في محادثة. تبقى القيمة الحالية في البطاقة حتى تعتمدها.',
      ),
      findsOneWidget,
    );
    expect(find.text('اعتماد'), findsOneWidget);
    expect(find.text('رفض'), findsOneWidget);
    expect(find.text('إلغاء الحظر'), findsOneWidget);

    await tester.tap(find.text('إلغاء الحظر'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'ستصل رسائله إلى صندوق الوارد من جديد ويمكنك مراسلته. ما أرسله أثناء الحظر لم يُحفظ.',
      ),
      findsOneWidget,
    );
  });

  group('a write that does not go through', () {
    Future<void> pumpWith(WidgetTester tester, AppFailure failure) async {
      _tallView(tester);
      await tester.pumpWidget(
        _screen(
          _ScriptedCustomers(
            customer: _ada,
            refreshed: _ada,
            proposals: <CustomerChangeProposal>[_emailProposal],
            writeFailure: failure,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('offline, a block says it needs a connection', (
      WidgetTester tester,
    ) async {
      await pumpWith(
        tester,
        const TransportFailure(message: 'offline', isOffline: true),
      );

      await tester.tap(find.text('Block customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(
        find.text('This needs a connection. Nothing was changed.'),
        findsOneWidget,
      );
      // Nothing changed, so the page still offers the block.
      expect(find.text('Block customer'), findsOneWidget);
    });

    testWidgets('a refused block says the member may not', (
      WidgetTester tester,
    ) async {
      await pumpWith(tester, const AuthorizationFailure(message: 'no'));

      await tester.tap(find.text('Block customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(
        find.text('You don’t have permission to do this.'),
        findsOneWidget,
      );
    });

    /* Somebody decided it on the web while this screen was open. */
    testWidgets('a proposal decided elsewhere says so', (
      WidgetTester tester,
    ) async {
      await pumpWith(tester, const NotFoundFailure(message: 'gone'));

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text('Someone already decided on this change.'),
        findsOneWidget,
      );
    });

    testWidgets('anything else asks the member to try again', (
      WidgetTester tester,
    ) async {
      await pumpWith(
        tester,
        const TransportFailure(message: 'boom', statusCode: 500),
      );

      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();

      expect(find.text('That didn’t go through. Try again.'), findsOneWidget);
    });
  });
}
