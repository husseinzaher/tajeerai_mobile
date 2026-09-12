import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';

/// Riverpod's [AsyncValue], as a state the design system draws.
///
/// Its own copy rather than the Inbox's, because a feature may not import
/// another feature's presentation (§6) -- and the alternative, a shared helper,
/// has nowhere to live: the design system may not know Riverpod exists
/// (RULE 33) and `app/` is not importable from a feature.
///
/// **A value beats a spinner.** These screens read the local database, so a
/// list that is already there stays on screen while a sync runs and after one
/// fails. Only a failure with nothing behind it is drawn as a failure.
extension CustomerAsyncView<T> on AsyncValue<T> {
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
