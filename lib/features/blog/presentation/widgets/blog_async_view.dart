import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';

/// Riverpod's [AsyncValue], as a state the design system draws.
///
/// Per-feature rather than shared, for the reason RULE 13 gives: a feature may
/// not import another feature's presentation, and the design system may not
/// know Riverpod exists (RULE 33). So each feature carries its own three-line
/// bridge, and `customer_async_view.dart` is the same file for customers.
///
/// **A value beats a spinner.** A list already on screen stays there while a
/// refresh runs and after one fails; only a failure with nothing to show is
/// drawn as a failure. That is what keeps a pull-to-refresh on a bad
/// connection from blanking an article the reader was halfway through.
extension BlogAsyncView<T> on AsyncValue<T> {
  AppViewState<R> toViewState<R>(
    R Function(T value) map, {
    required String failure,
    VoidCallback? onRetry,
  }) {
    if (hasValue) return AppViewLoaded<R>(map(requireValue));
    if (hasError) return AppViewFailed<R>(failure, onRetry: onRetry);

    return AppViewLoading<R>();
  }
}
