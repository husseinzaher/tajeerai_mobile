import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';

/// Why an entry could not be written -- a reason the screen words.
enum CustomerNoteFormError {
  /// Writing an entry is online-only, and there was no connection.
  needsConnection,

  /// Anything else.
  saveFailed,
}

/// The note form's state. The draft itself stays in the screen's field, so a
/// failure never costs the member what they typed.
final class CustomerNoteFormState {
  const CustomerNoteFormState({this.isSaving = false, this.error});

  final bool isSaving;
  final CustomerNoteFormError? error;

  CustomerNoteFormState copyWith({
    bool? isSaving,
    CustomerNoteFormError? error,
    bool clearError = false,
  }) {
    return CustomerNoteFormState(
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerNoteFormState &&
      other.isSaving == isSaving &&
      other.error == error;

  @override
  int get hashCode => Object.hash(isSaving, error);
}

/// Auto-disposed, so the next entry starts from a clean form.
final NotifierProvider<CustomerNoteFormController, CustomerNoteFormState>
customerNoteFormControllerProvider =
    NotifierProvider.autoDispose<
      CustomerNoteFormController,
      CustomerNoteFormState
    >(CustomerNoteFormController.new);

/// Owns writing an entry on a contact's record.
///
/// **Online only, and it says so.** The server stamps the entry with who wrote
/// it and when, and there is no local identity to stamp it with in the
/// meantime -- so this does not queue through the outbox the way a message
/// does. What it does instead is keep the draft: a failed send leaves the
/// words on screen, with a reason the screen words, rather than clearing the
/// field and asking somebody to remember what they typed.
class CustomerNoteFormController extends Notifier<CustomerNoteFormState> {
  @override
  CustomerNoteFormState build() => const CustomerNoteFormState();

  /// Writes the entry. True when it was saved; false when it was not, with
  /// the reason on [state]. Nothing happens for an empty body or while a save
  /// is already in flight.
  Future<bool> save({required String customerId, required String body}) async {
    final String trimmed = body.trim();

    if (trimmed.isEmpty || state.isSaving) return false;

    state = const CustomerNoteFormState(isSaving: true);

    try {
      await ref.read(customerRepositoryProvider).addNote(customerId, trimmed);

      state = state.copyWith(isSaving: false);

      return true;
    } on AppFailure catch (failure) {
      state = CustomerNoteFormState(
        error: switch (failure) {
          TransportFailure(isOffline: true) =>
            CustomerNoteFormError.needsConnection,
          _ => CustomerNoteFormError.saveFailed,
        },
      );

      return false;
    }
  }

  /// Clears the error as the member edits.
  void clearError() {
    if (state.error == null) return;

    state = state.copyWith(clearError: true);
  }
}
