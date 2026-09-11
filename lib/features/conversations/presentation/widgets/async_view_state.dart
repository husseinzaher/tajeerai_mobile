import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';

/// Riverpod's [AsyncValue], as a state the design system draws.
///
/// Here and not in the design system, which may not know Riverpod exists
/// (RULE 33).
///
/// **A value beats a spinner.** The Inbox reads the local database, so a value
/// that is there stays on screen while a refresh runs and after one fails. Only
/// a failure with nothing to show is drawn as a failure.
extension AsyncValueView<T> on AsyncValue<T> {
  AppViewState<R> toViewState<R>(
    R Function(T value) map, {
    required String failure,
    VoidCallback? onRetry,
  }) {
    if (hasValue) {
      return AppViewLoaded<R>(map(requireValue));
    }
    if (hasError) {
      return AppViewFailed<R>(failure, onRetry: onRetry);
    }
    return AppViewLoading<R>();
  }
}
