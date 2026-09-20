import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
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
  });

  final Customer? customer;
  final List<CustomerNote> notes;

  /// What a refresh answers. Null means the server no longer has them.
  final Customer? refreshed;

  int refreshes = 0;
  int noteSyncs = 0;

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

Widget _screen(
  CustomerRepository customers, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    // Untyped: Riverpod 3 does not export `Override`.
    overrides: [
      customerRepositoryProvider.overrideWithValue(customers),
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
}
