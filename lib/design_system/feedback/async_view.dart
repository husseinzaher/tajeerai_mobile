import 'package:flutter/material.dart';

import '../localization/ds_localization.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'loading_state.dart';

/// What a screen has, at this moment, for one thing it is showing.
///
/// A sealed hierarchy the **design system** owns, deliberately not Riverpod's
/// `AsyncValue`. Two reasons, and the second is the load-bearing one. A design
/// system that imports a state-management package can only be used by an
/// application that made the same choice — RULE 33 exists for that. And the
/// four states a screen *draws* are not the four a data layer *has*: loaded and
/// empty are one value to Riverpod and two entirely different pictures here.
sealed class AppViewState<T> {
  const AppViewState();
}

final class AppViewLoading<T> extends AppViewState<T> {
  const AppViewLoading();
}

final class AppViewFailed<T> extends AppViewState<T> {
  const AppViewFailed(this.message, {this.onRetry});

  /// Copy a person can act on. Never an exception's `toString` — mapping a
  /// failure to a sentence is the feature's job, and the failure taxonomy
  /// exists so it never has to reach for the infrastructure type to do it.
  final String message;

  final VoidCallback? onRetry;
}

final class AppViewLoaded<T> extends AppViewState<T> {
  const AppViewLoaded(this.value);

  final T value;
}

/// Draws the four states one way, everywhere.
///
/// This replaces the `.when(loading:, error:, data:)` block that was written
/// out in full on every screen, each time deciding for itself what "empty"
/// looked like and whether the error was retryable.
class AppAsyncView<T> extends StatelessWidget {
  const AppAsyncView({
    required this.state,
    required this.data,
    this.loading,
    this.error,
    this.isEmpty,
    this.empty,
    super.key,
  });

  final AppViewState<T> state;
  final Widget Function(T value) data;
  final WidgetBuilder? loading;
  final Widget Function(AppViewFailed<T> failure)? error;

  /// Whether a loaded value is *nothing*. A list with no rows and a customer
  /// with no orders are both loaded and both empty, and only the caller knows
  /// what emptiness means for its own type.
  final bool Function(T value)? isEmpty;

  final WidgetBuilder? empty;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AppViewLoading<T>() => loading?.call(context) ?? const AppLoadingState(),
      final AppViewFailed<T> failure =>
        error?.call(failure) ??
            AppErrorState(
              message: failure.message,
              onRetry: failure.onRetry,
              bordered: false,
            ),
      final AppViewLoaded<T> loaded =>
        isEmpty?.call(loaded.value) ?? false
            ? empty?.call(context) ??
                  AppEmptyState(
                    title: context.strings.noMatches,
                    bordered: false,
                  )
            : data(loaded.value),
    };
  }
}
