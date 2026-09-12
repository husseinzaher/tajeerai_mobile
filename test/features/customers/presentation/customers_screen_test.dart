import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/app/bootstrap/dependencies.dart';
import 'package:tajeerai_mobile/app/localization/locale_manager.dart';
import 'package:tajeerai_mobile/app/localization/translations/app_strings.dart';
import 'package:tajeerai_mobile/features/customers/domain/entities/customer.dart';
import 'package:tajeerai_mobile/features/customers/domain/entities/customer_note.dart';
import 'package:tajeerai_mobile/features/customers/domain/repositories/customer_repository.dart';
import 'package:tajeerai_mobile/features/customers/presentation/screens/customers_screen.dart';

import '../../../support/fixed_clock.dart';
import '../../../support/widget_harness.dart';

Customer _customer({String id = 'c1', String name = 'Ada Lovelace'}) {
  return Customer(
    id: id,
    name: name,
    phone: '+966501234567',
    tags: const <String>['vip'],
    createdAt: testEpoch,
    updatedAt: testEpoch,
  );
}

/// A repository that answers from a script, so the screen is tested in each of
/// its four states without a database or a server.
class _ScriptedCustomers implements CustomerRepository {
  _ScriptedCustomers({this.customers, this.tags = const <String>[]});

  /// Null leaves the stream open, which is what "loading" is on a screen that
  /// reads the database.
  final List<Customer>? customers;
  final List<String> tags;

  @override
  Stream<List<Customer>> watchCustomers({
    String? searchTerm,
    String? tag,
    int limit = 100,
  }) {
    final List<Customer>? rows = customers;

    if (rows == null) return const Stream<List<Customer>>.empty();

    return Stream<List<Customer>>.value(
      searchTerm == null
          ? rows
          : rows
                .where(
                  (Customer row) =>
                      row.name.toLowerCase().contains(searchTerm.toLowerCase()),
                )
                .toList(),
    );
  }

  @override
  Stream<List<String>> watchTags() => Stream<List<String>>.value(tags);

  @override
  Stream<List<CustomerNote>> watchNotes(String customerId) =>
      Stream<List<CustomerNote>>.value(const <CustomerNote>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A repository whose read fails, for the state a broken database leaves.
class _FailingCustomers extends _ScriptedCustomers {
  @override
  Stream<List<Customer>> watchCustomers({
    String? searchTerm,
    String? tag,
    int limit = 100,
  }) {
    return Stream<List<Customer>>.error(StateError('unreadable'));
  }
}

Widget _screen(
  CustomerRepository customers, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    // Untyped on purpose: Riverpod 3 does not export `Override`, so the list
    // cannot be annotated.
    overrides: [
      customerRepositoryProvider.overrideWithValue(customers),
      // The copy provider directly: the screen reads it, and overriding the
      // manager behind it would mean standing up its storage as well.
      appStringsProvider.overrideWithValue(
        AppStrings(
          locale.languageCode == 'ar' ? AppLocale.arabic : AppLocale.english,
        ),
      ),
    ],
    child: wrapWidget(
      const CustomersScreen(),
      locale: locale,
      textDirection: locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
    ),
  );
}

void main() {
  testWidgets('draws every contact it holds', (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(_ScriptedCustomers(customers: <Customer>[_customer()])),
    );
    await tester.pump();

    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('+966501234567'), findsOneWidget);
  });

  testWidgets('says the list is empty rather than showing nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(_ScriptedCustomers(customers: const <Customer>[])),
    );
    await tester.pump();

    expect(find.text('No contacts yet'), findsOneWidget);
  });

  testWidgets('says what failed when the list cannot be read', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_FailingCustomers()));
    await tester.pump();

    expect(find.text('Contacts could not be read'), findsOneWidget);
  });

  testWidgets('shows the tag filter only when there are tags to filter by', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(_ScriptedCustomers(customers: <Customer>[_customer()])),
    );
    await tester.pump();
    expect(find.text('All'), findsNothing);

    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(
          customers: <Customer>[_customer()],
          tags: const <String>['vip'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('vip'), findsOneWidget);
  });

  /*
    The copy is a merchant's, and this is a Gulf-market product: the screen has
    to be right in Arabic, not merely translatable.
  */
  testWidgets('reads in Arabic, right to left', (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(
        _ScriptedCustomers(customers: const <Customer>[]),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('جهات الاتصال'), findsOneWidget);
    expect(find.text('لا توجد جهات اتصال بعد'), findsOneWidget);
  });
}
