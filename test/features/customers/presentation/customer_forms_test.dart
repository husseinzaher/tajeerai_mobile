import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:TajeerAi/app/bootstrap/dependencies.dart';
import 'package:TajeerAi/app/localization/locale_manager.dart';
import 'package:TajeerAi/app/localization/translations/app_strings.dart';
import 'package:TajeerAi/app/theme/theme.dart';
import 'package:TajeerAi/design_system/design_system.dart';
import 'package:TajeerAi/failures/app_failure.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer.dart';
import 'package:TajeerAi/features/customers/domain/entities/customer_note.dart';
import 'package:TajeerAi/features/customers/domain/repositories/customer_repository.dart';
import 'package:TajeerAi/features/customers/presentation/screens/customer_form_screen.dart';
import 'package:TajeerAi/features/customers/presentation/screens/customer_note_form_screen.dart';

import '../../../support/fixed_clock.dart';

class _Contacts implements CustomerRepository {
  _Contacts({this.existing, this.failure});

  /// What `findByPhone` answers -- the duplicate the form must open instead of
  /// creating a second row.
  final Customer? existing;

  /// What a write raises, for the offline and refused cases.
  final AppFailure? failure;

  final List<String> notesWritten = <String>[];
  int creates = 0;

  @override
  Future<Customer?> findByPhone(String number) async => existing;

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

    creates += 1;

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

/// The screen under a real router.
///
/// Both forms navigate when they succeed -- one pops back to the record, the
/// other replaces itself with the contact it created -- so a bare `pumpWidget`
/// fails at the moment the test cares about most. The router is the smallest
/// one that lets those calls resolve: a page to leave, and a page to arrive
/// at.
Widget _wrap(
  Widget screen,
  CustomerRepository customers, {
  Locale locale = const Locale('en'),
  ValueChanged<GoRouter>? onRouter,
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/form',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const Text('behind'),
      ),
      GoRoute(
        path: '/form',
        builder: (BuildContext context, GoRouterState state) => screen,
      ),
      GoRoute(
        path: '/customers/:customerId',
        builder: (BuildContext context, GoRouterState state) =>
            Text('contact ${state.pathParameters['customerId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  onRouter?.call(router);

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
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.of(TajeerPreset.fallback, Brightness.light),
      locale: locale,
      supportedLocales: AppLocale.supported,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppDesignSystemLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

Finder _saveButton() => find.widgetWithText(AppButton, 'Save');

void main() {
  group('the note form', () {
    /*
      An entry that says nothing still claims somebody was here, and the API
      refuses it -- so the screen does not offer to send it.
    */
    testWidgets('will not offer to send an empty entry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CustomerNoteFormScreen(customerId: 'c1'), _Contacts()),
      );
      await tester.pump();

      expect(tester.widget<AppButton>(_saveButton()).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      expect(tester.widget<AppButton>(_saveButton()).onPressed, isNull);
    });

    testWidgets('sends what was written, trimmed', (WidgetTester tester) async {
      final _Contacts contacts = _Contacts();

      await tester.pumpWidget(
        _wrap(const CustomerNoteFormScreen(customerId: 'c1'), contacts),
      );
      await tester.enterText(find.byType(TextField), '  Called back  ');
      await tester.pump();

      await tester.tap(_saveButton());
      await tester.pump();

      await tester.pumpAndSettle();

      expect(contacts.notesWritten, <String>['Called back']);
    });

    /*
      Online only, so the failure that matters is being offline -- and the
      draft has to survive it. Clearing the field would ask somebody to
      remember what they typed.
    */
    testWidgets('keeps the draft and says why when there is no connection', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerNoteFormScreen(customerId: 'c1'),
          _Contacts(
            failure: const TransportFailure(
              message: 'offline',
              isOffline: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Called back');
      await tester.pump();

      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        find.text('Writing a note needs a connection. Your draft is kept.'),
        findsOneWidget,
      );
      expect(find.text('Called back'), findsOneWidget);
    });
  });

  group('the contact form', () {
    testWidgets('will not save a contact with no name', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(const CustomerFormScreen(), _Contacts()));
      await tester.pump();

      expect(tester.widget<AppButton>(_saveButton()).onPressed, isNull);
    });

    /*
      The duplicate check runs before the write. A contact created and then
      found to exist is two rows somebody has to merge.
    */
    testWidgets('opens the contact a number already belongs to', (
      WidgetTester tester,
    ) async {
      final _Contacts contacts = _Contacts(
        existing: Customer(id: 'c1', name: 'Ada', createdAt: testEpoch),
      );

      await tester.pumpWidget(_wrap(const CustomerFormScreen(), contacts));
      await tester.enterText(find.byType(TextField).first, 'Ada Lovelace');
      // In full: the form refuses a national number before it looks anything
      // up, which is a different test.
      await tester.enterText(find.byType(TextField).at(1), '+966501234567');
      await tester.pump();

      await tester.tap(_saveButton());
      await tester.pump();

      await tester.pumpAndSettle();

      expect(contacts.creates, 0);
      // It opened the contact that already had the number rather than making a
      // second one.
      expect(find.text('contact c1'), findsOneWidget);
    });

    /*
      The mistake the field invites: `0501234567` is Saudi Arabia's number to a
      Saudi reader and somebody else's to everybody else, and the API refuses
      it. Caught while the keyboard is still open rather than after a round
      trip.
    */
    testWidgets('refuses a number typed without its country code', (
      WidgetTester tester,
    ) async {
      final _Contacts contacts = _Contacts();

      await tester.pumpWidget(_wrap(const CustomerFormScreen(), contacts));
      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.enterText(find.byType(TextField).at(1), '0501234567');
      await tester.pump();

      await tester.tap(_saveButton());
      await tester.pump();

      expect(
        find.text('Start with the country code, like +966501234567.'),
        findsWidgets,
      );
      expect(contacts.creates, 0);
    });

    testWidgets(
      'opens on the country code, so the right answer is the easy one',
      (WidgetTester tester) async {
        await tester.pumpWidget(_wrap(const CustomerFormScreen(), _Contacts()));
        await tester.pump();

        expect(find.text('+966'), findsOneWidget);
      },
    );

    /* A field left at the bare calling code is nobody's number. */
    testWidgets('saves a contact with no number when only the code is there', (
      WidgetTester tester,
    ) async {
      final _Contacts contacts = _Contacts();

      await tester.pumpWidget(_wrap(const CustomerFormScreen(), contacts));
      await tester.enterText(find.byType(TextField).first, 'Ada');
      await tester.pump();

      await tester.tap(_saveButton());
      await tester.pumpAndSettle();

      expect(contacts.creates, 1);
    });

    testWidgets('prefills the number it was opened with', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerFormScreen(initialPhone: '0501234567'),
          _Contacts(),
        ),
      );
      await tester.pump();

      expect(find.text('0501234567'), findsOneWidget);
    });

    testWidgets('says a contact needs a connection, in Arabic too', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CustomerFormScreen(),
          _Contacts(
            failure: const TransportFailure(
              message: 'offline',
              isOffline: true,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'أحمد');
      await tester.pump();

      await tester.tap(find.widgetWithText(AppButton, 'حفظ'));
      await tester.pump();

      expect(
        find.text('إضافة جهة اتصال تحتاج اتصالًا بالإنترنت.'),
        findsOneWidget,
      );
    });
  });
}
