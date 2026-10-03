import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/features/conversations/domain/entities/conversation.dart';
import 'package:TajeerAi/features/conversations/presentation/widgets/customer_panel_sheet.dart';
import 'package:TajeerAi/features/customers/application/contracts/customer_record_capability.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/widget_harness.dart';

/// The read-only door the panel draws from: the contact as stored, no entries,
/// and a refresh that does nothing.
class _Record implements CustomerRecordCapability {
  _Record(this.customer, {this.notes = const <CustomerNote>[]});

  final Customer? customer;
  final List<CustomerNote> notes;

  @override
  Stream<Customer?> watchCustomer(String customerId) =>
      Stream<Customer?>.value(customer);

  @override
  Stream<List<CustomerNote>> watchNotes(String customerId) =>
      Stream<List<CustomerNote>>.value(notes);

  @override
  Future<void> refresh(String customerId) async {}
}

final Conversation _thread = Conversation(
  id: 'v1',
  state: ConversationState.open,
  createdAt: testEpoch,
  customerId: 'c1',
  customerName: 'Ada Lovelace',
);

/// Wide, because the test font draws every glyph a full em across: the three
/// tab labels that fit a phone in a real typeface overflow one in this.
const Size _view = Size(1200, 2400);

Widget _sheet(
  Customer? customer, {
  Locale locale = const Locale('en'),
  Conversation? thread,
  List<CustomerNote> notes = const <CustomerNote>[],
  VoidCallback? onOpenCustomer,
  VoidCallback? onAddReminder,
}) {
  final bool arabic = locale.languageCode == 'ar';

  return ProviderScope(
    // Untyped: Riverpod 3 does not export `Override`.
    overrides: [
      customerRecordProvider.overrideWithValue(_Record(customer, notes: notes)),
      appStringsProvider.overrideWithValue(
        AppStrings(arabic ? AppLocale.arabic : AppLocale.english),
      ),
    ],
    child: wrapWidget(
      CustomerPanelSheet(
        conversation: thread ?? _thread,
        onOpenCustomer: onOpenCustomer,
        onAddReminder: onAddReminder,
      ),
      size: _view,
      locale: locale,
      textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
    ),
  );
}

void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = _view;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /*
    A member opening the panel is about to reply. A blocked contact is one
    nothing reaches, and the panel says so before anything else.
  */
  testWidgets('says a blocked contact is blocked', (WidgetTester tester) async {
    tallView(tester);
    await tester.pumpWidget(
      _sheet(
        Customer(
          id: 'c1',
          name: 'Ada Lovelace',
          createdAt: testEpoch,
          blockedAt: testEpoch,
        ),
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
  });

  testWidgets('says nothing of a block on a contact that has none', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(
      _sheet(Customer(id: 'c1', name: 'Ada Lovelace', createdAt: testEpoch)),
    );
    await tester.pump();

    expect(find.text('Registered customer'), findsOneWidget);
    expect(find.text('Blocked'), findsNothing);
  });

  testWidgets('says it in Arabic', (WidgetTester tester) async {
    tallView(tester);
    await tester.pumpWidget(
      _sheet(
        Customer(
          id: 'c1',
          name: 'Ada Lovelace',
          createdAt: testEpoch,
          blockedAt: testEpoch,
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('محظور'), findsOneWidget);
    expect(
      find.text('محظور — تُتجاهَل رسائله ولا يُرسَل إليه شيء.'),
      findsOneWidget,
    );
  });

  testWidgets('offers call, reminder and open for a registered contact', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    int opened = 0;
    await tester.pumpWidget(
      _sheet(
        Customer(
          id: 'c1',
          name: 'Ada Lovelace',
          phone: '+966501234567',
          createdAt: testEpoch,
        ),
        onOpenCustomer: () => opened += 1,
        onAddReminder: () {},
      ),
    );
    await tester.pump();

    expect(find.text('Call'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);

    // "Open" is the way to the contact's own screen, where a block is lifted.
    // By its glyph: the thread's own status also reads "Open".
    await tester.tap(find.byIcon(LucideIcons.userRound));
    expect(opened, 1);
  });

  /*
    A thread nobody has attached a contact to yet: the header says so, and
    each tab says why it is empty rather than looking broken.
  */
  testWidgets('a thread with no contact says why each tab is empty', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(
      _sheet(
        null,
        thread: Conversation(
          id: 'v2',
          state: ConversationState.pending,
          createdAt: testEpoch,
          customerName: 'Unknown sender',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Not a customer yet'), findsOneWidget);
    expect(find.text('Blocked'), findsNothing);

    await tester.tap(find.text('Orders'));
    await tester.pump();
    expect(
      find.text('This conversation has no customer attached yet.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Follow-ups'));
    await tester.pump();
    expect(
      find.text('This conversation has no customer attached yet.'),
      findsOneWidget,
    );
  });

  testWidgets('lists a follow-up still owed, and marks it overdue', (
    WidgetTester tester,
  ) async {
    tallView(tester);
    await tester.pumpWidget(
      _sheet(
        Customer(id: 'c1', name: 'Ada Lovelace', createdAt: testEpoch),
        notes: <CustomerNote>[
          CustomerNote(
            id: 'n1',
            customerId: 'c1',
            body: 'Send the revised quote',
            authorName: 'Demo Owner',
            followUpAt: DateTime.utc(2020),
            createdAt: testEpoch,
          ),
          // Done: no longer owed, so not listed.
          CustomerNote(
            id: 'n2',
            customerId: 'c1',
            body: 'Already handled',
            followUpAt: DateTime.utc(2020),
            followUpDoneAt: DateTime.utc(2020, 1, 2),
            createdAt: testEpoch,
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Follow-ups'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Send the revised quote'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Already handled'), findsNothing);
  });
}
