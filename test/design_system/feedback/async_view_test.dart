import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tajeerai_mobile/design_system/feedback/async_view.dart';
import 'package:tajeerai_mobile/design_system/feedback/empty_state.dart';
import 'package:tajeerai_mobile/design_system/feedback/error_state.dart';
import 'package:tajeerai_mobile/design_system/loaders/spinner.dart';

import '../../support/widget_harness.dart';

/// The four states, drawn one way.
///
/// This replaces a `.when(loading:, error:, data:)` block that was written out
/// in full on every screen, each one deciding for itself what empty looked like
/// and whether the failure was retryable.
void main() {
  Widget subject(
    AppViewState<List<String>> state, {
    bool Function(List<String>)? isEmpty,
    WidgetBuilder? empty,
  }) => wrapWidget(
    AppAsyncView<List<String>>(
      state: state,
      isEmpty: isEmpty,
      empty: empty,
      data: (List<String> rows) =>
          Column(children: <Widget>[for (final String row in rows) Text(row)]),
    ),
  );

  testWidgets('loading shows a spinner', (WidgetTester tester) async {
    await tester.pumpWidget(subject(const AppViewLoading<List<String>>()));
    expect(find.byType(AppSpinner), findsOneWidget);
  });

  testWidgets('failure shows the message, and a retry only when there is one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      subject(const AppViewFailed<List<String>>('تعذّر التحميل')),
    );
    expect(find.text('تعذّر التحميل'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);

    int retries = 0;
    await tester.pumpWidget(
      subject(
        AppViewFailed<List<String>>('تعذّر التحميل', onRetry: () => retries++),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('loaded draws the data', (WidgetTester tester) async {
    await tester.pumpWidget(
      subject(const AppViewLoaded<List<String>>(<String>['أحمد', 'سارة'])),
    );
    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text('سارة'), findsOneWidget);
  });

  testWidgets('empty is a fifth picture, and only the caller knows it', (
    WidgetTester tester,
  ) async {
    // A list with no rows and a customer with no orders are both *loaded* and
    // both empty. Riverpod's AsyncValue has one value for that; a screen needs
    // two pictures.
    await tester.pumpWidget(
      subject(
        const AppViewLoaded<List<String>>(<String>[]),
        isEmpty: (List<String> rows) => rows.isEmpty,
        empty: (BuildContext context) => const AppEmptyState(title: 'لا شيء'),
      ),
    );

    expect(find.text('لا شيء'), findsOneWidget);
  });

  testWidgets('without isEmpty, an empty list is still data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      subject(const AppViewLoaded<List<String>>(<String>[])),
    );

    expect(find.byType(AppEmptyState), findsNothing);
    expect(find.byType(AppErrorState), findsNothing);
  });

  testWidgets('a caller can replace any of the three defaults', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrapWidget(
        AppAsyncView<int>(
          state: const AppViewLoading<int>(),
          loading: (BuildContext context) => const Text('جارٍ التحميل'),
          data: (int value) => Text('$value'),
        ),
      ),
    );

    expect(find.text('جارٍ التحميل'), findsOneWidget);
    expect(find.byType(AppSpinner), findsNothing);
  });
}
